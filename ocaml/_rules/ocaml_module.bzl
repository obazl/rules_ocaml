load("//ocaml:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlSignatureProvider",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("//ocaml/_transitions:transitions.bzl",
     "module_in_transition")

load(":options.bzl",
     "options",
     "options_module",
     "options_ns_opts",
     "options_ppx")

load(":impl_module.bzl", "impl_module")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

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
        # gen = attr.label_keyed_string_dict(
        #     doc = "Experimental. Key is executable target, value is command-line arg string."
        # ),
        ################
        ## obsolete:
        # cc_linkall = attr.label_list(
        #     ## FIXME: make this sticky; replace with "static-linkall" value for cc_deps dict entry
        #     doc     = "True: use `-whole-archive` (GCC toolchain) or `-force_load` (Clang toolchain). Deps in this attribute must also be listed in cc_deps.",
        #     # providers = [CcInfo],
        # ),
        # cc_linkopts = attr.string_list(
        #     doc = "List of C/C++ link options. E.g. `[\"-lstd++\"]`.",

        # ),
        # cc_linkstatic = attr.bool(
        #     ## FIXME: replaced by "static" value for cc_deps dict
        #     doc     = "DEPRECATED. Control linkage of C/C++ dependencies. True: link to .a file; False: link to shared object file (.so or .dylib)",
        #     default = True # False  ## false on macos, true on linux?
        # ),

        ## TODO:
        # _cc_linkdynamic = attr.label(
        #     ## FIXME: find a better way
        #     doc = "Global dynamically linked cc-deps, apply to all instances of rule. Added last.",
        #     default = "@ocaml//module:cc_linkdynamic"
        # ),
        # _cc_linkstatic = attr.label(
        #     ## FIXME: find a better way
        #     doc = "Global statically linked cc-deps, apply to all instances of rule. Added last.",
        #     default = "@ocaml//module:cc_linkstatic"
        # ),
        # here = attr.label(
        #     allow_single_file = True,
        #     default = ":BUILD.bazel"
        # )
    ),
    cfg     = module_in_transition,  # incoming
    provides = [OcamlModuleProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
