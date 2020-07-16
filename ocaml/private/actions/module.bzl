load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml/private:providers.bzl",
     "OcamlNsModuleProvider",
     "PpxBinaryProvider",
     "PpxNsModuleProvider")
load("//ocaml/private:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath"
)

TMPDIR = "_obazl/"

################################################################
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
  print("RENAMING MODULE %s" % module)
  ns = ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.ns + ctx.attr.ns_sep
  print("NS: %s" % ns)
  if (module == ns):
    out_filename = module + extension
  else:
    out_filename = ns + capitalize_initial_char(module) + extension
  print("RENAMED MODULE %s" % out_filename)

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
  module = ""
  if (rule == "ocaml_module"):
    if ctx.attr.ns_module:
      pfx = ctx.attr.ns_module[OcamlNsModuleProvider].payload.ns + ctx.attr.ns_sep
  elif (rule == "ppx_module"):
    if ctx.attr.ppx_ns_module:
      pfx = ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.ns + ctx.attr.ns_sep
  elif (rule == "ocaml_interface"):
    if ctx.attr.ns_module:
      pfx = ctx.attr.ns_module[OcamlNsModuleProvider].payload.ns + ctx.attr.ns_sep
  else:
    fail("ppx_transform_action called by rule other than ocaml_module or ppx_module: %s" % rule)

  if pfx == None:
    pfx = TMPDIR
  else:
    if pfx.find("/") > 0:
      fail("ERROR: ns contains '/' : '%s'" % pfx)

  # print("PFX: %s" % pfx)
  # print("INFILE: %s" % infile.basename)
  outfilename = None
  parts = paths.split_extension(infile.basename.capitalize())
  if ctx.attr.module_name:
    module = ctx.attr.module_name
  else:
    module = parts[0]
    # print("INFILE MODULE %s" % module)

  if (pfx.lower().startswith(module.lower())):
    # print("NS INFILE MATCH!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    outfilename = module
  else:
    outfilename = pfx + module
  outfilename = outfilename + parts[1]

  # print("RESOLVED OUTFILE: %s" % outfilename)
  outfile = ctx.actions.declare_file(outfilename)
  outputs = {}
  outputs["impl"] = outfile

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  args = ctx.actions.args()

  if ctx.attr.ppx_bin:
    args.add_all(ctx.attr.ppx_bin[PpxBinaryProvider].args)
    args.add_all(ctx.attr.ppx_bin_opts)

  args.add("-o", outfile)
  if infile.path.endswith(".mli"):
    args.add("-intf", infile)
  if infile.path.endswith(".ml"):
    args.add("-impl", infile)

  # args.add("-corrected-suffix", ".ppx-corrected")
  # args.add("-dump-ast")


  ppx = ctx.attr.ppx_bin.files.to_list()[0]
  # print("PPX: %s" % ppx)
  # if ctx.attr.ppx:
  #   for item in ctx.attr.ppx_bin.items():
  #     pkg = item[0].label.name
  #     print("PKG: {}".format(pkg))
  #     args.add("-package", pkg)
  #     if item[1]:
  #       ppxargs = ",".join(item[1].split(" "))
  #       print("PPXARGS: {}".format(ppxargs))
  #       args.add("-ppxopt", pkg + "," + ppxargs)

  ctx.actions.run(
    env = env,
    executable = ppx, # item[0],
    arguments = [args],
    inputs = [infile] + [ppx],
    outputs = [outfile], #outputs.values(),
    tools = [ppx], # [item[0]],
    mnemonic = "OcamlPpxModule",
    progress_message = "ppx_transform_action of {rule}({target}){msg}".format(
      rule=rule, target=ctx.label.name, msg = "" if not ctx.attr.msg else ", msg: " + ctx.attr.msg
    )
  )
  # print("TRANSFORM result: %s" % outfile)
  # return struct(impl = outputs["impl"], intf = outputs["intf"] if "intf" in outputs else None)
  return outfile
