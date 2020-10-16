load("@bazel_skylib//lib:paths.bzl", "paths")

# load("//ocaml/_actions:library.bzl", "library_action")

# load("//ocaml/_actions:ppx.bzl",
#      "apply_ppx",
#      "ocaml_ppx_compile",
#      "ocaml_ppx_library_gendeps",
#      "ocaml_ppx_library_cmo",
#      "ocaml_ppx_library_link")
# load("//ocaml/_actions:batch.bzl", "copy_srcs_to_tmp")
# load("//ocaml/_actions:ocamlopt.bzl",
#      "compile_native_with_ppx",
#      "link_native")
load("//ocaml/_providers:ocaml.bzl",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlImportProvider",
     "OcamlLibraryProvider",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider",
     "OcamlSDK")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_utils:deps.bzl", "get_all_deps")
load("//implementation:utils.bzl",
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

  mydeps = get_all_deps("ocaml_import", ctx)

  provider = OcamlImportProvider(
      payload = struct(
          archive = ctx.label.name,
          cmx     = ctx.attr.cmx,
          cma     = ctx.attr.cma,
          cmxa    = ctx.attr.cmxa,
          cmxs    = ctx.attr.cmxs
      ),
      indirect = depset(order = "postorder", direct = mydeps.nopam.to_list())
  )

  # transitive graph my have dupes; use depset.to_list() to remove
  dset = []
  if ctx.file.cmx:
      dset.append(ctx.file.cmx)
  if ctx.file.cma:
      dset.append(ctx.file.cma)
  if ctx.file.cmxa:
      dset.append(ctx.file.cmxa)
  if ctx.file.cmxs:
      dset.append(ctx.file.cmxs)
  # if ctx.file.ml:
  #     dset.append(ctx.file.ml)

  default = DefaultInfo(files = depset(dset))

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
    cmx = attr.label(
      allow_single_file = True
    ),
    cma = attr.label(
      allow_single_file = True
    ),
    cmxa = attr.label(
      allow_single_file = True
    ),
    cmxs = attr.label(
      allow_single_file = True
    ),
    ml = attr.label(
      allow_single_file = True
    ),
    deps = attr.label_list(
      # providers = [[OpamPkgInfo],
      #              [OcamlArchiveProvider]],
    ),
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    msg = attr.string(),
    _rule = attr.string(default = "ocaml_import")
  ),
  # provides = [OcamlArchiveProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
