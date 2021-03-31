load("//ocaml:providers.bzl",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("//ocaml/_transitions:transitions.bzl", "executable_in_transition")

load(":options.bzl", "options")

load(":impl_executable.bzl", "impl_executable")

#############################################
########## DECL:  PPX_EXECUTABLE  ################
ppx_executable = rule(
    implementation = impl_executable,
    doc = """Generates a PPX executable.  Provides: [PpxExecutableProvider](providers_ppx.md#ppxexecutableprovider).

By default, this rule adds `-predicates ppx_driver` to the command line.
    """,
    attrs = dict(
        options("ppx"),
        _linkall     = attr.label(default = "@ppx//executable/linkall"),
        _thread     = attr.label(default = "@ppx//executable/thread"),
        _warnings  = attr.label(default = "@ppx//executable:warnings"),
        _opts = attr.label(
            ## We need this for '-predicates ppx_driver', to avoid hardcoding it in obazl rules
            doc = "Hidden options.",
            default = "@ppx//executable:opts"
        ),
        # IMPLICIT: args = string list = runtime args, passed whenever the binary is used
        exe_name = attr.string(
            doc = "Name for output executable file.  Overrides 'name' attribute."
        ),
        main = attr.label(
            doc = "A `ppx_module` to be listed last in the list of dependencies. For more information see [Main Module](../ug/ppx.md#main_module).",
            # mandatory = True,
            # allow_single_file = [".ml", ".cmx"],
            providers = [[PpxModuleProvider]],
            default = None
        ),
        ppx  = attr.label(
            doc = "PPX binary (executable).",
            providers = [PpxExecutableProvider],
            mandatory = False,
        ),
        # print = attr.label(
        #     doc = "Format of output of PPX transform, binary (default) or text",
        #     default = "@ppx//print"
        # ),
        runtime_args = attr.string_list(
            doc = "List of args that must be passed to the ppx_executable at runtime. E.g. -inline-test-lib."
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
            providers = [[DefaultInfo], [PpxModuleProvider]],
        ),
        _deps = attr.label(
            doc = "Dependency to be added last.",
            default = "@ppx//executable:deps"
        ),
        deps_opam = attr.string_list(
            doc = "List of OPAM package names"
        ),
        deps_adjunct = attr.label_list(
            doc = """List of non-opam adjunct dependencies (labels).""",
            # providers = [[DefaultInfo], [PpxModuleProvider]]
        ),
        deps_adjunct_opam = attr.string_list(
            doc = """List of opam adjunct dependencies (pkg name strings).""",
        ),
        cc_deps = attr.label_keyed_string_dict(
            doc = "C/C++ library dependencies",
            providers = [[CcInfo]]
        ),
        _cc_deps = attr.label(
            doc = "Global C/C++ library dependencies. Apply to all instances of ocaml_executable.",
            ## FIXME: cc libs could come from LSPs that do not support CcInfo, e.g. rules_rust
            # providers = [[CcInfo]]
            default = "@ocaml//executable:cc_deps"
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
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        _allowlist_function_transition = attr.label(
            ## required for transition fn of attribute _mode
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    cfg     = executable_in_transition,
    # provides = [DefaultInfo, PpxExecutableProvider],
    executable = True,
    ## NB: 'toolchains' actually means 'toolchain types'
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
