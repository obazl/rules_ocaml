load("//ocaml:providers.bzl",
     "OcamlNsEnvProvider",
     "PpxNsArchiveProvider")

load(":options.bzl", "options")

load(":impl_ns_archive.bzl", "impl_ns_archive")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

##############
ppx_ns_archive = rule(
    implementation = impl_ns_archive,
    doc = """Generate a PPX namespace module.

    """,
    attrs = dict(
        options("@ppx"),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        # module_name = attr.string(),
        # ns = attr.string(),
        # ns_sep = attr.string(
        #     doc = "Namespace separator.  Default: '__'",
        #     default = "__"
        # ),
        ns_env = attr.label(
            doc = "Label of an ocaml_ns_env target. Used for renaming struct source file. See [Namepaces](../namespaces.md) for more information.",
            providers = [OcamlNsEnvProvider],
            # default = Label("@ocaml//ns/init")
        ),
        main = attr.label(
            doc = "Code to use as the ns module.",
            allow_single_file = [".ml"]
        ),
        includes = attr.label_list(
            doc = "List of modules to be 'include'd in the resolver.",
        ),
        deps = attr.label_list(
            doc = "Dependencies"
        ),
        submodules = attr.label_keyed_string_dict(
            doc = "Dict from submodule target to name",
            allow_files = True ## OCAML_FILETYPES
            # cfg = ocaml_ns_transition,
        ),
        # submodules = attr.label_list(
        #     doc = "List of all submodule source files, including .ml/.mli file(s) whose name matches the ns.",
        #     allow_files = True ## OCAML_FILETYPES
        # ),
        _linkall     = attr.label(default = "@ppx//ns/linkall"),
        _thread     = attr.label(default = "@ppx//ns/thread"),
        _warnings    = attr.label(default = "@ppx//ns:warnings"),
        _mode = attr.label(
            default = "@ppx//mode"
        ),
        msg = attr.string(),
        _projroot = attr.label(
            default = "@ocaml//:projroot"
        ),
        _rule = attr.string(default = "ppx_ns_archive")
    ),
    provides = [DefaultInfo, PpxNsArchiveProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
