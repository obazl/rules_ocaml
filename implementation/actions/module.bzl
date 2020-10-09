load("@bazel_skylib//lib:paths.bzl", "paths")
load("//implementation:providers.bzl",
     "OcamlNsModuleProvider",
     "PpxBinaryProvider",
     "PpxNsModuleProvider")
load("//implementation:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath"
)

TMPDIR = "_obazl/"

################################################################
def rename_ocaml_module(ctx, src):  # , pfx):
  """Rename implementation and interface (if given) using prefix.

  Inputs: context, src
  Outputs: outfile :: declared File
  """

  # if module name == ns, then output module name
  # otherwise, outputp ns + "__" + module name

  parts = paths.split_extension(src.basename)
  module = parts[0]
  extension = parts[1]
  # print("RENAMING MODULE %s" % module)
  ns = ctx.attr.ns_module[OcamlNsModuleProvider].payload.ns + ctx.attr.ns_sep
  # print("NS: %s" % ns)
  if (module == ns):
    out_filename = module + extension
  else:
    out_filename = ns + capitalize_initial_char(module) + extension
  # print("RENAMED MODULE %s" % out_filename)

  # if pfx.find("/") > 0:
  #   fail("ERROR: ns contains '/' : '%s'" % pfx)

  inputs  = []
  # outputs = []
  outputs = {}
  inputs.append(src)
  outfile = ctx.actions.declare_file(out_filename)

  destdir = paths.normalize(outfile.dirname)
  # print("DESTDIR: %s" % destdir)

  cmd = ""
  dest = outfile.path
  # print("DEST: %s" % dest)
  # cmd = cmd + "touch {dest}; ".format(dest = bindir + "/" + tmpdir + src.path)
  cmd = cmd + "mkdir -vp {destdir} && cp -v {src} {dest} && ".format(
    src = src.path,
    destdir = destdir,
    dest = dest
  )

  cmd = cmd + " true;"
  # print("CMD: %s" % cmd)
  # print("CP SRCS")

  ctx.actions.run_shell(
    # env = env,
    command = cmd,
    inputs = inputs,
    outputs = [outfile],
    progress_message = "rename_src_action ({}){}".format(
      ctx.label.name, src
    )
  )
  return outfile

################################################################
##FIXME rename:  rename_ppx_module
def rename_module(ctx, src):  # , pfx):
  """Rename implementation and interface (if given) using prefix.

  Inputs: context, src
  Outputs: outfile :: declared File
  """

  # if module name == ns, then output module name
  # otherwise, outputp ns + "__" + module name

  parts = paths.split_extension(src.basename)
  module = parts[0]
  extension = parts[1]
  # print("RENAMING MODULE %s" % module)
  ns = ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.ns + ctx.attr.ns_sep
  # print("NS: %s" % ns)
  if (module == ns):
    out_filename = module + extension
  else:
    out_filename = ns + capitalize_initial_char(module) + extension
  # print("RENAMED MODULE %s" % out_filename)

  # if pfx.find("/") > 0:
  #   fail("ERROR: ns contains '/' : '%s'" % pfx)

  inputs  = []
  # outputs = []
  outputs = {}
  inputs.append(src)
  outfile = ctx.actions.declare_file(out_filename)

  destdir = paths.normalize(outfile.dirname)
  # print("DESTDIR: %s" % destdir)

  cmd = ""
  dest = outfile.path
  # print("DEST: %s" % dest)
  # cmd = cmd + "touch {dest}; ".format(dest = bindir + "/" + tmpdir + src.path)
  cmd = cmd + "mkdir -vp {destdir} && cp -v {src} {dest} && ".format(
    src = src.path,
    destdir = destdir,
    dest = dest
  )

  cmd = cmd + " true;"
  # print("CMD: %s" % cmd)
  # print("CP SRCS")

  ctx.actions.run_shell(
    # env = env,
    command = cmd,
    inputs = inputs,
    outputs = [outfile],
    progress_message = "rename_src_action ({}){}".format(
      ctx.label.name, src
    )
  )
  return outfile

