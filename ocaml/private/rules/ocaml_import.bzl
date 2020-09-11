load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/private/actions:library.bzl", "library_action")

load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_link")
load("//ocaml/private/actions:batch.bzl", "copy_srcs_to_tmp")
load("//ocaml/private/actions:ocamlopt.bzl",
     "compile_native_with_ppx",
     "link_native")
load("//ocaml/private:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("//ocaml/private:deps.bzl", "get_all_deps")
load("//ocaml/private:utils.bzl",
     # "get_all_deps",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "split_srcs",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

##################################################
######## RULE DECL:  OCAML_IMPORT  #########
##################################################
################################################################
################################################################
def _ocaml_import_impl(ctx):

  """Import an OCaml archive."""

  # make all deps direct for client of this rule

  transitives = []
  for dep in ctx.attr.deps:
    # print("TRANSITIVES: %s" % dep)
    transitives.extend(dep.files.to_list())

  provider = OcamlArchiveProvider(
    payload = struct(
      archive = ctx.label.name,
      cmxa    = ctx.attr.cmxa
    ),
    deps = struct(
      opam = depset(),
      nopam = depset(direct = transitives)
    )
  )


  # transitive graph my have dupes; use depset.to_list() to remove
  dset = depset(direct = [ctx.file.cmxa] + transitives)
  default = DefaultInfo(files = depset(dset.to_list()))

  # print("IMPORT %s" % ctx.label.name)
  # print("IMPORT DefaultInfo: %s" % default)

  return [
    default,
    provider
  ]

################################################################
################################################################
ocaml_import = rule(
  implementation = _ocaml_import_impl,
  attrs = dict(
    cmxa = attr.label(
      allow_single_file = True
    ),
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlArchiveProvider]],
    ),
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    msg = attr.string(),
    _rule = attr.string(default = "ocaml_import")
  ),
  provides = [OcamlArchiveProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
