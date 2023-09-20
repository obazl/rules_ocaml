load("//ocaml:providers.bzl",
     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker")

load("//ppx:providers.bzl",
     "PpxExecutableMarker",
)

load("//ocaml/_transitions:in_transitions.bzl",
     "ppx_executable_in_transition")

load("//ocaml/_transitions:out_transitions.bzl",
     "ocaml_binary_deps_out_transition")

load(":options.bzl", "options")

load(":impl_binary.bzl", "impl_binary")

load("//ocaml/_debug:colors.bzl", "CCDER", "CCGAM", "CCRESET")

CCBLURED="\033[44m\033[31m"

################################################
def _ppx_deps_out_transition_impl(settings, attr):
    # print("{c}_ppx_deps_out_transition{r}: {lbl}".format(
    #     c=CCDER, r = CCRESET, lbl = attr.name
    # ))

    return {
        "@rules_ocaml//cfg/ns:prefixes":   [],
        "@rules_ocaml//cfg/ns:submodules": []
    }

################
_ppx_deps_out_transition = transition(
    implementation = _ppx_deps_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

###########################
def _ppx_executable(ctx):

    # print("{c}ppx_executable: {m}{r}".format(
    #     c=CCBLURED,m=ctx.label,r=CCRESET))

    # if True: #  debug_tc:
    #     tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    #     print("BUILD TGT: {color}{lbl}{reset}".format(
    #         color=CCGAM, reset=CCRESET, lbl=ctx.label))
    #     print("  TC.NAME: %s" % tc.name)
    #     print("  TC.HOST: %s" % tc.host)
    #     print("  TC.TARGET: %s" % tc.target)
    #     print("  TC.COMPILER: %s" % tc.compiler.basename)

    return impl_binary(ctx) # , tc.target, tc, tc.compiler, [])

########## DECL:  PPX_EXECUTABLE  ################
ppx_executable = rule(
    implementation = _ppx_executable,
    doc = """Generates a PPX executable.  Provides: [PpxExecutableMarker](providers_ppx.md#ppxexecutableprovider).

    """,
    attrs = dict(
        options("ppx"),
        _linkall = attr.label(default = "@rules_ocaml//ppx/executable:linkall"),
        # _linkall     = attr.label(default = "@ppx//executable/linkall"),
        # threading is supported by pkg @ocaml//threads; just add it
        # as a dep
        # _threads     = attr.label(default = "@ppx//executable/threads"),
        _warnings  = attr.label(default = "@rules_ocaml//ppx/executable:warnings"),
        _opts = attr.label(
            doc = "Hidden options.",
            default = "@rules_ocaml//ppx/executable:opts"
        ),
        # IMPLICIT: args = string list = runtime args, passed whenever the binary is used
        exe = attr.string(
            doc = "Name for output executable file.  Overrides 'name' attribute."
        ),

        bin = attr.label( # 'import' would be better but it's a keyword
            doc = "Precompiled ppx executable",
            allow_single_file = True,
        ),

        prologue = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OcamlArchiveMarker],
                         [OcamlImportMarker],
                         [OcamlLibraryMarker],
                         [OcamlModuleMarker],
                         [OcamlNsMarker],
                         [CcInfo]],
            cfg = _ppx_deps_out_transition
            # cfg = ocaml_binary_deps_out_transition
        ),

        main = attr.label(
            doc = "A module to be listed after those in 'initial' and after those in 'final'. For more information see [Main Module](../ug/ppx.md#main_module).",
            mandatory = True,
            # allow_single_file = True,
            # providers = [
            #     [OcamlModuleMarker], [PpxExecutableMarker]
            #     # or @ppxlib//lib/runner"
            # ],
            default = None,
            # cfg = ocaml_binary_deps_out_transition
        ),
        epilogue = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OcamlArchiveMarker],
                         [OcamlImportMarker],
                         [OcamlLibraryMarker],
                         [OcamlModuleMarker],
                         [OcamlNsMarker],
                         [CcInfo]],
            cfg = _ppx_deps_out_transition
            # cfg = ocaml_binary_deps_out_transition
        ),

        # finalizer = attr.label(),

        # FIXME: no need for ppx attrib on ppx_executable?
        # (since no source files)
        # ppx  = attr.label(
        #     doc = "PPX binary (executable).",
        #     providers = [PpxExecutableMarker],
        #     mandatory = False,
        # ),
        # print = attr.label(
        #     doc = "Format of output of PPX transform, binary (default) or text",
        #     default = "@ppx//print"
        # ),

        ## NB: 'args' is built-in, cannot add as attrib
        # runtime_args = attr.string_list(
        # args = attr.string_list(
        #     doc = "List of args that will be passed to the ppx_executable at runtime. E.g. -inline-test-lib. CAVEAT: will be used wherever the exec is run, and passed before command line args.  For finer granularity use the 'ppx_args' attr of e.g. ocaml_module."
        # ),

        data  = attr.label_list(
            doc = "Runtime data dependencies. E.g. a file used by %%import from ppx_optcomp.",
            allow_files = True,
        ),

        data_prefix_map = attr.string_dict(
            doc = "Map for replacing path prefixes of data files"
        ),

        # strip_data_prefixes = attr.bool(
        #     doc = "Symlink each data file to the basename part in the runfiles root directory. E.g. test/foo.data -> foo.data.",
        #     default = False
        # ),

        # manifest = attr.label_list(
        #     doc = "Mereological deps to be directly linked into ppx executable. Modular deps should be listed in ocaml_module, ppx_module rules.",
        #     providers = [[DefaultInfo], [OcamlModuleMarker], [CcInfo]],
        #     cfg = _ppx_deps_out_transition
        # ),

        # _deps = attr.label(
        #     doc = "Dependency to be added last.",
        #     default = "@rules_ocaml//ppx/executable:deps"
        # ),

        ## ppx_executable only
        ppx_codeps = attr.label_list(
            doc = """List of non-opam adjunct dependencies (labels).""",
            mandatory = False,
            # FIXME: for jsoo, codeps must pass on js files. :(
            # otherwise the link action would have to transpile them
            cfg = "target"
            # providers = [[DefaultInfo], [PpxModuleMarker]]
        ),

        ppx_runner = attr.label_list(
            doc = """Modules to be linked last when the transformed module is linked into an executable.""",
            mandatory = False,
            cfg = "target"
            # providers = [[DefaultInfo], [PpxModuleMarker]]
        ),

        ################
        cc_deps = attr.label_keyed_string_dict(
            doc = "C/C++ library dependencies",
            providers = [[CcInfo]]
        ),
        _cc_deps = attr.label(
            doc = "Global C/C++ library dependencies. Apply to all instances of ocaml_binary.",
            ## FIXME: cc libs could come from LSPs that do not support CcInfo, e.g. rules_rust
            # providers = [[CcInfo]]
            default = "@rules_ocaml//cfg/executable:cc_deps"
        ),
        cc_linkall = attr.label_list(
            ## equivalent to cc_library's "alwayslink"
            doc     = "True: use `-whole-archive` (GCC toolchain) or `-force_load` (Clang toolchain). Deps in this attribute must also be listed in cc_deps.",
            # providers = [CcInfo],
        ),
        cc_linkopts = attr.string_list(
            doc = "List of C/C++ link options. E.g. `[\"-lstd++\"]`.",

        ),

        vm_runtime = attr.label(
            doc = "@ocaml_rules//cfg/runtime:dynamic (default), @ocaml_rules//cfg/runtime:static, or a custom ocaml_vm_runtime target label",
            default = "@rules_ocaml//cfg/runtime:dynamic"
        ),

        _rule = attr.string( default = "ppx_executable" ),
        _tags = attr.string_list( default  = ["ppx", "executable"] ),

        _allowlist_function_transition = attr.label(
            ## required for transition fn of attribute _mode
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),

    ),
    cfg     = ppx_executable_in_transition,
    provides = [DefaultInfo, PpxExecutableMarker],
    executable = True,
    ## NB: 'toolchains' actually means 'toolchain types'
    toolchains = [
        "@rules_ocaml//toolchain/type:std",
        "@rules_ocaml//toolchain/type:profile",
        # "@bazel_tools//tools/cpp:toolchain_type"
    ],
)
