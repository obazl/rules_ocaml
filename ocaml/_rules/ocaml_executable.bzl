load("//ocaml:providers.bzl", "PpxInfo", "PpxArchiveProvider")

load(":options.bzl", "options", "options_executable")

load(":impl_executable.bzl", "impl_executable")

load("//ocaml/_transitions:transitions.bzl", "executable_in_transition")

################################
rule_options = options("ocaml")
rule_options.update(options_executable("ocaml"))

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
        rule_options,
        _rule = attr.string( default  = "ocaml_executable" ),
    ),
    cfg = executable_in_transition,
    executable = True,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
