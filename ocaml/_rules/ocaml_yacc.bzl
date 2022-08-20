load("@bazel_skylib//lib:paths.bzl", "paths")

########## RULE:  OCAML_INTERFACE  ################
def _ocaml_yacc_impl(ctx):

  debug = False
  if debug:
      print("OCAML YACC TARGET: %s" % ctx.label.name)

  tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

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
ocaml_yacc = rule(
    implementation = _ocaml_yacc_impl,
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
        _rule = attr.string( default = "ocaml_yacc" )
    ),
    # provides = [],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain:type"],
)
