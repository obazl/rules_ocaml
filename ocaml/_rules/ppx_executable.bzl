load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider")

load("@obazl_rules_opam//opam/_providers:opam.bzl",
     "OpamPkgInfo")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name",
)

load("//ocaml/_providers:ocaml.bzl", "OcamlSDK")

load("//ppx/_transitions:transitions.bzl", "ppx_mode_transition")

load("//ppx:_providers.bzl",
     "PpxCompilationModeSettingProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load(":options_ppx.bzl", "options_ppx")

load(":impl_executable.bzl", "impl_executable")

#############################################
########## DECL:  PPX_EXECUTABLE  ################
ppx_executable = rule(
    implementation = impl_executable,
    doc = """Generates a PPX executable.  Provides: [PpxExecutableProvider](providers_ppx.md#ppxexecutableprovider).

By default, this rule adds `-predicates ppx_driver` to the command line.
    """,
    attrs = dict(
        options_ppx,
        _linkall     = attr.label(default = "@ppx//executable:linkall"),
        _threads     = attr.label(default = "@ppx//executable:threads"),
        _warnings  = attr.label(default = "@ppx//executable:warnings"),
        _opts = attr.label(
            ## We need this for '-predicates ppx_driver', to avoid hardcoding it in obazl rules
            doc = "Hidden options.",
            default = "@ppx//executable:opts"
        ),
        # linkopts = attr.string_list(),
        # IMPLICIT: args = string list = runtime args, passed whenever the binary is used
        exe_name = attr.string(
            doc = "Name for output executable file.  Overrides 'name' attribute."
        ),
        main = attr.label(
            doc = "A `ppx_module` to be listed last in the list of dependencies. For more information see [Main Module](../ug/ppx.md#main_module).",
            mandatory = True,
            # allow_single_file = [".ml", ".cmx"],
            providers = [[PpxModuleProvider], [OpamPkgInfo]],
            default = None
        ),
        ppx  = attr.label(
            doc = "PPX binary (executable).",
            providers = [PpxExecutableProvider],
            mandatory = False,
        ),
        print = attr.label(
            doc = "Format of output of PPX transform, binary (default) or text",
            default = "@ppx//print"
        ),
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
            providers = [[DefaultInfo], [PpxModuleProvider]]
        ),
        _deps = attr.label(
            doc = "Dependency to be added last.",
            default = "@ppx//executable:deps"
        ),
        adjunct_deps = attr.label_list(
            doc = """Adjunct dependencies.""",
            # providers = [[DefaultInfo], [PpxModuleProvider]]
        ),
        # adjunct_deps = attr.label_list(
        #     doc = """(Adjunct) eXtension Dependencies.""",
        #     # providers = [[DefaultInfo], [PpxModuleProvider]]
        # ),
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
        _mode = attr.label(
            default = "@ppx//mode",
            cfg     = ppx_mode_transition
        ),
        _allowlist_function_transition = attr.label(
            ## required for transition fn of attribute _mode
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        # _dllpaths = attr.label_list(
        #     # default = "@opam//:bin/cppo"
        #     default = [ # FIXME - get this from toolchain
        #         "@ocaml//:stublibs",
        #         # "@ocaml//:base_stubs",
        #         # "@ocaml//:bin_prot_stubs",
        #         # "@ocaml//:bigstringaf_stubs",
        #         # "@ocaml//:core_stubs",
        #         # "@ocaml//:expect_test_collector_stubs",
        #         # "@ocaml//:re2_stubs",
        #         # "@ocaml//:re2_c_stubs",
        #         # "@ocaml//:spawn_stubs",
        #         # "@ocaml//:time_now_stubs",
        #         # "@ocaml//:base_bigstring_stubs",
        #         # "@ocaml//:core_kernel_stubs",
        #     ]
        # ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        # message = attr.string()
        _rule = attr.string( default = "ppx_executable" )
    ),
    provides = [DefaultInfo, PpxExecutableProvider],
    executable = True,
    ## NB: 'toolchains' actually means 'toolchain types'
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
    # Attaching at rule transitions the configuration of this target and all its dependencies
    # (until it gets overwritten again, for example...)
)
