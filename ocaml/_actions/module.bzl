load("@bazel_skylib//lib:paths.bzl", "paths")
load("//implementation:providers.bzl",
     "OcamlNsModuleProvider",
     # "PpxExecutableProvider",
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
