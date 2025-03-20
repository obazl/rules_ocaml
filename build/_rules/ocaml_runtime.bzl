# load(":apis.bzl", "options") # , "options_ns_resolver")

load("@rules_ocaml//build:providers.bzl",
     "OCamlDepsProvider",
     "OCamlModuleProvider",
     "OCamlImportProvider",
     # "OCamlLibraryProvider",
     "OCamlRuntimeProvider")

load("//build/_lib:apis.bzl", "options")
load("//build/_lib:ccdeps.bzl", "extract_cclibs")

load("//build/_lib:options.bzl", "get_options")
load("//build/_lib:utils.bzl", "dsorder", "tmpdir")

load("//build/_transitions:in_transitions.bzl",
     "toolchain_in_transition")

load("//lib:colors.bzl", "CCRED", "CCMAGBG", "CCRESET")

###############################
def _rt_in_transition_impl(settings, attr):
    host = "@rules_ocaml//platform:ocamlc.opt"
    tgt  = "@rules_ocaml//platform:vm>any"
    return {
        "@rules_ocaml//toolchain": "ocamlc.opt",
        "//command_line_option:host_platform": host,
        "//command_line_option:platforms": tgt
    }

_rt_in_transition = transition(
    implementation = _rt_in_transition_impl,
    inputs = [],
    # "//command_line_option:host_platform",
    #           "//command_line_option:platforms"],
    outputs = ["//command_line_option:host_platform",
               "//command_line_option:platforms",
               "@rules_ocaml//toolchain"]
)

###############################
def _ocaml_runtime_impl(ctx):

    debug = False

    if debug:
        print("{c}ocaml_runtime:{r} {lbl}".format(
            c=CCMAGBG,r=CCRESET, lbl=ctx.label))

    if ctx.label.name in ["_std", "_dbg", "_instrumented"]:
        defaultInfo = DefaultInfo()
        ocamlRuntimeProvider = OCamlRuntimeProvider(
            name = ctx.label.name,
            sys = True)
        providers = [
            defaultInfo,
            ocamlRuntimeProvider
        ]
        return providers

    else: # user-defined runtime

        tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
        tc_profile = ctx.toolchains["@rules_ocaml//toolchain/type:profile"]

        # Q: deps are supposed to be OCaml wrappers on cclibs
        # what if they have their own dependencies?
        # do we need to merge deps?

        args = ctx.actions.args()
        _options = get_options(ctx.attr._rule, ctx)
        args.add_all(_options)

        action_outputs = []
        out_rt = ctx.actions.declare_file(
            ctx.label.name + ".rt"
        )
        action_outputs.append(out_rt)
        print("OUT RT: %s" % out_rt)

        action_inputs  = []
        # print("DEPS attr: %s" % ctx.attr.deps)
        ## deps may include libs, modules, and imports
        static_cc_deps = []
        dynamic_cc_deps = []
        for datum in ctx.attr.deps:
            # print("DATUM %s" % datum)
            if OCamlDepsProvider in datum:
                # print("dp: %s" % datum[OCamlDepsProvider].archives)
                action_inputs.append(datum[OCamlDepsProvider].archives)
            if CcInfo in datum:
                # print("EXTRACTING CCINFO %s" % datum)
                [static_cc, dynamic_cc] = extract_cclibs(ctx, datum[CcInfo])
                static_cc_deps.extend(static_cc)
                dynamic_cc_deps.extend(dynamic_cc)

        # print("ccinfo statics: %s" % static_cc_deps)
        action_inputs_depset = depset(
            order = dsorder,
            direct = static_cc_deps,
            transitive = action_inputs
        )
        # print("ccinfo dynlibs: %s" % dynamic_cc_deps)
        # print("ACTION INPUTS: %s" % action_inputs_depset)

        if ctx.attr.sys_runtime:
            if ctx.attr.sys_runtime[OCamlRuntimeProvider].name == "_dbg":
                args.add("-runtime-variant", "d")
            elif ctx.attr.sys_runtime[OCamlRuntimeProvider].name == "_instrumented":
                args.add("-runtime-variant", "i")

        args.add("-make-runtime")
        for item in action_inputs:
            for f in item.to_list():
                args.add(f.basename)
                args.add("-I", f.dirname)
        # for item in static_cc_deps:
        #     args.add(item)
        args.add("-o", out_rt)

        ################
        mnemonic = "GenRuntime"
        if ctx.label.workspace_name == ctx.workspace_name:
            ws_name = ""
        else:
            ws_name = "@" + ctx.label.workspace_name if ctx.label.workspace_name else ""

        ctx.actions.run(
            executable = tc.compiler,
            arguments = [args],
            inputs    = action_inputs_depset,
            outputs   = action_outputs,
            tools = [tc.compiler],
            mnemonic = mnemonic,
            progress_message = "{mode} generating runtime: {ws}//{pkg}:{tgt}".format(
                mode = tc.host + ">" + tc.target,
                ws = ws_name,
                pkg = ctx.label.package,
                tgt=ctx.label.name,
            )
        )

        defaultInfo = DefaultInfo(
            files = depset(
                order = dsorder,
                direct = [out_rt]
            )
        )
        ocamlRuntime = OCamlRuntimeProvider(
            name = ctx.label.name,
            sys  = False,
            rt = out_rt
        )

        return [defaultInfo, ocamlRuntime]

#########################
rule_options = options("rules_ocaml")

ocaml_runtime = rule(
  implementation = _ocaml_runtime_impl,
    doc = """
OCaml runtime, either system (std, debug, instrumented)or user-defined using ocamlc -make-runtime
    """,
# Manual https://ocaml.org/manual/5.3/comp.html
# -make-runtime
# Build a custom runtime system (in the file specified by option -o) incorporating the C object files and libraries given on the command line. This custom runtime system can be used later to execute bytecode executables produced with the ocamlc -use-runtime runtime-name option. See section 22.1.6 for more information.

# 22.1.6 example:
# ocamlc -make-runtime -o /home/me/ocamlunixrun unix.cma threads.cma
    attrs = dict(
        rule_options,
        sys_runtime = attr.label(
            doc = "System runtime to use: std, dbg, or instrumented.",
            # default = "@rules_ocaml//rt:_std"
        ),

        deps = attr.label_list(
            doc = """Libraries whose cc deps should be included in the runtime
            """,
            mandatory = False,
            providers = [
                # deps must provide CcInfo
                [OCamlModuleProvider],
                [OCamlImportProvider],
                [CcInfo]
                 # [OCamlLibraryProvider]
            ]
        ),
        _rule = attr.string(default = "ocaml_runtime")
    ),
    cfg = _rt_in_transition,
    provides = [OCamlRuntimeProvider],
    executable = False,
    toolchains     = ["@rules_ocaml//toolchain/type:std",
                      "@rules_ocaml//toolchain/type:profile",
                      "@bazel_tools//tools/cpp:toolchain_type"]
)
