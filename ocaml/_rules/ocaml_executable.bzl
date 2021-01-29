load("//ocaml/_providers:ocaml.bzl",
     "OcamlArchiveProvider",
     "OcamlLibraryProvider",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider")

load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl", "PpxInfo", "PpxArchiveProvider")

load(":options_ocaml.bzl", "options_ocaml")

load(":impl_executable.bzl", "impl_executable")

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
| @ocaml//executable:threads | True | `-thread`, `-no-thread`|
| @ocaml//executable:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value |

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        options_ocaml,
        _linkall     = attr.label(default = "@ocaml//executable:linkall"),
        _threads     = attr.label(default = "@ocaml//executable:threads"),
        _warnings  = attr.label(default   = "@ocaml//executable:warnings"),
        _opts = attr.label(
            doc = "Hidden options.",
            default = "@ocaml//executable:opts"
        ),
        exe_name = attr.string(
            doc = "Name for output executable file.  Overrides 'name' attribute."
        ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        main = attr.label(
            doc = "Label of module containing entry point of executable. This module will be placed last in the list of dependencies.",
            # allow_single_file doesn't work - ocaml deps produce at least two files (module + interface)
            providers = [[OcamlModuleProvider], [OpamPkgInfo]],
            default = None
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
            providers = [[OpamPkgInfo],
                         [OcamlArchiveProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsModuleProvider],
                         [PpxArchiveProvider],
                         [CcInfo]],
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
        _mode = attr.label(
            default = "@ocaml//mode"
            # cfg     = ocaml_mode_transition
        ),
        message = attr.string( doc = "Deprecated" ),
        _rule = attr.string( default  = "ocaml_executable" )
    ),
    executable = True,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
