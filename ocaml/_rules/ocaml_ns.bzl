load("//ocaml/_providers:ocaml.bzl", "OcamlNsModuleProvider")

load(":impl_ns.bzl", "impl_ns")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

################
ocaml_ns = rule(
  implementation = impl_ns,
    doc = """Generate a 'namespace' module. [User Guide](../ug/ocaml_ns.md).  Provides: [OcamlNsModuleProvider](providers_ocaml.md#ocamlnsmoduleprovider).

See [Namespacing](../ug/namespacing.md) for more information on namespaces.

    """,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    # module_name = attr.string(
    #     doc = "Name of output file. Overrides default, which is derived from _name_ attribute."
    # ),
    ns = attr.string(
        doc = "A namespace name string. The name of namespace is taken from this attribute, not the `name` attribute.  This makes it easier to avoid naming conflicts when a package contains a large number of modules, archives, etc."
    ),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__' (double underscore)",
      default = "__"
    ),
      ## experimental transition fns
    # xns = attr.label(
    #     cfg = ocaml_ns_transition,
    #     default = "@ocaml//ns",
        # doc = "Experimental",
    # ),
    submods = attr.label_list(
      doc = "List of all submodule source files, including .ml/.mli file(s) whose name matches the ns.",
      allow_files = True ## OCAML_FILETYPES
        # cfg = ocaml_ns_transition,
    ),
    # _allowlist_function_transition = attr.label(
    #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
    # ),
      ## end experimental transition fns
    submodules = attr.label_list(
      doc = "List of all submodule source files, including .ml/.mli file(s) whose name matches the ns.",
      allow_files = True ## OCAML_FILETYPES
    ),
    _mode = attr.label(
        default = "@ocaml//mode"
    ),
    _warnings  = attr.label(default = "@ocaml//ns:warnings"),
    _rule = attr.string(default = "ocaml_ns")
  ),
  provides = [DefaultInfo, OcamlNsModuleProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
