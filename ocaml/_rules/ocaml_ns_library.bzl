load("//ocaml:providers.bzl",
     "OcamlSignatureProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlNsEnvProvider")

load(":impl_ns_library.bzl", "impl_ns_library")

load(":options.bzl", "options")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

################
ocaml_ns_library = rule(
    implementation = impl_ns_library,
    doc = """Generate a 'namespace' module. [User Guide](../ug/ocaml_ns.md).  Provides: [OcamlNsLibraryProvider](providers_ocaml.md#ocamlnsmoduleprovider).

**NOTE** 'name' must be a legal OCaml module name string.  Leading underscore is illegal.

See [Namespacing](../ug/namespacing.md) for more information on namespaces.

    """,
    attrs = dict(
        options("@ocaml"),
        _linkall     = attr.label(default = "@ocaml//ns_library/linkall"), # FIXME: call it alwayslink?
        # _thread     = attr.label(default = "@ocaml//ns_library/thread"),
        _warnings  = attr.label(default = "@ocaml//ns_library:warnings"),

        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        archive = attr.bool(
            doc = "Output and archive file containing this namespace module and all submodules.",
            default = False
        ),
        opts             = attr.string_list(
            doc          = "List of OCaml options. Will override configurable default options."
        ),
        ns_env = attr.label(
            doc = "Label of an ocaml_ns_env target. Used for renaming struct source file. See [Namepaces](../namespaces.md) for more information.",
            providers = [OcamlNsEnvProvider],
            # default = Label("@ocaml//ns/init")
        ),
        main = attr.label(
            doc = "Code to use as the ns module instead of generated code. The module specified must contain pseudo-recursive alias equations for all submodules.  If this attribute is specified, an ns resolver module will be generated for resolving the alias equations of the provided module.",
            allow_single_file = [".ml"]
        ),
        includes = attr.label_list(
            doc = "List of modules to be 'include'd in the resolver.",
        ),
        # deps = attr.label_list(
        #     doc = "Dependencies",
        #     providers   = [[OcamlModuleProvider], [OcamlNsLibraryProvider], [OcamlSignatureProvider]]
        # ),
        ## experimental transition fns
        # xns = attr.label(
        #     cfg = ocaml_ns_transition,
        #     default = "@ocaml//ns",
        # doc = "Experimental",
        # ),
        submodules = attr.label_keyed_string_dict(
            doc = "Dict from submodule target to name",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = [
                [OcamlModuleProvider],
                [OcamlNsArchiveProvider],
                [OcamlNsLibraryProvider],
                [OcamlSignatureProvider]
            ]
            # cfg = ocaml_ns_transition,
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        ## end experimental transition fns
        # submodules = attr.label_list(
        #   doc = "List of all submodule source files, including .ml/.mli file(s) whose name matches the ns.",
        #   allow_files = True ## OCAML_FILETYPES
        # ),
        _mode = attr.label(
            default = "@ocaml//mode"
        ),
        _projroot = attr.label(
            default = "@ocaml//:projroot"
        ),
        _rule = attr.string(default = "ocaml_ns_library")
    ),
    provides = [DefaultInfo, OcamlNsLibraryProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
