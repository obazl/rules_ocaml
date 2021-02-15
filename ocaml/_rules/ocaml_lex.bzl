load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",)
     # "OcamlArchiveProvider",
     # "OcamlDepsetProvider",
     # "OcamlSignatureProvider",
     # "OcamlLibraryProvider",
     # "OcamlModuleProvider",
     # "OcamlNsLibraryProvider")
     # "OpamPkgInfo",
     # "PpxArchiveProvider",
     # "PpxExecutableProvider",
     # "PpxNsLibraryProvider")

load("//ocaml/_rules/utils:rename.bzl", "rename_module")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "file_to_lib_name",
     "get_opamroot",
     "get_sdkpath",
)

OCAML_INTF_FILETYPES = [
    ".mli", ".cmi"
]

########## RULE:  OCAML_INTERFACE  ################
def _ocaml_lex_impl(ctx):

  debug = False
  # if (ctx.label.name == "_Impl"):
  #     debug = True

  if debug:
      print("OCAML LEX TARGET: %s" % ctx.label.name)

  mode = ctx.attr._mode[CompilationModeSettingProvider].value

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  lexer_fname = paths.replace_extension(ctx.file.src.basename, ".ml")

  tmpdir = "_obazl_/"

  lexer = ctx.actions.declare_file(lexer_fname)

  if debug:
      print("lexer: %s" % lexer)

  ################################################################
  args = ctx.actions.args()

  if mode == "native":
      args.add("-ml")

  args.add_all(ctx.attr.opts)

  args.add("-o", lexer)

  args.add(ctx.file.src)

  ctx.actions.run(
      env = env,
      executable = tc.ocamllex,
      arguments = [args],
      inputs = [ctx.file.src],
      outputs = [lexer],
      tools = [tc.ocamllex],
      mnemonic = "OcamlLex",
      progress_message = "{mode} ocaml_lex: @{ws}//{pkg}:{tgt}".format(
          mode = mode,
          ws  = ctx.label.workspace_name,
          pkg = ctx.label.package,
          tgt=ctx.label.name
      )
  )

  return [DefaultInfo(files = depset(direct = [lexer]))]

#################
ocaml_lex = rule(
    implementation = _ocaml_lex_impl,
    doc = """Generates an OCaml source file from an ocamllex source file.
    """,
    attrs = dict(
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        src = attr.label(
            doc = "A single .mll source file label",
            allow_single_file = [".mll"]
        ),
        opts = attr.string_list(
            doc = "Options"
        ),
        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        _rule = attr.string( default = "ocaml_lex" )
    ),
    # provides = [],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
