load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "C_COMPILE_ACTION_NAME")


load("//ocaml:providers.bzl",
     "OcamlArchiveMarker",
     "OcamlExecutableMarker",
     "OcamlImportMarker")

RED="\033[0;31m"
MAG="\033[0;35m"
RESET="\033[0;0m"

################
def _dump_cc_toolchain(ctx):
    print("**** CcToolchainInfo ****")
    tc = find_cpp_toolchain(ctx)

    # tc2 = cc_common.CcToolchainInfo

    items = dir(tc)
    for item in items:
        print("{c}{item}".format(c=RED, item=item))
        val = getattr(tc, item)
        print("  %s" % val)
        # if item == "dynamic_runtime_lib":
        #     print(":: %s" % tc.dynamic_runtime_lib(
        #         feature_configuration = cc_common.configure_features(
        #             ctx = ctx,
        #             cc_toolchain = tc,
        #             requested_features = ctx.features,
        #             unsupported_features = ctx.disabled_features,
        #         )
        #     ))
        # if item == "linker_files":
        #     print(":: %s" % tc.linker_files)

################
def _dump_tc_frags(ctx):
    print("**** host platform frags: %s" % ctx.host_fragments.platform)
    ds = dir(ctx.host_fragments.platform)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d, dval = getattr(ctx.host_fragments.platform, d)))
        _platform = ctx.host_fragments.platform.platform

    print("**** target platform frags: %s" % ctx.fragments.platform)
    ds = dir(ctx.fragments.platform)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d, dval = getattr(ctx.host_fragments.platform, d)))
    _platform = ctx.host_fragments.platform.platform

    if ctx.host_fragments.apple:
        _cc_opts = ["-Wl,-no_compact_unwind"]
        print("**** host apple frags: %s" % ctx.host_fragments.apple)
        ds = dir(ctx.host_fragments.apple)
        for d in ds:
            print("\t{d}:\n\t{dval}".format(
                d = d, dval = getattr(ctx.host_fragments.apple, d)))
    else:
        _cc_opts = []

    print("**** host cpp frags: %s" % ctx.host_fragments.cpp)
    ds = dir(ctx.fragments.cpp)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d,
            dval = getattr(ctx.fragments.cpp, d) if d != "custom_malloc" else ""))

    print("**** target cpp frags: %s" % ctx.fragments.cpp)
    ds = dir(ctx.fragments.cpp)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d,
            dval = getattr(ctx.fragments.cpp, d) if d != "custom_malloc" else ""))

## obtaining CC toolchain:  https://github.com/bazelbuild/bazel/issues/7260
################################################################
def _ocaml_toolchain_adapter_impl(ctx):
    # print("\n\t_ocaml_toolchain_impl")

    debug_cctc  = True
    debug_frags = False

    cctc = ctx.toolchains["@bazel_tools//tools/cpp:toolchain_type"]
    if debug_cctc: print("CC TOOLCHAIN: %s" % cctc)

    if debug_frags:
        _dump_tc_frags(ctx)

    if debug_cctc:
        _dump_cc_toolchain(ctx)

    the_cc_toolchain = find_cpp_toolchain(ctx)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = the_cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    _c_exe = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
    )
    if debug_cctc: print("c_exe: %s" % _c_exe)

    if not ctx.attr.linkmode in ["static", "dynamic"]:
        fail("Bad value '{actual}' for attrib 'link'. Allowed values: 'static', 'dynamic' (in rule: ocaml_toolchain(name=\"{n}\"), build file: \"{bf}\", workspace: \"{ws}\"".format(
            ws = ctx.workspace_name,
            bf = ctx.build_file_path,
            n = ctx.label.name,
            actual = ctx.attr.linkmode
        )
             )

    return [platform_common.ToolchainInfo(
        # Public fields
        name                   = ctx.label.name,
        host                   = ctx.attr.host,
        target                 = ctx.attr.target,
        compiler               = ctx.file.compiler,
        vmruntime              = ctx.file.vmruntime,
        vmruntime_debug        = ctx.file.vmruntime_debug,
        vmruntime_instrumented = ctx.file.vmruntime_instrumented,
        vmlibs                 = ctx.files.vmlibs,

        ocamllex               = ctx.file.ocamllex,
        ocamlyacc              = ctx.file.ocamlyacc,

        ## deprecated:
        ocamlc                 = ctx.file.ocamlc,
        ocamlc_opt             = ctx.file.ocamlc_opt,
        ocamlopt               = ctx.file.ocamlopt,
        ocamlopt_opt           = ctx.file.ocamlopt_opt,
        linkmode               = ctx.attr.linkmode,


        # cc_toolchain = ctx.attr.cc_toolchain,
        ## rules add [cc_toolchain.all_files] to action inputs
        ## at least, rules linking to cc libs must do this;
        ## pure ocaml code need not?
        # cc_toolchain = the_cc_toolchain,
        # cc_exe = _c_exe, ## to be passed via `-cc` (will be a sh script on mac)

        # cc_opts = _cc_opts,

        ## config frag.cpp fld `linkopts` contains whatever was passed
        ## by CLI using `--linkopt`
        linkopts  = None,

        # ocamlbuild = ctx.attr._ocamlbuild.files.to_list()[0],
        # ocamlfind  = ctx.attr._ocamlfind.files.to_list()[0],
        # ocamldep   = ctx.attr._ocamldep.files.to_list()[0],
        # objext     = ".cmx" if mode == "native" else ".cmo",
        # archext    = ".cmxa" if mode == "native" else ".cma",
    )]

