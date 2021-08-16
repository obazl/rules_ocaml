load("//ocaml:providers.bzl", "OcamlModuleProvider")

load("//ocaml/_transitions:transitions.bzl", "module_in_transition")

load(":options.bzl",
     "options",
     "options_module",
     "options_ns_opts",
     "options_ppx")

load(":impl_module.bzl", "impl_module")

################################
rule_options = options("ocaml")
rule_options.update(options_module("ocaml"))
rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

####################
ocaml_module = rule(
    implementation = impl_module,
    doc = """Compiles an OCaml module. Provides: [OcamlModuleProvider](providers_ocaml.md#ocamlmoduleprovider).

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
        _rule = attr.string( default = "ocaml_module" ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        _opam_lib = attr.label(
            default = "@opam//:opam_lib"
        )
    ),
    incompatible_use_toolchain_transition = True,
    # exec_groups = {
    #     "compile": exec_group(
    #         exec_compatible_with = [
    #             # "@platforms//os:linux",
    #             "@platforms//os:macos"
    #         ],
    #         toolchains = [
    #             "@obazl_rules_ocaml//ocaml:toolchain",
    #             # "@obazl_rules_ocaml//coq:toolchain_type",
    #         ],
    #     ),
    # },
    # cfg     = module_in_transition,
    provides = [OcamlModuleProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
