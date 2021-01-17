load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml/_providers:ocaml.bzl", "OcamlNsModuleProvider")

# load("//ocaml/_actions:ns_module.bzl", "ns_module_compile")

load(":impl_ns.bzl", "impl_ns")

# load("//ocaml/_transitions:ns_transitions.bzl", "ocaml_ns_transition")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

########## RULE:  OCAML_NS  ################
## Generate a namespacing module, containing module aliases for the
## namespaced submodules listed as sources.

# def _ocaml_ns_impl(ctx):

#     # print("TEST ocaml_ns _NS: %s" % ctx.attr.xns[0][BuildSettingInfo].value)

#     return ns_module_compile(ctx)

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  OCAML_MODULE  ################
ocaml_ns = rule(
  implementation = impl_ns,
  # implementation = _ocaml_ns_impl,
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
    # xns = attr.label(
    #     cfg = ocaml_ns_transition,
    #     default = "@ocaml//ns",
        # doc = "Experimental",
    # ),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__' (double underscore)",
      default = "__"
    ),
    # _allowlist_function_transition = attr.label(
    #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
    # ),
    submods = attr.label_list(
      doc = "List of all submodule source files, including .ml/.mli file(s) whose name matches the ns.",
      allow_files = True ## OCAML_FILETYPES
        # cfg = ocaml_ns_transition,
    ),
    submodules = attr.label_list(
      doc = "List of all submodule source files, including .ml/.mli file(s) whose name matches the ns.",
      allow_files = True ## OCAML_FILETYPES
    ),
    ## we don't really need any options for an ns module
    # opts = attr.string_list(
    #     doc = "DEPRECATED"
    # ),
      # default = [
      #   "-w", "-49", # ignore Warning 49: no cmi file was found in path for module x
      #   "-no-alias-deps", # lazy linking
      #   "-opaque"         #  do not generate cross-module optimization information
      # ]
    # ),
    # linkopts = attr.string_list(),
    # linkall = attr.bool(default = True),
    # alwayslink = attr.bool(
    #   doc = "If true (default), use OCaml -linkall switch. Default: False",
    #   default = False,
    # ),
    # impl = attr.label(
    #   allow_single_file = OCAML_IMPL_FILETYPES
    # ),
    # deps = attr.label_list(
    #   # providers = [OpamPkgInfo]
    # ),
    ## linkall?
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