## toolchain adapters bind tc interface to tc implementation
## implementation details are passed via attributes
# or: ocaml_toolchain_binding(
# ocaml_toolchain = rule(
ocaml_toolchain_adapter = rule(
    _ocaml_toolchain_adapter_impl,
    attrs = {

        "host": attr.string(
            doc     = "OCaml host platform: native or vm (bytecode).",
            default = "native"
        ),
        "target": attr.string(
            doc     = "OCaml target platform: native or vm (bytecode).",
            default = "native"
        ),

        "repl": attr.label(
            doc = "A/k/a 'toplevel': 'ocaml' command.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),

        "vmruntime": attr.label(
            doc = "ocamlrun, usually",
            allow_single_file = True, executable = True, cfg = "exec"
        ),
        "vmruntime_debug": attr.label(
            doc = "ocamlrund",
            allow_single_file = True, executable = True, cfg = "exec"
        ),
        "vmruntime_instrumented": attr.label(
            doc = "Usually the standard 'ocamlrun' interpreter.",
            allow_single_file = True, executable = True, cfg = "exec"
        ),



        "vmlibs": attr.label(
            doc = "Dynamically-loadable libs needed by the ocamlrun vm. Standard location: lib/stublibs. The libs are usually named 'dll<name>_stubs.so', e.g. 'dllcore_unix_stubs.so'.",
            allow_files = True,
        ),

        "compiler": attr.label(
            executable = True,
            ## providers constraints seem to be ignored
            # providers = [["OcamlArchiveMarker"]],
            allow_single_file = True,
            cfg = "exec",
        ),

        "profiling_compiler": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        "ocamllex": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        "ocamlyacc": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        ## DEPRECATED: with platforms and toolchains the 'compiler'
        ## attribute is sufficient - no need to list all compilers here.
        "ocamlc": attr.label(
            executable = True,
            ## providers constraints seem to be ignored
            # providers = [["OcamlArchiveMarker"]],
            allow_single_file = True,
            cfg = "exec",
        ),

        "ocamlc_opt": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        "ocamlopt": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        "ocamlopt_opt": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        # "_coqc": attr.label(
        #     default = Label("//tools:coqc"),
        #     executable = True,
        #     allow_single_file = True,
        #     cfg = "exec",
        # ),

        "linkmode": attr.string(
            doc = "Default link mode: 'static' or 'dynamic'"
            # default = "static"
        ),

        ## https://bazel.build/docs/integrating-with-rules-cc
        ## hidden attr required to make find_cpp_toolchain work:
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")
        ),
        # "_cc_opts": attr.string_list(
        #     default = ["-Wl,-no_compact_unwind"]
        # ),
    },

    doc = "Defines a Ocaml toolchain.",
    provides = [platform_common.ToolchainInfo],

    ## NB: config frags evidently expose CLI opts like `--cxxopt`;
    ## see https://docs.bazel.build/versions/main/skylark/lib/cpp.html
    fragments = ["cpp", "apple", "platform"],
    host_fragments = ["cpp", "apple", "platform"],

    ## ocaml toolchain adapter depends on cc toolchain?
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"]
)
