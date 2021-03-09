load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     # "DefaultMemo",
     "OcamlArchiveProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlSDK",
     "PpxArchiveProvider",
     "PpxLibraryProvider",
     "PpxModuleProvider",
     "PpxNsArchiveProvider",
     "PpxNsLibraryProvider")

load(":impl_executable.bzl", "impl_executable")

load("//ocaml/_transitions:transitions.bzl", "executable_in_transition")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_functions:utils.bzl",
     "file_to_lib_name",
     "get_opamroot",
     "get_sdkpath",
)

load(":options.bzl", "options", "options_executable")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "merge_deps")

################################
rule_options = options("ocaml")
rule_options.update(options_executable("ocaml"))

##################
ocaml_test = rule(
    implementation = impl_executable,
    doc = """OCaml test rule.

**CONFIGURABLE DEFAULTS** for rule `ocaml_test`

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
        rule_options,
        _rule = attr.string( default = "ocaml_test" ),
    ),
    cfg = executable_in_transition,
    test = True,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
