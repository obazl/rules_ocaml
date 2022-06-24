load("//ocaml:providers.bzl",
     "OcamlModuleMarker")

load("//ppx:providers.bzl",
     "PpxExecutableMarker",
)

load("//ocaml/_transitions:transitions.bzl",
     "ocaml_executable_deps_out_transition",
     "executable_in_transition")

load(":options.bzl", "options")

load(":impl_executable.bzl", "impl_executable")

###########################
def _ppx_executable(ctx):

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    return impl_executable(ctx, tc.emitting, tc, tc.compiler, [])

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
        exe_name = attr.string(
            doc = "Name for output executable file.  Overrides 'name' attribute."
        ),

        bin = attr.label(
            doc = "Precompiled ppx executable",
            allow_single_file = True,
        ),

        # initializer = attr.label(),
        main = attr.label(
            doc = "A module to be listed last in the list of dependencies. For more information see [Main Module](../ug/ppx.md#main_module).",
            # mandatory = True,
            allow_single_file = True,
            providers = [[OcamlModuleMarker], [PpxExecutableMarker]],
            default = None,
            # cfg = ocaml_executable_deps_out_transition
        ),
        # finalizer = attr.label(),

        _stublibs = attr.label_list(
            default = ["@stublibs//:stublibs"]
        ),

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

        ##FIXME: use std 'args' attrib, common to all "*_binary" rules
        runtime_args = attr.string_list(
            doc = "List of args that will be passed to the ppx_executable at runtime. E.g. -inline-test-lib. CAVEAT: will be used wherever the exec is run, and passed before command line args.  For finer granularity use the 'ppx_args' attr of e.g. ocaml_module."
        ),

        data  = attr.label_list(
            doc = "Runtime data dependencies. E.g. a file used by %%import from ppx_optcomp.",
            allow_files = True,
        ),
        strip_data_prefixes = attr.bool(
            doc = "Symlink each data file to the basename part in the runfiles root directory. E.g. test/foo.data -> foo.data.",
            default = False
        ),
        deps = attr.label_list(
            doc = "Deps needed to build this ppx executable.",
            providers = [[DefaultInfo], [OcamlModuleMarker], [CcInfo]],
            # cfg = ocaml_executable_deps_out_transition
        ),
        # _deps = attr.label(
        #     doc = "Dependency to be added last.",
        #     default = "@rules_ocaml//ppx/executable:deps"
        # ),
        ppx_codeps = attr.label_list(
            doc = """List of non-opam adjunct dependencies (labels).""",
            mandatory = False
            # providers = [[DefaultInfo], [PpxModuleMarker]]
        ),
        cc_deps = attr.label_keyed_string_dict(
            doc = "C/C++ library dependencies",
            providers = [[CcInfo]]
        ),
        _cc_deps = attr.label(
            doc = "Global C/C++ library dependencies. Apply to all instances of ocaml_executable.",
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
        _rule = attr.string( default = "ppx_executable" ),
        # _sdkpath = attr.label(
        #     default = Label("@rules_ocaml//cfg:sdkpath")
        # ),
        # _allowlist_function_transition = attr.label(
        #     ## required for transition fn of attribute _mode
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),

    ),
    # cfg     = executable_in_transition,
    # provides = [DefaultInfo, PpxExecutableMarker],
    executable = True,
    ## NB: 'toolchains' actually means 'toolchain types'
    toolchains = ["@rules_ocaml//toolchain:type"],
)
