load("//ocaml:providers.bzl",
     "OcamlModuleMarker",
     "OcamlNsResolverProvider")

load("//ppx:providers.bzl", "PpxModuleMarker")

load("//ocaml/_transitions:in_transitions.bzl", "module_in_transition")

load(":options.bzl",
     "options",
     "options_module",
     "options_ns_opts",
     "options_ppx")

load(":impl_module.bzl", "impl_module")

load("@rules_ocaml//ocaml/_debug:colors.bzl",
     "CCRED", "CCDER", "CCGRN", "CCBLU", "CCBLUBG", "CCMAG", "CCCYN", "CCRESET")


################################################
## ppx codeps should not inheret namespace of ppx module.
## this transition resets the config.
def _ppx_codeps_out_transition_impl(settings, attr):
    # print("{color}_ppx_codeps_out_transition{reset}: {lbl}".format(
    #     color=CCDER, reset = CCRESET, lbl = attr.name
    # ))

    ## WARNING: returning [] evidently means no change rather than reset?

    ## Case: ppx_compare, where two module targets have same runtime
    ## codep. One is namespaced, so we get two copies and an error:
    ## Files foo and bar both define a module Ppx_compare_lib. If we
    ## return [] here we still get that error. But if we return "" (or
    ## a nonsense string), then both get the same config so the build
    ## only happens once.
    return {
        # "@rules_ocaml//cfg/manifest"      : [],
        "@rules_ocaml//cfg/ns:prefixes"   : [""],
        "@rules_ocaml//cfg/ns:submodules" : [""]
    }

################
_ppx_codeps_out_transition = transition(
    implementation = _ppx_codeps_out_transition_impl,
    inputs = [],
    outputs = [
        # "@rules_ocaml//cfg/manifest",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

###############################
def _ppx_module(ctx):

    # print("{c}ppx_module: {m}{r}".format(
    #     c=CCBLUBG,m=ctx.label,r=CCRESET))

    # if True:  # debug_tc:
    #     tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    #     print("BUILD TGT: {color}{lbl}{reset}".format(
    #         color=CCNRG, reset=CCRESET, lbl=ctx.label))
    #     print("  TC.NAME: %s" % tc.name)
    #     print("  TC.HOST: %s" % tc.host)
    #     print("  TC.TARGET: %s" % tc.target)
    #     print("  TC.COMPILER: %s" % tc.compiler.basename)

    return impl_module(ctx) # , tc.target, tc.compiler, [])

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

**CONFIGURABLE DEFAULTS** for rule `ppx_module`:

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
        ns_resolver = attr.label(
            doc = """
NS resolver module for bottom-up namespacing. Modules may use this attribute to elect membership in a bottom-up namespace.
            """,
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            mandatory = False
        ),

        ## this one is for topdown-up namespacing:
        _ns_resolver = attr.label(
            doc = "NS resolver module for top-down namespacing",
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            ## @rules_ocaml//cfg/ns is a 'label_setting' whose value is an
            ## `ocaml_ns_resolver` rule. so this institutes a
            ## dependency on a resolver whose build params will be set
            ## dynamically using transition functions.
            default = "@rules_ocaml//cfg/ns:resolver",

            ## TRICKY BIT: if our struct is generated (e.g. by
            ## ocaml_lex), this transition will prevent ns renaming:
            # cfg = ocaml_module_deps_out_transition
        ),

        # _manifest = attr.label(
        #     doc = "Hidden attribute set by transition function. Value is string list.",
        #     default = "@rules_ocaml//cfg/manifest"
        # ),

        ppx_codeps = attr.label_list(
            doc = """List of non-opam adjunct dependencies (labels).""",
            mandatory = False,
            # cfg = "target"
            # providers = [[DefaultInfo], [PpxModuleMarker]]
            cfg = _ppx_codeps_out_transition
        ),

        ppx_compile_codeps = attr.label_list(
            doc = """List labels of compile-time dependencies. These are required to compile any file transformed by this ppx.""",
            mandatory = False,
            cfg = _ppx_codeps_out_transition
        ),
        ppx_link_codeps = attr.label_list(
            doc = """List labels of link-time dependencies. These are required to link any file transformed by this ppx.""",
            mandatory = False,
            cfg = _ppx_codeps_out_transition
        ),

        _rule = attr.string( default  = "ppx_module" ),
        _tags = attr.string_list( default  = [
            "ppx",
            "exec" # all ppx_modules are 'exec' modules
        ] ),

        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
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
    #             "@rules_ocaml//toolchain/type:std",
    #             # "@rules_ocaml//cfg/coq:toolchain_type",
    #         ],
    #     ),
    # },
    cfg     = module_in_transition,
    provides = [PpxModuleMarker],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile"
                  # "@bazel_tools//tools/cpp:toolchain_type"
                  ],
)
