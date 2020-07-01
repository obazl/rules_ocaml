load("@bazel_skylib//lib:paths.bzl", "paths")
load("@obazl//ocaml/private:utils.bzl",
     "get_opamroot",
     "get_sdkpath"
)

TMPDIR = "_obazl/"

################################################################
def rename_module(ctx, srcs, pfx):
  """Rename implementation and interface (if given) using prefix.

  Inputs: context, srcs: struct(intf: File, maybe impl: File), pfx: string
  Outputs: struct(intf: declared File, impl: declared File)
  """

  if not pfx.endswith("__"):
    print("WARNING: prefix '{pfx}' does not appear to be an OCaml module path segment prefix; did you mean '{pfx}__'?".format(pfx = pfx))

  if pfx.find("/") > 0:
    fail("ERROR: ns contains '/' : '%s'" % pfx)

  inputs  = []
  # outputs = []
  outputs = {}
  if srcs.intf:
    intf = srcs.intf.files.to_list()[0]
    inputs.append(intf)
    new_intf = ctx.actions.declare_file(pfx + intf.basename.capitalize())
    # outputs.append(new_intf)
    outputs["intf"] = new_intf
    print("NEW INTF: %s" % new_intf)
  inputs.append(srcs.impl)
  new_impl = ctx.actions.declare_file(pfx + srcs.impl.basename.capitalize())
  outputs["impl"] = new_impl
  print("NEW IMPL: %s" % new_impl)

  destdir = paths.normalize(new_impl.dirname)
  print("DESTDIR: %s" % destdir)

  cmd = ""
  dest = new_impl.path
  # print("DEST: %s" % dest)
  # cmd = cmd + "touch {dest}; ".format(dest = bindir + "/" + tmpdir + src.path)
  cmd = cmd + "mkdir -vp {destdir} && cp -v {src} {dest} && ".format(
    src = srcs.impl.path,
    destdir = destdir,
    dest = dest
  )

  if srcs.intf:
    dest = new_intf.path
    cmd = cmd + "mkdir -vp {destdir} && cp -v {src} {dest} && ".format(
      src = srcs.impl.path,
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
    outputs = outputs.values(),
    progress_message = "ocaml_library_batch({}): renaming module {}".format(
      ctx.label.name, srcs
    )
  )
  print("RENAME result: %s" % outputs.values())
  return struct(impl = outputs["impl"], intf = outputs["intf"] if "intf" in outputs else None)

################################################################
def to_libarg(lib):
  return "'library-name=\"{}\"'".format(lib)

def transform_module(rule, ctx, srcs):
  """Apply a PPX to module sources.

  Inputs: context, srcs:: struct(intf :: File, maybe impl :: File)
  Outputs: struct(intf :: declared File, maybe impl :: declared File)
  """

  inputs = [srcs.impl]

  pfx = ""
  module = ""
  if ctx.attr.ns:
    module = srcs.impl.basename.capitalize()
    pfx = ctx.attr.ns
    if not pfx.endswith("__"):
      print("WARNING: ns '{pfx}' does not appear to be an OCaml module path segment prefix; did you mean '{pfx}__'?".format(pfx = pfx))
    if pfx.find("/") > 0:
      fail("ERROR: ns contains '/' : '%s'" % pfx)
  else:
    pfx = TMPDIR
    module = srcs.impl.basename

  new_impl = ctx.actions.declare_file(pfx + module)
  outputs = {}
  outputs["impl"] = new_impl
  # print("NEW IMPL: %s" % new_impl)

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  args = ctx.actions.args()
  # args.add_all(ctx.attr.args)

  # IF ppx_inline_test
  # args.add("--cookie")
  # args.add("library=\"ppx_optcomp_test\"")
  # args.add("ppx_optcomp_test", format="'library=\"%s\"'")
  # args.add("-inline-test-lib", "ppx_optcomp_test")

  args.add("-o", new_impl)
  args.add("-impl", srcs.impl)
  # args.add("-corrected-suffix", ".ppx-corrected")
  args.add("-dump-ast")

  ppx = ctx.attr.ppx.files.to_list()[0]

  ctx.actions.run(
    env = env,
    executable = ppx,
    arguments = [args],
    inputs = inputs,
    outputs = outputs.values(),
    tools = [ppx],
    mnemonic = "OcamlPpxModule",
    progress_message = "transform_module of {rule}({target}){msg}".format(
      rule=rule, target=ctx.label.name, msg = "" if not ctx.attr.msg else ", msg: " + ctx.attr.msg
    )
  )
  # print("TRANSFORM result: %s" % outputs.values())
  return struct(impl = outputs["impl"], intf = outputs["intf"] if "intf" in outputs else None)

