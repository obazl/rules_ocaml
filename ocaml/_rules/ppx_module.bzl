load("//ocaml:providers.bzl",
     "OcamlModuleMarker",
     "OcamlNsResolverProvider")

load("//ppx:providers.bzl", "PpxModuleMarker")

load("//ocaml/_transitions:transitions.bzl", "module_in_transition")

load(":options.bzl",
     "options",
     "options_module",
     "options_ns_opts",
     "options_ppx")

load(":impl_module.bzl", "impl_module")

###############################
def _ppx_module(ctx):

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    return impl_module(ctx, tc.target, tc.compiler, [])

################################
rule_options = options("ocaml")
rule_options.update(options_module("ocaml"))
# rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

####################
ppx_module = rule(
    implementation = _ppx_module,
 # Provides: [OcamlModuleMarker](providers_ocaml.md#ocamlmoduleprovider).
    doc = """

Compiles a PPX module. Same as ocaml_module but with added ppx_codeps
attribute. A ppx_module may depend on a standard ocaml_module, but not
the other way around.

The **module name** is determined by rule,
based on the `struct`, `sig`, `name`, and `module` attributes:

* If the `sig` attribute is the label of an `ocaml_signature` target,
  then the module name is derived from the name of the compiled
  sigfile, since compiled interface files cannot be renamed. The
  structfile will be renamed if it does not match the sigfile name.

* If the `sig` attribute is a filename, then:

** if its principal name is equal to the principal name of the file
   named in the `struct` attribute, then the module name is derived
   from it.

** if the principal names of the sigfile and structfile do not match,
   then the module name is derived from from the `name` attribute.
   Both the sigfile and the structfile will be renamed accordingly.

** The `module` attribute may be used to force the module name. Both
   the sigfile and the structfile will be renamed accordingly.

* If the `sig` attribute is not specified (i.e. the structfile is
  "orphaned"), then the module name will be derived from the
  structfile name, unless the `module` attribute is specified, in
  which case it overrides.

**CONFIGURABLE DEFAULTS** for rule `ocaml_module`:

In addition to the <<Configurable defaults>> that apply to all
`ocaml_*` rules, the following apply to this rule:

**Options**

[.rule_attrs]
[cols="1,1,1"]
|===
| Label | Default | Comments

| @rules_ocaml//cfg/module:deps | `@rules_ocaml//cfg:null` | list of OCaml deps to add to all `ocaml_module` instances

| @rules_ocaml//cfg/module:cc_deps^1^ | `@rules_ocaml//cfg:null` | list of cc_deps to add to all `ocaml_module` instances

| @rules_ocaml//cfg/module:cc_linkstatic^1^ | `@rules_ocaml//cfg:null` | list of cc_deps to link statically (DEPRECATED)

| @rules_ocaml//cfg/module:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| sets `-w` option for all `ocaml_module` instances

|===

^1^ See link:../user-guide/dependencies-cc[CC Dependencies] for more information on CC deps.

**Boolean Flags**

NOTE: These do not support `:enable`, `:disable` syntax.

[.rule_attrs]
[cols="1,1,1"]
|===
| Label | Default | `opts` attrib equivalent

| @rules_ocaml//cfg/module/linkall | False | `-linkall`, `-no-linkall`

| @rules_ocaml//cfg/module:verbose | False | `-verbose`, `-no-verbose`

|===

    """,
    attrs = dict(
        rule_options,

        ppx_codeps = attr.label_list(
            doc = """List of non-opam adjunct dependencies (labels).""",
            mandatory = False
            # providers = [[DefaultInfo], [PpxModuleMarker]]
        ),

    ),

    fragments = ["platform"],
    host_fragments = ["platform"],
    incompatible_use_toolchain_transition = True,
    # exec_groups = {
    #     "compile": exec_group(
    #         exec_compatible_with = [
    #             # "@platforms//os:linux",
    #             "@platforms//os:macos"
    #         ],
    #         toolchains = [
    #             "@rules_ocaml//toolchain:type",
    #             # "@rules_ocaml//cfg/coq:toolchain_type",
    #         ],
    #     ),
    # },
    cfg     = module_in_transition,
    provides = [OcamlModuleMarker, PpxModuleMarker],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain:type",
                  "@bazel_tools//tools/cpp:toolchain_type"
                  ],
)

