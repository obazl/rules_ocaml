load("//build/_rules/ocaml_binary:impl_binary.bzl", "impl_binary")

load("//build/_lib:apis.bzl", "options", "options_binary")

load("//build/_transitions:in_transitions.bzl",
     "toolchain_in_transition")

load("//lib:colors.bzl", "CCYEL", "CCRESET")

###############################
def _ocaml_test(ctx):

    # print("ctx.attr.constraint_deps: %s" % ctx.attr.constraint_deps)
    # for dep in ctx.attr.constraint_deps:
    #     print("constraint_deps[DefaultInfo]: %s" % dep[DefaultInfo])
    #     print("constraint_deps[BuildSettingInfo]: %s" % dep[BuildSettingInfo])

    # tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    # print("BUILD TGT: {color}{lbl}{reset}".format(
    #     color=CCYEL, reset=CCRESET, lbl=ctx.label))

    # print("  TC.NAME: %s" % tc.name)
    # print("  TC.HOST: %s" % tc.host)
    # print("  TC.TARGET: %s" % tc.target)
    # print("  TC.COMPILER: %s" % tc.compiler.basename)

    return impl_binary(ctx) # , tc.target, tc, tc.compiler, [])

################################
rule_options = options("rules_ocaml")
rule_options.update(options_binary())

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

        diff_cmd = attr.label(
            allow_single_file = True
            # e.g. diff_cmd = "@patdiff//bin:patdiff"
        ),

        _rule = attr.string( default = "ocaml_test" ),
        _tags = attr.string_list( default  = ["ocaml", "test"] ),

        cc_libs = attr.label_list(),

        ## https://bazel.build/docs/integrating-with-rules-cc
        ## hidden attr required to make find_cpp_toolchain work:
        # _cc_toolchain = attr.label(
        #     default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")
        # ),
    ),
    cfg = toolchain_in_transition,
    # cfg = executable_in_transition,
    test = True,
    fragments = ["platform", "cpp"],
    host_fragments = ["platform",  "cpp"],
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)
