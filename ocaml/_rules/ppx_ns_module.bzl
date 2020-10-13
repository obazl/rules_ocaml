load("@bazel_skylib//lib:paths.bzl", "paths")

load("//implementation:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "OcamlInterfaceProvider",
     "PpxBinaryProvider",
     "PpxNsModuleProvider",
     "PpxModuleProvider")
load("//ocaml/_actions:batch.bzl", "copy_srcs_to_tmp")
load("//ocaml/_actions:ns_module.bzl", "ns_module_action")
# load("//ocaml/_actions:module.bzl", "rename_module")
load("//ocaml/_actions:ppx_transform.bzl", "ppx_transform_action")
load("//implementation:utils.bzl",
     "capitalize_initial_char",
     "xget_all_deps",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "get_target_file",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

################################################################
##########  PPX_NS_MODULE  ################
ppx_ns_module = rule(
  implementation = ns_module_action,
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
    alwayslink = attr.bool(
      doc = "If true (default), use OCaml -linkall switch",
      default = True,
    ),
    # linkall = attr.bool(default = True),
    mode = attr.string(default = "native"),
    msg = attr.string(),
    _rule = attr.string(default = "ppx_ns_module")
  ),
  provides = [DefaultInfo, PpxNsModuleProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)

