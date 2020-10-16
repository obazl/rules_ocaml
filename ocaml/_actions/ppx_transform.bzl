load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml/_providers:ocaml.bzl", "OcamlNsModuleProvider")
load("//ocaml/_providers:ppx.bzl", "PpxExecutableProvider")
load("//implementation:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath"
)

TMPDIR = "_obazl/"

################################################################
def ppx_transform_action(rule, ctx, infile):
  """Apply a PPX to source file.

  Inputs: rule, context, infile
  Outputs: struct(intf :: declared File, maybe impl :: declared File)
  """

  debug = False
  # if (ctx.label.name == "snark0.cm_"):
  # if ctx.label.name == "Filter":
  #     debug = True

  # print("PPX_TRANSFORM_ACTION: {rule} ({target}): {infile}".format(rule=rule, target=ctx.label.name, infile=infile))

  pfx = None
  if (rule == "ocaml_module"):
    if ctx.attr.ns_module:
      pfx = ctx.attr.ns_module[OcamlNsModuleProvider].payload.ns
  # elif (rule == "ppx_module"):
  #   if ctx.attr.ppx_ns_module:
  #     pfx = ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.ns
  elif (rule == "ppx_module"):
    if ctx.attr.ns_module:
      pfx = ctx.attr.ns_module[OcamlNsModuleProvider].payload.ns
  elif (rule == "ocaml_interface"):
    if ctx.attr.ns_module:
      pfx = ctx.attr.ns_module[OcamlNsModuleProvider].payload.ns
  else:
    fail("ppx_transform_action called by rule other than ocaml_module or ocaml_interface or ppx_module: %s" % rule)

  # print("XFORM NS: %s" % pfx)

  # print("INFILE: %s" % infile.basename)
  outfilename = None
  parts = paths.split_extension(capitalize_initial_char(infile.basename)) # .capitalize())
  if ctx.attr.module_name:
    module = ctx.attr.module_name
  else:
    module = parts[0]

  # print("INFILE MODULE %s" % module)

  if pfx == None: ## no ns_module
    # pfx = TMPDIR
    outfilename = TMPDIR + module
  else:
    if pfx.find("/") > 0:
      fail("ERROR: ns contains '/' : '%s'" % pfx)
    else:
      if pfx.lower() == module.lower():
        outfilename = module
      else:
        outfilename = capitalize_initial_char(pfx) + ctx.attr.ns_sep + module

  # print("PFX: %s" % pfx)


  # if pfx.lower() == module.lower():
  #   print("NS INFILE MATCH!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
  #   outfilename = module
  # else:
  #   outfilename = pfx + module

  outfilename = outfilename + parts[1]  ## add extension from infile

  # print("RESOLVED OUTFILE: %s" % outfilename)
  outfile = ctx.actions.declare_file(outfilename)
  outputs = {"impl": outfile}
  # outputs["impl"] = outfile

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  args = ctx.actions.args()

  # ppx = None

  # if hasattr(ctx.attr, "ppx"):
  #     if ctx.attr.ppx:
  #         for key in ctx.attr.ppx.keys():
  #             # print("KEY LABEL: %s" % key.label[PpxExecutableProvider])
  #             if PpxExecutableProvider in key:
  #                 ppx = key
  #                 # # print("PPX EXE[0] : %s" % ppx[0])
  #                 #       print("PPX EXE: %s" % key[PpxExecutableProvider])
  #                 #       print("PPX VAL: %s" % ctx.attr.ppx[key])
  # elif ctx.attr.ppx:
  #     ppx = ctx.attr.ppx

  # print("PPX: %s" % ppx)
  if ctx.attr.ppx:
    if debug:
        print("PPX: %s" % ctx.attr.ppx)
    args.add_all(ctx.attr.ppx[PpxExecutableProvider].args)
    args.add_all(ctx.attr.ppx_args)
    if hasattr(ctx.attr, "ppx_output_format"):
      if ctx.attr.ppx_output_format == "binary":
        #FIXME: also check ppx_args for -dump-ast
        args.add("-dump-ast")

  args.add("-o", outfile)
  if infile.path.endswith(".mli"):
    args.add("-intf", infile)
  if infile.path.endswith(".ml"):
    args.add("-impl", infile)

  ppx = ctx.file.ppx
  # ppx = ctx.attr.ppx.files.to_list()[0]
  # print("PPX: %s" % ppx)
  # if ctx.attr.ppx:
  #   for item in ctx.attr.ppx.items():
  #     pkg = item[0].label.name
  #     print("PKG: {}".format(pkg))
  #     args.add("-package", pkg)
  #     if item[1]:
  #       ppxargs = ",".join(item[1].split(" "))
  #       print("PPXARGS: {}".format(ppxargs))
  #       args.add("-ppxopt", pkg + "," + ppxargs)

  dep_graph = [infile] # , ppx]
  if hasattr(ctx.attr, "ppx_runtime_deps"):
      if ctx.attr.ppx_runtime_deps:
          for dep in ctx.files.ppx_runtime_deps:
              # includes.append(dep.dirname)
              dep_graph.append(dep)

  ctx.actions.run(
    env = env,
    executable = ppx, # item[0],
    arguments = [args],
    inputs = dep_graph,
    outputs = [outfile], #outputs.values(),
    tools = [ppx], # [item[0]],
    mnemonic = "PpxTransformAction",
    progress_message = "Action: ppx_transform_action of {rule}({tgt}){msg}".format(
        rule=rule,
        tgt=ctx.label.name,
        msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
    )
  )

  # print("TRANSFORM result: %s" % outfile)
  # return struct(impl = outputs["impl"], intf = outputs["intf"] if "intf" in outputs else None)
  return outfile
