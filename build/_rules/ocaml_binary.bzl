load("//build:providers.bzl", "OcamlExecutableMarker", "OCamlModuleProvider")

load("//build/_lib:apis.bzl", "options", "options_binary")

load("//build/_rules/ocaml_binary:impl_binary.bzl", "impl_binary")

load("//build/_transitions:ocaml_executable_in_transition.bzl",
     "ocaml_executable_in_transition")

load("//lib:colors.bzl", "CCRED", "CCMAG", "CCRESET")

###############################
def _ocaml_binary(ctx):

    # print("{c}ocaml_binary: {m}{r}".format(
    #     c=CCBLURED,m=ctx.label,r=CCRESET))

    # if True: #  debug_tc:
    #     tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    #     print("BUILD TGT: {color}{lbl}{reset}".format(
    #         color=CCMAG, reset=CCRESET, lbl=ctx.label))
    #     print("  TC.NAME: %s" % tc.name)
    #     print("  TC.HOST: %s" % tc.host)
    #     print("  TC.TARGET: %s" % tc.target)
    #     print("  TC.COMPILER: %s" % tc.compiler.basename)

    return impl_binary(ctx) # , tc.target, tc, tc.compiler, [])

################################
rule_options = options("rules_ocaml")
rule_options.update(options_binary())

########################
ocaml_binary = rule(
    implementation = _ocaml_binary,

    doc = """Generates an OCaml executable binary.

**CONFIGURABLE DEFAULTS** for rule `ocaml_binary`

In addition to the <<Configurable defaults>> that
apply to all `ocaml_*` rules, the following apply to this rule. (Note
the difference between '/' and ':' in such labels):

[.rule_attrs]
[cols="1,1,1"]
|===
| Label | Default | `opts` attrib

| @rules_ocaml//cfg/executable/linkall | True | `-linkall`, `-no-linkall`

| @rules_ocaml//cfg/executable:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value

|===

// | @rules_ocaml//cfg/executable/threads | True | `-thread`, `-no-thread`


**NOTE** These do not support `:enable`, `:disable` syntax.

    """,
    attrs = dict(
        rule_options,

        ## FIXME: get cclibs from toolchain?
        _cclibs = attr.label_list( ## for ppx only
            # default = ["@cclibs//:cclibs"]
        ),

        _rule = attr.string( default  = "ocaml_binary" ),
        _tags = attr.string_list( default  = ["ocaml", "binary"] ),

        ## required, so we can obtain the cc tc and inspect it
        ## to determine if we need to -UDEBUG
        _cc_toolchain = attr.label(
            default = Label(
                # "@bazel_tools//tools/cpp:current_cc_toolchain"
                "@rules_cc//cc:current_cc_toolchain",
            )
        ),

        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    provides = [OcamlExecutableMarker], # OCamlModuleProvider],
    ## this is not an ns archive, and it does not use ns ConfigState,
    ## but we need to reset the ConfigState anyway, so the deps are
    ## not affected if this is a dependency of an ns aggregator.
    # cfg     = nsarchive_in_transition,
    cfg     = ocaml_executable_in_transition,
    executable = True,
    toolchains = [
        "@rules_ocaml//toolchain/type:std",
        "@rules_ocaml//toolchain/type:profile",
        "@bazel_tools//tools/cpp:toolchain_type"
    ],
    fragments = ["cpp"],
)
