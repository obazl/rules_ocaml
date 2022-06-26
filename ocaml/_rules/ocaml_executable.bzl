load("//ocaml:providers.bzl", "OcamlExecutableMarker", "OcamlModuleMarker")

load(":options.bzl", "options", "options_executable")

load(":impl_executable.bzl", "impl_executable")

load("//ocaml/_transitions:transitions.bzl", "executable_in_transition")
## load("//ocaml/_transitions:ns_transitions.bzl", "nsarchive_in_transition")

###############################
def _ocaml_executable(ctx):

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    return impl_executable(ctx, tc.emitting, tc, tc.compiler, [])

################################
rule_options = options("ocaml")
rule_options.update(options_executable("ocaml"))

########################
ocaml_executable = rule(
    implementation = _ocaml_executable,

    doc = """Generates an OCaml executable binary. Provides only standard DefaultInfo provider.

**CONFIGURABLE DEFAULTS** for rule `ocaml_executable`

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

        _rule = attr.string( default  = "ocaml_executable" ),

        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    provides = [OcamlModuleMarker,OcamlExecutableMarker],
    ## this is not an ns archive, and it does not use ns ConfigState,
    ## but we need to reset the ConfigState anyway, so the deps are
    ## not affected if this is a dependency of an ns aggregator.
    # cfg     = nsarchive_in_transition,
    # cfg     = executable_in_transition,
    executable = True,
    toolchains = ["@rules_ocaml//toolchain:type"],
)
