load("//ocaml:providers.bzl", "OcamlImportProvider")

##################################################
######## RULE DECL:  OCAML_IMPORT  #########
##################################################
def _ocaml_import_impl(ctx):

  """Import an OCaml archive."""

  debug = False

  # make all deps direct for client of this rule

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
  attrs = dict(
  ),
  provides = [OcamlImportProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
