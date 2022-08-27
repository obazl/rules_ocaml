load("@bazel_skylib//rules:common_settings.bzl", "int_setting", "string_setting", "BuildSettingInfo")

load("//ocaml/_functions:utils.bzl",
     "get_sdkpath"
     )

################################################################
def _x_cppo_filegroup_impl(ctx):

  debug = False
  # if (ctx.label.name == "snark0.cm_"):
  # if ctx.label.name == "RefList":
  #     debug = True

  if debug:
      print("X_CPPO_FILEGROUP TARGET: %s" % ctx.label.name)

  tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
  env = {"PATH": get_sdkpath(ctx)}

  entailed_deps = None

  dep_graph = []
  dep_graph.extend(ctx.files.srcs)
  outputs   = []

  ## FIXME: if ctx.attr.outs empty, use input filenames as output filenames
  ## problem: if multiple inputs, must match input to output filenames?
  ## support output template?
  if len(ctx.files.outs) > 0:
      for src in ctx.files.outs:
          o = ctx.actions.declare_file("_obazl_/" + src.basename)
          outputs.append(o)
  else:
      for src in ctx.files.srcs:
          o = ctx.actions.declare_file("_obazl_/" + src.basename)
          outputs.append(o)

  ################################################################
  args = ctx.actions.args()
  args.add_all(ctx.attr.opts)

  args.add_all(ctx.attr.defines, before_each="-D", uniquify = True)
  args.add_all(ctx.attr.undefines, before_each="-U", uniquify = True)

  for var in ctx.attr.vars.items():
      args.add("-V", var[1] + ":" + var[0][BuildSettingInfo].value)

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
      progress_message = "x_cppo_filegroup"
  )

  defaultInfo = DefaultInfo(
      # payload
      files = depset(
          order = dsorder,
          direct = outputs
      )
  )

  return [defaultInfo]

#############################################
########## DECL:  OCAML_MODULE  ################
x_cppo_filegroup = rule(
    implementation = _x_cppo_filegroup_impl,
    doc = """Process file with cppo.
example:
x_cppo_filegroup(
    name = "ExtArray.cppo_mli",
    srcs = ["extArray.mli"],
    opts = ["-I", "foo"],
    defines = [
        "OCAML 407"
    ] + WORD_SIZE + HAS_BYTES_FLAG,
    undefines = ["FOO"],
    exts = {
        "lowercase": 'tr "[A-Z]" "[a-z]"'
    }
)

output has same name as input, but is output to a Bazel-controlled
dir (e.g. bazel-bin/src)
    """,

    attrs = dict(
        _sdkpath = attr.label(
            default = Label("@rules_ocaml//cfg:sdkpath")
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
        vars = attr.label_keyed_string_dict(
            doc = "Dictionary of cppo VAR (-V) options. Keys: label. Values: string VAR name."
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
    # provides = [OcamlModuleMarker],
    # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std"],
)