################################################################
def to_libarg(lib):
  return "'library-name=\"{}\"'".format(lib)

################################################################
def ppx_transform_action(rule, ctx, infile):
  """Apply a PPX to source file.

  Inputs: rule, context, infile
  Outputs: struct(intf :: declared File, maybe impl :: declared File)
  """

  # print("PPX_TRANSFORM_ACTION: {rule} ({target}): {infile}".format(rule=rule, target=ctx.label.name, infile=infile))

  pfx = None
  if (rule == "ocaml_module"):
    if ctx.attr.ns_module:
      pfx = ctx.attr.ns_module[OcamlNsModuleProvider].payload.ns
  # elif (rule == "ppx_module"):
  #   if ctx.attr.ppx_ns_module:
  #     pfx = ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.ns
  elif (rule == "ocaml_interface"):
    if ctx.attr.ns_module:
      pfx = ctx.attr.ns_module[OcamlNsModuleProvider].payload.ns
  else:
    fail("ppx_transform_action called by rule other than ocaml_module or ppx_module: %s" % rule)

  # print("XFORM NS: %s" % pfx)

  # print("INFILE: %s" % infile.basename)
  outfilename = None
  parts = paths.split_extension(infile.basename.capitalize())
  if ctx.attr.module_name:
    module = ctx.attr.module_name
  else:
    module = parts[0]

  # print("INFILE MODULE %s" % module)

  if pfx == None:
    # pfx = TMPDIR
    outfilename = TMPDIR + module
  else:
    if pfx.find("/") > 0:
      fail("ERROR: ns contains '/' : '%s'" % pfx)
    else:
      if pfx.lower() == module.lower():
        outfilename = module
      else:
        outfilename = pfx.capitalize() + ctx.attr.ns_sep + module

  # print("PFX: %s" % pfx)


  # if pfx.lower() == module.lower():
  #   print("NS INFILE MATCH!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
  #   outfilename = module
  # else:
  #   outfilename = pfx + module
  outfilename = outfilename + parts[1]

  # print("RESOLVED OUTFILE: %s" % outfilename)
  outfile = ctx.actions.declare_file(outfilename)
  outputs = {}
  outputs["impl"] = outfile

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  args = ctx.actions.args()

  # ppx = None

  # if hasattr(ctx.attr, "ppx"):
  #     if ctx.attr.ppx:
  #         for key in ctx.attr.ppx.keys():
  #             # print("KEY LABEL: %s" % key.label[PpxBinaryProvider])
  #             if PpxBinaryProvider in key:
  #                 ppx = key
  #                 # # print("PPX EXE[0] : %s" % ppx[0])
  #                 #       print("PPX EXE: %s" % key[PpxBinaryProvider])
  #                 #       print("PPX VAL: %s" % ctx.attr.ppx[key])
  # elif ctx.attr.ppx:
  #     ppx = ctx.attr.ppx

  # print("PPX: %s" % ppx)
  if ctx.attr.ppx:
    args.add_all(ctx.attr.ppx[PpxBinaryProvider].args)
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

  ppx = ctx.attr.ppx.files.to_list()[0]
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
  if ctx.attr.ppx_deps:
      for dep in ctx.files.ppx_deps:
          # includes.append(dep.dirname)
          dep_graph.append(dep)

  ctx.actions.run(
    env = env,
    executable = ppx, # item[0],
    arguments = [args],
    inputs = dep_graph,
    outputs = [outfile], #outputs.values(),
    tools = [ppx], # [item[0]],
    mnemonic = "OcamlPpxModule",
    progress_message = "ppx_transform_action of {rule}{msg}".format(
        rule=rule,
        # target=ctx.label.name,
        msg = "" if not ctx.attr.msg else ", msg: " + ctx.attr.msg
    )
  )

  # print("TRANSFORM result: %s" % outfile)
  # return struct(impl = outputs["impl"], intf = outputs["intf"] if "intf" in outputs else None)
  return outfile
