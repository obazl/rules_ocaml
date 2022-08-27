load("@bazel_skylib//lib:paths.bzl", "paths")

# load("//ocaml/_functions:utils.bzl",
#      "get_sdkpath",
# )

load(":impl_common.bzl", "tmpdir")

########## RULE:  OCAML_INTERFACE  ################
def _ocaml_lex_impl(ctx):

  debug = False
  # if (ctx.label.name == "_Impl"):
  #     debug = True

  if debug:
      print("OCAML LEX TARGET: %s" % ctx.label.name)

  tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
  # env = {"PATH": get_sdkpath(ctx)}

  # lexer_fname = paths.replace_extension(ctx.file.src.basename, ".ml")

  # lexer = ctx.actions.declare_file(lexer_fname)
  lexer = ctx.outputs.out

  #########################
  args = ctx.actions.args()

  if tc.target == "native":
      args.add("-ml")

  args.add_all(ctx.attr.opts)

  args.add("-o", lexer)

  args.add(ctx.file.src)

  ctx.actions.run(
      # env = env,
      executable = tc.ocamllex,
      arguments = [args],
      inputs = [ctx.file.src],
      outputs = [lexer],
      tools = [tc.ocamllex],
      mnemonic = "OcamlLex",
      progress_message = "{mode} ocaml_lex: @{ws}//{pkg}:{tgt}".format(
          mode = tc.target,
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
        # _sdkpath = attr.label(
        #     default = Label("@rules_ocaml//cfg:sdkpath")
        # ),
        src = attr.label(
            doc = "A single .mll source file label",
            allow_single_file = [".mll"]
        ),
        out = attr.output(
            doc = """Output filename.""",
            mandatory = True
        ),
        opts = attr.string_list(
            doc = "Options"
        ),
        # _mode       = attr.label(
        #     default = "@rules_ocaml//build/mode",
        # ),
        _rule = attr.string( default = "ocaml_lex" )
    ),
    # provides = [],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std"],
)
