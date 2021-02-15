load("//ocaml:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlSignatureProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlNsEnvProvider",
     "OpamPkgInfo",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load(":options.bzl", "options", "options_ppx")

load(":impl_module.bzl", "impl_module")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

################################
rule_options = options("@ocaml")
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
        ## RULE DEFAULTS
        _opts     = attr.label(default = "@ocaml//module:opts"),     # string list
        _linkall  = attr.label(default = "@ocaml//module/linkall"),  # bool
        _thread   = attr.label(default = "@ocaml//module/thread"),   # bool
        _warnings = attr.label(default = "@ocaml//module:warnings"), # string list
        #### end options ####
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        doc = attr.string(
            doc = "Docstring for module. DEPRECATED"
        ),
        # module_name   = attr.string(
        #     doc = "Module name. Overrides `name` attribute."
        # ),
        ns_env = attr.label(
            doc = "Label of an ocaml_ns_env target. Used for renaming struct source file. See [Namepaces](../namespaces.md) for more information.",
            providers = [OcamlNsEnvProvider],
            default = None
        ),
        # ns = attr.label(
        #     doc = "Experimental",
        #     # default = Label("@ocaml//ns/init")
        # ),
        # _xns = attr.label(
        #     doc = "Experimental",
        #     default = "@ocaml//ns"
        # ),
        # xns = attr.label(
        #     doc = "Experimental",
        #     cfg = ocaml_ns_transition_reset,
        #     default = "@ocaml//ns"
        # ),
        struct = attr.label(
            mandatory = True,
            doc = "A single .ml source file label.",
            allow_single_file = OCAML_IMPL_FILETYPES
        ),
        module = attr.string(
            doc = "Name for output file. Use to coerce input file with different name, e.g. for a file generated from a .ml file to a different name, like foo.cppo.ml."
        ),
        sig = attr.label(
            doc = "Single label of a target providing a single .cmi or .mli file. Optional. Currently only supports .cmi input.",
            # allow_single_file = [".cmi", ".mli"],
            # providers = [[DefaultInfo], [OcamlSignatureProvider]],
        ),
        ################################
        data = attr.label_list(
            allow_files = True,
            doc = "Runtime dependencies: list of labels of data files needed by this module at runtime."
        ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OpamPkgInfo],
                         [OcamlArchiveProvider],
                         [OcamlImportProvider],
                         [OcamlSignatureProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsArchiveProvider],
                         [OcamlNsLibraryProvider],
                         # [OcamlNsEnvProvider],
                         [PpxArchiveProvider],
                         [PpxModuleProvider]]
                         # [CcInfo]],
        ),
        _deps = attr.label(
            doc = "Global deps, apply to all instances of rule. Added last.",
            default = "@ocaml//module:deps"
        ),
        # deps_adjunct = attr.label_list(
        #     doc = "List of [adjunct dependencies](../ug/ppx.md#adjunct_deps).",
        #     # providers = [[DefaultInfo], [PpxModuleProvider]]
        #     allow_files = True,
        # ),
        deps_opam = attr.string_list(
            doc = "List of OPAM package names"
        ),
        cc_deps = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            # providers = [[CcInfo]]
        ),
        _cc_deps = attr.label(
            doc = "Global cc-deps, apply to all instances of rule. Added last.",
            default = "@ocaml//module:deps"
        ),
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

        ## CONFIGURATION RULE DEFAULTS ##
        _mode       = attr.label(
            default = "@ocaml//mode",
            # cfg     = ocaml_mode_transition
        ),
        # _ppx_mode       = attr.label(
        #     default = "@ppx//mode",
        #     # Attaching to an attribute transitions the configuration of this dependency (and
        #     # all its dependencies)
        #     cfg = ocaml_mode_transition_incoming
        # ),
        # _allowlist_function_transition = attr.label(
        #     ## required for transition fn of attribute _mode
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),

        msg = attr.string(),
        _rule = attr.string( default = "ocaml_module" )
    ),
    provides = [OcamlModuleProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
