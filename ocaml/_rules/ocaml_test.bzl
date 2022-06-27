load(":impl_executable.bzl", "impl_executable")

load("//ocaml/_transitions:transitions.bzl", "executable_in_transition")

load(":options.bzl", "options", "options_executable")

###############################
def _ocaml_test(ctx):

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    return impl_executable(ctx, tc.target, tc, tc.compiler, [])

################################
rule_options = options("ocaml")
rule_options.update(options_executable("ocaml"))

##################
ocaml_test = rule(
    implementation = _ocaml_test,
    doc = """OCaml test rule.

**CONFIGURABLE DEFAULTS** for rule `ocaml_test`

In addition to the [OCaml configurable defaults](#configdefs) that apply to all
`ocaml_*` rules, the following apply to this rule:

| Label | Default | `opts` attrib |
| ----- | ------- | ------- |
| @rules_ocaml//cfg/executable:linkall | True | `-linkall`, `-no-linkall`|
| @rules_ocaml//cfg/executable:threads | False | true: `-I +thread`|
| @rules_ocaml//cfg/executable:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value |

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        rule_options,
        _rule = attr.string( default = "ocaml_test" ),

        ## https://bazel.build/docs/integrating-with-rules-cc
        ## hidden attr required to make find_cpp_toolchain work:
        _cc_toolchain = attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")
        ),
    ),
    # cfg = executable_in_transition,
    test = True,
    toolchains = [
        "@rules_ocaml//toolchain:type",
        "@bazel_tools//tools/cpp:toolchain_type"
    ],
)
