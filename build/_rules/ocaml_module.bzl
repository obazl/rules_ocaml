load("//build:providers.bzl",
     "OCamlModuleProvider",
     "OCamlDepsProvider",
     "OCamlNsResolverProvider")

load("//build/_transitions:in_transitions.bzl", "module_in_transition")

load("//build/_lib:options.bzl",
     "options",
     "options_module",
     "options_ns_opts",
     "options_ppx")

# load("//build/_rules/ocaml_module:api.bzl", "ocaml_module_api")
load("//build/_rules/ocaml_module:impl_module.bzl", "impl_module")

load("@rules_ocaml//lib:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCBLUBG", "CCMAG", "CCCYN", "CCRESET")

###############################
def _ocaml_module(ctx):

    # print("{c}ocaml_module: {m}{r}".format(
    #     c=CCBLUBG,m=ctx.label,r=CCRESET))

    # tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    # print("BUILD TGT: {color}{lbl}{reset}".format(
    #     color=CCYEL, reset=CCRESET, lbl=ctx.label))
    # print("  TC.NAME: %s" % tc.name)
    # print("  TC.HOST: %s" % tc.host)
    # print("  TC.TARGET: %s" % tc.target)
    # print("  TC.COMPILER: %s" % tc.compiler.basename)

    return impl_module(ctx) # , tc.target, tc.compiler, [])

################################
rule_options = options("rules_ocaml")
rule_options.update(options_module("ocaml"))
# rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

####################
ocaml_module = rule(
    implementation = _ocaml_module,
    doc = """
Compiles an OCaml module. The **module name** is determined by rule,
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
        struct = attr.label(
            doc = "A single module (struct) source file label.",
            mandatory = True,
            allow_single_file = True # no constraints on extension
        ),

        ## we have both a public and a hidden ns resolver attribute.
        ## this one is for bottom-up namespacing:
        ns = attr.label(
            doc = """
Label of an ocaml_ns target, which must list this module in its 'manifest' attribute. For bottom-up namespacing. Modules may use this attribute to elect membership in a bottom-up namespace.
            """,
            allow_single_file = True,
            providers = [OCamlNsResolverProvider],
            mandatory = False
        ),

        ## this one is for topdown-up namespacing:
        _ns_resolver = attr.label(
            doc = "NS resolver module for top-down namespacing",
            # allow_single_file = True,
            providers = [OCamlNsResolverProvider],
            ## @rules_ocaml//cfg/ns is a 'label_setting' whose value is an
            ## `ocaml_ns_resolver` rule. so this institutes a
            ## dependency on a resolver whose build params will be set
            ## dynamically using transition functions.
            default = "@rules_ocaml//cfg/ns:resolver",

            ## TRICKY BIT: if our struct is generated (e.g. by
            ## ocaml_lex), this transition will prevent ns renaming:
            # cfg = ocaml_module_deps_out_transition
        ),
        _rule = attr.string( default  = "ocaml_module" ),
        _tags = attr.string_list( default  = ["ocaml"] ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),

        _cmd_line_option = attr.label(default = "@rules_ocaml//cfg/option"),
    ),

    fragments      = ["platform", "cpp"],
    host_fragments = ["platform",  "cpp"],
    cfg            = module_in_transition,
    provides       = [OCamlModuleProvider, OCamlDepsProvider],
    executable     = False,
    toolchains     = ["@rules_ocaml//toolchain/type:std",
                      "@rules_ocaml//toolchain/type:profile",
                      "@bazel_tools//tools/cpp:toolchain_type"]
)

