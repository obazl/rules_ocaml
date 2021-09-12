load("//ocaml:providers.bzl", "OcamlImportProvider")

##################################################
######## RULE DECL:  OCAML_IMPORT  #########
##################################################
def _ocaml_import_impl(ctx):

  """Import an OCaml archive."""

  debug = False

  # print("ocaml_import: %s" % ctx.label)

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

  dep_depsets = []
  adjunct_depsets = []
  if ctx.attr.deps:
      for dep in ctx.attr.deps:
          dep_depsets.append(dep[DefaultInfo].files)
          adjunct_depsets.append(dep[OcamlImportProvider].deps_adjunct)

  sig_depsets = []
  if ctx.attr.signature:
      for sig in ctx.attr.signature:
          sig_depsets.append(ctx.files.signature)

  if ctx.attr.archive:
      # print("{tgt} archives: {archives}".format(
      #     tgt=ctx.label,
      #     archives=ctx.attr.archive))
      # for f in ctx.files.archive:
      #     print("f: %s" % f.path)
      default = DefaultInfo(
          files = depset(
              direct = ctx.files.archive,
              transitive = dep_depsets
          )
      )
  else:
      default = DefaultInfo() # files = depset(dset))

  # print("IMPORT %s" % ctx.label.name)
  # print(" ctx.files.deps_adjunct: %s" % ctx.files.deps_adjunct)
  # print(" adjunct_depsets: %s" % adjunct_depsets)

  importProvider = OcamlImportProvider(
      deps_adjunct = depset(
          direct = ctx.files.deps_adjunct,
          transitive = adjunct_depsets
      ),
      signatures = depset(
          transitive = sig_depsets
      ),
      # paths = depset( ... )
  )

  return [
      default,
      importProvider
  ]

################################################################
################################################################
ocaml_import = rule(
  implementation = _ocaml_import_impl,
    doc = """Imports a pre-compiled OCaml binary. [User Guide](../ug/ocaml_import.md).

**NOT YET SUPPORTED**
    """,
  attrs = dict(
      srcs = attr.label_list(
          allow_files = True
      ),
      deps = attr.label_list(
          allow_files = True
      ),
      deps_adjunct = attr.label_list(
          allow_files = True
      ),
      modules = attr.label_list(
          allow_files = True
      ),
      signature = attr.label_list(
          allow_files = True
      ),
      archive = attr.label_list(
          allow_files = True
      ),
      plugin = attr.label_list(
          allow_files = True
      ),
      version = attr.string(),
      doc = attr.string(),
      _rule = attr.string( default = "ocaml_import" ),
  ),
  provides = [OcamlImportProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
