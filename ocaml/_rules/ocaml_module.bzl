load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "OcamlModuleMarker",
     "OcamlNsResolverProvider")

load("//ocaml/_transitions:transitions.bzl", "module_in_transition")

load(":options.bzl",
     "options",
     "options_module",
     "options_ns_opts",
     "options_ppx")

load(":impl_module.bzl", "impl_module")

###############################
def _ocaml_module(ctx):

    tc = ctx.toolchains["@ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    if mode == "native":
        tool = tc.ocamlopt # .basename
    else:
        tool = tc.ocamlc  #.basename

    tool_args = []

    return impl_module(ctx, mode, tool, tool_args)

################################
rule_options = options("ocaml")
rule_options.update(options_module("ocaml"))
rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

####################
ocaml_module = rule(
    implementation = _ocaml_module,
    doc = """Compiles an OCaml module. Provides: [OcamlModuleMarker](providers_ocaml.md#ocamlmoduleprovider).

**CONFIGURABLE DEFAULTS** for rule `ocaml_module`

In addition to the [OCaml configurable defaults](#configdefs) that apply to all
`ocaml_*` rules, the following apply to this rule:

**Options**

| Label | Default | Notes |
| ----- | ------- | ------- |
| @ocaml//module:deps | `@ocaml//:null` | list of OCaml deps to add to all `ocaml_module` instances |
| @ocaml//module:cc_deps<sup>1</sup> | `@ocaml//:null` | list of cc_deps to add to all `ocaml_module` instances |
| @ocaml//module:cc_linkstatic<sup>1</sup> | `@ocaml//:null` | list of cc_deps to link statically (DEPRECATED) |
| @ocaml//module:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| sets `-w` option for all `ocaml_module` instances |

<sup>1</sup> See [CC Dependencies](../ug/cc_deps.md) for more information on CC deps.

**Boolean Flags**

| Label | Default | `opts` attrib |
| ----- | ------- | ------- |
| @ocaml//module:linkall | True | `-linkall`, `-no-linkall`|
| @ocaml//module:thread  | True | `-thread`, `-no-thread`|
| @ocaml//module:verbose | True | `-verbose`, `-no-verbose`|

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(

        rule_options,

        _ns_resolver = attr.label(
            doc = "NS resolver module",
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            ## @ocaml//ns is a 'label_setting' whose value is an
            ## `ocaml_ns_resolver` rule. so this institutes a
            ## dependency on a resolver whose build params will be set
            ## dynamically using transition functions.
            default = "@ocaml//ns", ## FIXME rename: @ocaml//ns:resolver

            ## TRICKY BIT: if our struct is generated (e.g. by
            ## ocaml_lex), this transition will prevent ns renaming:
            # cfg = ocaml_module_deps_out_transition
        ),

        _warnings = attr.label(
            default = "@ocaml//module:warnings"
        ),

        _rule = attr.string( default = "ocaml_module" ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    incompatible_use_toolchain_transition = True,
    # exec_groups = {
    #     "compile": exec_group(
    #         exec_compatible_with = [
    #             # "@platforms//os:linux",
    #             "@platforms//os:macos"
    #         ],
    #         toolchains = [
    #             "@ocaml//ocaml:toolchain",
    #             # "@ocaml//coq:toolchain_type",
    #         ],
    #     ),
    # },
    cfg     = module_in_transition,
    provides = [OcamlModuleMarker],
    executable = False,
    toolchains = ["@ocaml//ocaml:toolchain"],
)
