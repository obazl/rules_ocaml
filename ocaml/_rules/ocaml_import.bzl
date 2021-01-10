load("//ocaml/_providers:ocaml.bzl", "OcamlImportProvider")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

##################################################
######## RULE DECL:  OCAML_IMPORT  #########
##################################################
def _ocaml_import_impl(ctx):

  """Import an OCaml archive."""

  debug = False

  # make all deps direct for client of this rule
  # mydeps = get_all_deps("ocaml_import", ctx)

  # provider = OcamlImportProvider(
  #     payload = struct(
  #         archive = ctx.label.name,
  #         cmx     = ctx.attr.cmx,
  #         cma     = ctx.attr.cma,
  #         cmxa    = ctx.attr.cmxa,
  #         cmxs    = ctx.attr.cmxs
  #     ),
  #     indirect = depset(order = "postorder", direct = mydeps.nopam.to_list())
  # )

  # # transitive graph my have dupes; use depset.to_list() to remove
  # dset = []
  # if ctx.file.cmx:
  #     dset.append(ctx.file.cmx)
  # if ctx.file.cma:
  #     dset.append(ctx.file.cma)
  # if ctx.file.cmxa:
  #     dset.append(ctx.file.cmxa)
  # if ctx.file.cmxs:
  #     dset.append(ctx.file.cmxs)
  # # if ctx.file.ml:
  # #     dset.append(ctx.file.ml)

  # default = DefaultInfo(files = depset(dset))

  # # print("IMPORT %s" % ctx.label.name)
  # # print("IMPORT DefaultInfo: %s" % default)

  # return [
  #     default,
  #     provider
  # ]

################################################################
################################################################
ocaml_import = rule(
  implementation = _ocaml_import_impl,
    doc = """Imports a pre-compiled OCaml binary. [User Guide](../ug/ocaml_import.md).

**NOT YET SUPPORTED**
    """,
  # attrs = dict(
  #   cmx = attr.label(
  #     allow_single_file = True
  #   ),
  #   cma = attr.label(
  #     allow_single_file = True
  #   ),
  #   cmxa = attr.label(
  #     allow_single_file = True
  #   ),
  #   cmxs = attr.label(
  #     allow_single_file = True
  #   ),
  #   ml = attr.label(
  #     allow_single_file = True
  #   ),
  #   deps = attr.label_list(
  #     # providers = [[OpamPkgInfo],
  #     #              [OcamlArchiveProvider]],
  #   ),
  #   _sdkpath = attr.label(
  #     default = Label("@ocaml//:path")
  #   ),
  #   msg = attr.string(),
  #   _rule = attr.string(default = "ocaml_import")
  # ),
  # provides = [OcamlArchiveProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
