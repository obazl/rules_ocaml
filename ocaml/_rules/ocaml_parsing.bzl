load("@bazel_skylib//lib:paths.bzl", "paths")

########## RULE:  OCAML_INTERFACE  ################
def _ocamllex_impl(ctx):

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
      progress_message = "{mode} ocamllex: @{ws}//{pkg}:{tgt}".format(
          mode = tc.target,
          ws  = ctx.label.workspace_name,
          pkg = ctx.label.package,
          tgt=ctx.label.name
      )
  )

  return [DefaultInfo(files = depset(direct = [lexer]))]

#################
ocamllex = rule(
    implementation = _ocamllex_impl,
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
        _rule = attr.string( default = "ocamllex" )
    ),
    # provides = [],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std"],
)

#########################
def _ocamlyacc_impl(ctx):

  debug = False
  if debug:
      print("OCAML YACC TARGET: %s" % ctx.label.name)

  tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]

  yaccer_fname = paths.replace_extension(ctx.file.src.basename, ".ml")
  yacceri_fname = paths.replace_extension(ctx.file.src.basename, ".mli")
  yaccer = ctx.outputs.outs

  ctx.actions.run_shell(
      inputs  = [ctx.file.src],
      outputs = yaccer, # yacceri],
      tools   = [tc.ocamlyacc],
      command = "\n".join([
          ## ocamlyacc is inflexible, it writes to cwd, that's it.
          ## we cannot tell it to write the output to another dir,
          ## so we have to either copy the src to our wd, or
          ## ocamlyacc in place and cp/mv the outputs
          ## 1. copy src to output dir (symlinking doesn't seem to work)
          ## 2. cd to output dir
          ## 3. run ocamlyacc

          "cp -v {src} {dst};".format(src = ctx.file.src.path, dst = yaccer[0].dirname),
          "cd {dst};".format(dst=yaccer[0].dirname), # ctx.file.src.dirname),
          "{tool} {src}".format(
              # dest=ctx.file.src.dirname,
              tool = tc.ocamlyacc.basename,
              src=ctx.file.src.basename,
          ),
      ])
  )

  return [
      DefaultInfo(files = depset(direct = yaccer)),
      # OutputGroupInfo(
      #     ml = depset([yaccer]),
      #     mli= depset([yacceri]),
      #   )
  ]

#################
ocamlyacc = rule(
    implementation = _ocamlyacc_impl,
    doc = """Generates OCaml source files from an ocamlyacc source file.
    """,
    attrs = dict(
        src = attr.label(
            doc = "A single .mly ocamlyacc source file label",
            allow_single_file = [".mly"]
        ),
        outs = attr.output_list(
            doc = """Output filenames.""",
            mandatory = True
        ),
        opts = attr.string_list(
            doc = "Options"
        ),
        _rule = attr.string( default = "ocamlyacc" )
    ),
    # provides = [],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std"],
)
