load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_providers:ocaml.bzl",
     "OcamlSDK",
     "OcamlNsModuleProvider")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_actions:ns_module.bzl", "ns_module_compile")
# load("//ocaml/_actions:ppx.bzl",
#      "apply_ppx",
#      "ocaml_ppx_compile",
#      # "ocaml_ppx_apply",
#      "ocaml_ppx_library_gendeps",
#      "ocaml_ppx_library_cmo",
#      "ocaml_ppx_library_compile",
#      "ocaml_ppx_library_link")
load("//implementation:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)
# testing
# load("//implementation/actions:ocamlopt.bzl",
#      "compile_native_with_ppx",
#      "link_native")

# print("implementation/ocaml.bzl loading")


########## RULE:  OCAML_NS  ################
## Generate a namespacing module, containing module aliases for the
## namespaced submodules listed as sources.

def _ocaml_ns_impl(ctx):

  return ns_module_compile(ctx)

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  OCAML_MODULE  ################
ocaml_ns = rule(
  implementation = _ocaml_ns_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    module_name = attr.string(),
    ns = attr.string(),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__'",
      default = "__"
    ),
    submodules = attr.label_list(
      doc = "List of all submodule source files, including .ml/.mli file(s) whose name matches the ns.",
      allow_files = OCAML_FILETYPES
    ),
    opts = attr.string_list(
      # default = [
      #   "-w", "-49", # ignore Warning 49: no cmi file was found in path for module x
      #   "-no-alias-deps", # lazy linking
      #   "-opaque"         #  do not generate cross-module optimization information
      # ]
    ),
    linkopts = attr.string_list(),
    # linkall = attr.bool(default = True),
    alwayslink = attr.bool(
      doc = "If true (default), use OCaml -linkall switch. Default: False",
      default = False,
    ),
    # impl = attr.label(
    #   allow_single_file = OCAML_IMPL_FILETYPES
    # ),
    # deps = attr.label_list(
    #   # providers = [OpamPkgInfo]
    # ),
    mode = attr.string(default = "native"),
    msg = attr.string(),
    _rule = attr.string(default = "ocaml_ns")
  ),
  provides = [DefaultInfo, OcamlNsModuleProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
