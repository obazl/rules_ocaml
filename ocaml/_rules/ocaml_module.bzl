load("//ocaml/_providers:ocaml.bzl",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider")

load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load(":options_ocaml.bzl", "options_ocaml")

load(":impl_module.bzl", "impl_module")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

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
| @ocaml//module:threads | True | `-thread`, `-no-thread`|
| @ocaml//module:verbose | True | `-verbose`, `-no-verbose`|

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        options_ocaml,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//module:linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//module:threads"),
        _warnings  = attr.label(default = "@ocaml//module:warnings"),
        #### end options ####
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        doc = attr.string(
            doc = "Docstring for module. DEPRECATED"
        ),
        module_name   = attr.string(
            doc = "Module name. Overrides `name` attribute."
        ),
        ns = attr.label(
            doc = "Label of an ocaml_ns target. Used to derive namespace, output name, -open arg, etc. See [Namepaces](../namespaces.md) for more information.",
            default = None
        ),
        ns_init = attr.label(
            doc = "Experimental",
            # default = Label("@ocaml//ns/init")
        ),
        # _xns = attr.label(
        #     doc = "Experimental",
        #     default = "@ocaml//ns"
        # ),
        # xns = attr.label(
        #     doc = "Experimental",
        #     cfg = ocaml_ns_transition_reset,
        #     default = "@ocaml//ns"
        # ),
        src = attr.label(
            mandatory = True,
            doc = "A single .ml source file label.",
            allow_single_file = OCAML_IMPL_FILETYPES
        ),
        intf = attr.label(
            doc = "Single label of a target providing a single .cmi or .mli file. Optional. Currently only supports .cmi input.",
            allow_single_file = [".cmi", ".mli"],
            # providers = [[DefaultInfo], [OcamlInterfaceProvider]],
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
                         [OcamlInterfaceProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsModuleProvider],
                         [PpxArchiveProvider],
                         [PpxModuleProvider],
                         [CcInfo]],
        ),
        _deps = attr.label(
            doc = "Global deps, apply to all instances of rule. Added last.",
            default = "@ocaml//module:deps"
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
        cc_linkall = attr.label_list(
            ## FIXME: make this sticky; replace with "static-linkall" value for cc_deps dict entry
            doc     = "True: use `-whole-archive` (GCC toolchain) or `-force_load` (Clang toolchain). Deps in this attribute must also be listed in cc_deps.",
            # providers = [CcInfo],
        ),
        cc_linkopts = attr.string_list(
            doc = "List of C/C++ link options. E.g. `[\"-lstd++\"]`.",

        ),
        cc_linkstatic = attr.bool(
            ## FIXME: replaced by "static" value for cc_deps dict
            doc     = "DEPRECATED. Control linkage of C/C++ dependencies. True: link to .a file; False: link to shared object file (.so or .dylib)",
            default = True # False  ## false on macos, true on linux?
        ),
        ## TODO:
        _cc_linkstatic = attr.label(
            ## FIXME: find a better way
            doc = "Global statically linked cc-deps, apply to all instances of rule. Added last.",
            default = "@ocaml//module:cc_linkstatic"
        ),

        ppx  = attr.label(
            doc = "PPX binary (executable).  The rule will use this executable to transform the source file before compiling it. For more information on the actions generated by `ocaml_module` when used with a PPX transform see [Action Queries](../ug/transparency.md#action_queries).",
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            providers = [PpxExecutableProvider]
        ),
        ppx_args  = attr.string_list(
            doc = "Options to pass to PPX binary passed by the `ppx` attribute.",
        ),
        ppx_tags  = attr.string_list(
            doc = "DEPRECATED. List of tags.  Used to set e.g. -inline-test-libs, --cookies. Currently only one tag allowed."
        ),
        ppx_data  = attr.label_list(
            doc = "PPX runtime dependencies. List of labels of files needed by the PPX executable passed via the `ppx` attribute when it is executed to transform the source file. For example, a source file using [ppx_optcomp](https://github.com/janestreet/ppx_optcomp) may import a file using extension `[%%import ]`; this file should be listed in this attribute.",
            allow_files = True,
        ),
        ppx_print = attr.label(
            doc = "Format of output of PPX transform. Value must be one of '@ppx//print:binary', '@ppx//print:text'.  See [PPX Support](../ug/ppx.md#ppx_print) for more information",
            default = "@ppx//print:binary"
        ),
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
