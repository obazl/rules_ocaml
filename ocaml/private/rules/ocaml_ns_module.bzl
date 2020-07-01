load("@bazel_skylib//lib:paths.bzl", "paths")

load("@obazl//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "OcamlModuleProvider")
load("@obazl//ocaml/private:actions/ns_module.bzl", "ns_module_action")
load("@obazl//ocaml/private:actions/ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")
load("@obazl//ocaml/private:utils.bzl",
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
load("@obazl//ocaml/private:actions/ocamlopt.bzl",
     "compile_native_with_ppx",
     "link_native")

# print("private/ocaml.bzl loading")


########## RULE:  OCAML_NS_MODULE  ################
## Generate a namespacing module, containing module aliases for the
## namespaced submodules listed as sources.

def _ocaml_ns_module_impl(ctx):

  return ns_module_action(ctx)

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  OCAML_MODULE  ################
ocaml_ns_module = rule(
  implementation = _ocaml_ns_module_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    module_name = attr.string(),
    ns = attr.string(),
    submodules = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    opts = attr.string_list(
      default = [
        "-w", "-49", # ignore Warning 49: no cmi file was found in path for module x
        "-no-alias-deps", # lazy linking
        "-opaque"         #  do not generate cross-module optimization information
      ]
    ),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    # impl = attr.label(
    #   allow_single_file = OCAML_IMPL_FILETYPES
    # ),
    # deps = attr.label_list(
    #   # providers = [OpamPkgInfo]
    # ),
    mode = attr.string(default = "native"),
    msg = attr.string(),
    _rule = attr.string(default = "ocaml_ns_module")
  ),
  provides = [DefaultInfo, OcamlModuleProvider],
  executable = False,
  toolchains = ["@obazl//ocaml:toolchain"],
)
