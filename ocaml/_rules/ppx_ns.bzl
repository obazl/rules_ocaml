load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_providers:ocaml.bzl", "OcamlSDK")
load("//ppx:_providers.bzl", "PpxNsModuleProvider")
load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_actions:ns_module.bzl", "ns_module_compile")
# load("//ocaml/_actions:ppx.bzl",
#      "apply_ppx",
#      "ocaml_ppx_compile",
#      # "ocaml_ppx_apply",
#      "ocaml_ppx_library_gendeps",
#      "ocaml_ppx_library_cmo",
#      "ocaml_ppx_library_compile",
#      "ocaml_ppx_library_link")
load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "WARNING_FLAGS"
)
load(":options_ppx.bzl", "options_ppx")

######################
def _ppx_ns_impl(ctx):
  return ns_module_compile(ctx)

##############
ppx_ns = rule(
    implementation = _ppx_ns_impl,
    attrs = dict(
        options_ppx,
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
        # opts = attr.string_list(),
        _linkall     = attr.label(default = "@ppx//ns:linkall"),
        _threads     = attr.label(default = "@ppx//ns:threads"),
        _warnings    = attr.label(default = "@ppx//ns:warnings"),
        _mode = attr.label(
            default = "@ppx//mode"
        ),
        msg = attr.string(),
        _rule = attr.string(default = "ppx_ns")
    ),
    provides = [DefaultInfo, PpxNsModuleProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
