load("//ocaml:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlLibraryProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlModuleProvider",
     "PpxModuleProvider")

load("//ocaml:providers.bzl", "PpxInfo", "PpxArchiveProvider")

load(":options.bzl", "options")

load(":impl_executable.bzl", "impl_executable")

load("//ocaml/_transitions:transitions.bzl",
     "executable_in_transition")

########################
ocaml_executable = rule(
    implementation = impl_executable,

    doc = """Generates an OCaml executable binary. Provides only standard DefaultInfo provider.

**CONFIGURABLE DEFAULTS** for rule `ocaml_executable`

In addition to the [OCaml configurable defaults](#configdefs) that apply to all
`ocaml_*` rules, the following apply to this rule:

| Label | Default | `opts` attrib |
| ----- | ------- | ------- |
| @ocaml//executable:linkall | True | `-linkall`, `-no-linkall`|
| @ocaml//executable:thread | True | `-thread`, `-no-thread`|
| @ocaml//executable:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value |

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        options("ocaml"),
        _linkall     = attr.label(default = "@ocaml//executable/linkall"),
        _thread     = attr.label(default = "@ocaml//executable/thread"),
        _warnings  = attr.label(default   = "@ocaml//executable:warnings"),
        _opts = attr.label(
            doc = "Hidden options.",
            default = "@ocaml//executable:opts"
        ),
        # exe_name = attr.string(
        #     doc = "Name for output executable file.  Overrides 'name' attribute."
        # ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        main = attr.label(
            doc = "Label of module containing entry point of executable. This module will be placed last in the list of dependencies.",
            # allow_single_file doesn't work - ocaml deps produce at least two files (module + interface)
            providers = [[OcamlModuleProvider], [PpxModuleProvider]],
        ),
        data = attr.label_list(
            allow_files = True,
            doc = "Runtime dependencies: list of labels of data files needed by this executable at runtime."
        ),
        strip_data_prefixes = attr.bool(
            doc = "Symlink each data file to the basename part in the runfiles root directory. E.g. test/foo.data -> foo.data.",
            default = False
        ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OcamlArchiveProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsArchiveProvider],
                         [OcamlNsLibraryProvider],
                         [PpxArchiveProvider],
                         [CcInfo]],
            # cfg = ocaml_executable_deps_out_transition
        ),
        _deps = attr.label(
            doc = "Dependency to be added last.",
            default = "@ocaml//executable:deps"
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
            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            ## FIXME: cc libs could come from LSPs that do not support CcInfo, e.g. rules_rust
            # providers = [[CcInfo]]
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
        mode = attr.string(
            # default = "@ocaml//mode"
            # cfg     = ocaml_mode_transition
        ),
        _mode = attr.label(
            default = "@ocaml//mode"
            # cfg     = ocaml_mode_transition
        ),
        message = attr.string( doc = "Deprecated" ),
        _rule = attr.string( default  = "ocaml_executable" ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    cfg = executable_in_transition,
    executable = True,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
