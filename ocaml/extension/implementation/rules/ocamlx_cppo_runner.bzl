load("@bazel_skylib//lib:paths.bzl", "paths")

load("//implementation:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
     )

## example:
# ocamlx_cppo_runner(
#     name = "ExtArray.cppo_mli",
#     srcs = ["extArray.mli"],
#     opts = ["-I", "foo"],
#     defines = [
#         "OCAML 407"
#     ] + WORD_SIZE + HAS_BYTES_FLAG,
#     undefines = ["FOO"],
#     exts = {
#         "lowercase": 'tr "[A-Z]" "[a-z]"'
#     }
# )

# output has same name as input, but is output to a Bazel-controlled
# dir (e.g. bazel-bin/src)

################################################################
def _ocamlx_cppo_runner_impl(ctx):

  debug = False
  # if (ctx.label.name == "snark0.cm_"):
  # if ctx.label.name == "RefList":
  #     debug = True

  if debug:
      print("OCAMLX_CPPO_RUNNER TARGET: %s" % ctx.label.name)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  entailed_deps = None

  dep_graph = ctx.files.srcs
  outputs   = []
  for src in ctx.files.srcs:
      o = ctx.actions.declare_file(src.basename)
      outputs.append(o)

  ################################################################
  args = ctx.actions.args()
  args.add_all(ctx.attr.opts)

  args.add_all(ctx.attr.defines, before_each="-D", uniquify = True)
  args.add_all(ctx.attr.undefines, before_each="-U", uniquify = True)

  if ctx.attr.exts:
      for k in ctx.attr.exts.keys():
          args.add("-x")
          args.add(k + ":" + ctx.attr.exts[k])

  args.add_all(outputs, before_each="-o", uniquify = True)
  # args.add_all(ctx.files.includes, before_each="-I", uniquify = True)

  args.add_all(dep_graph)

  if debug:
      print("\n\t\t================ INPUTS (DEP_GRAPH) ================\n\n")
      for dep in dep_graph:
          print("\nINPUT: %s\n\n" % dep)

  if debug:
      print("\n\t\t================ OUTPUTS ================\n\n")
      for out in outputs:
          print("\nOUTPUT: %s\n\n" % out)

  ctx.actions.run(
      env = env,
      executable = ctx.file._tool,
      arguments = [args],
      inputs = dep_graph,
      outputs = outputs,
      tools = [ctx.file._tool],
      mnemonic = "OcamlxCPPORunner",
      progress_message = "ocamlx_cppo_runner"
  )

  defaultInfo = DefaultInfo(
      # payload
      files = depset(
          order = "postorder",
          direct = outputs
      )
  )

  return [defaultInfo]

#############################################
########## DECL:  OCAML_MODULE  ################
ocamlx_cppo_runner = rule(
    implementation = _ocamlx_cppo_runner_impl,
    attrs = dict(
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        doc = attr.string(
            doc = "Docstring for module"
        ),
        srcs = attr.label_list(
            allow_files = True
        ),
        outs = attr.label_list(
            allow_files = True
        ),
        defines  = attr.string_list(
            doc = "CPPO -D (define) declarations.",
        ),
        undefines  = attr.string_list(
            doc = "CPPO -U (undefine) declarations.",
        ),
        opts = attr.string_list(),
        exts = attr.string_dict(
        ),
        msg = attr.string(),
        _tool = attr.label(
            allow_single_file = True,
            default = "@opam//:bin/cppo"
        )
    ),
    # provides = [OcamlModuleProvider],
    # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
