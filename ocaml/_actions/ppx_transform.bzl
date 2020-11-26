load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
# load("//ocaml/_providers:ocaml.bzl", "CompilationModeSettingProvider")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml/_providers:ocaml.bzl", "OcamlNsModuleProvider", "OcamlVerboseFlagProvider")
load("//ppx:_providers.bzl", "PpxExecutableProvider", "PpxPrintSettingProvider")
load("//implementation:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath"
)
load(":rename.bzl", "get_module_name")

tmpdir = "_obazl_"

################################################################
def ppx_transform(rule, ctx, src):
  """Apply a PPX to source file.

  Inputs: rule, context, src
  Outputs: struct(intf :: declared File, maybe impl :: declared File)
  """

  debug = False
  # if ctx.label.name == "_Prover":
  #     debug = True

  # print("PPX_TRANSFORM: {rule} ({target}): {src}".format(rule=rule, target=ctx.label.name, src=src))

  module_name = get_module_name(ctx, src)
  outfilename = tmpdir + "/" + module_name

  # print("RESOLVED OUTFILE: %s" % outfilename)
  outfile = ctx.actions.declare_file(outfilename)
  outputs = {"impl": outfile}
  # outputs["impl"] = outfile

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  verbose = False
  if ctx.attr._verbose[OcamlVerboseFlagProvider].value:
      if not "-no-verbose" in ctx.attr.opts:
          verbose = True
  elif "-verbose" in ctx.attr.opts:
          verbose = True

  ################################################################
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
  if ctx.attr.ppx: # isn't this always true here?
    if debug:
        print("PPX: %s" % ctx.attr.ppx)
    args.add_all(ctx.attr.ppx[PpxExecutableProvider].args)
    args.add_all(ctx.attr.ppx_args)
    if hasattr(ctx.attr, "ppx_print"):
        if ctx.attr.ppx_print[PpxPrintSettingProvider].value == "binary":
            if "-dump-ast" not in ctx.attr.opts:
                args.add("-dump-ast")
        else:
            if "-dump-ast" in ctx.attr.opts:
                args.add("-dump-ast")

  ## in our shell script, we cd to _obazl_/ before executing this, so we need "../"
  args.add("-o", "../" + outfile.path)
  if src.path.endswith(".mli"):
      args.add("-intf",
               # src.dirname + "/" + module_name)
               src)
  if src.path.endswith(".ml"):
      ## shell script copies src to _obazl_/, cds there, then runs the ppx
      args.add("-impl",
               # src.dirname + "/" + module_name)
               src.path)

  dep_graph = [src] # , ppx]

  # if deps contains inline-tests add "-inline-test-lib {{ctx.attr.ppx_tags}}"
  # if "@opama//pkg:ppx_inline_test" in ctx.files.deps:
  if hasattr(ctx.attr, "ppx_tags"):
      if len(ctx.attr.ppx_tags) > 0:
          args.add("--cookie", "library=" + ctx.attr.ppx_tags[0])
          args.add("-inline-test-lib", ctx.attr.ppx_tags[0]) # FIXME

  parent = src.dirname
  RUNTIME_FILES = ""
  if hasattr(ctx.attr, "ppx_data"):
      if len(ctx.attr.ppx_data) > 0:
          for dep in ctx.attr.ppx_data:
              for f in dep[DefaultInfo].files.to_list():
                  dep_graph.append(f)
                  fname_len = len(f.basename)
                  datafile_parent = f.short_path[:-fname_len]
                  RUNTIME_FILES = RUNTIME_FILES + "\n".join([
                      # "echo FNAME LEN: {}".format(fname_len),
                      # "echo SHORTPATH: {}".format(f.short_path),
                      "if [ ! \( -f {tmpdir}/{parent}/{rtf} \) ]".format(tmpdir=tmpdir,
                                                                parent = datafile_parent,
                                                                rtf = f.basename),
                      "then",
                      "    mkdir -p {v} {tmpdir}/{parent}".format(v = "-v" if verbose else "",
                                                              tmpdir=tmpdir,
                                                              parent=datafile_parent),
                      "    cp {v} {rtf} {tmpdir}/{parent}".format(v = "-v" if verbose else "",
                                                              rtf = f.path,
                                                              tmpdir=tmpdir,
                                                              parent = datafile_parent),
                      "fi"
                  ])

  command = "\n".join([
      "#!/bin/sh",
      "set {set}".format(set = "-x" if verbose else "+x"),
      "mkdir -p {v} {tmpdir}/{path}".format(v = "-v" if verbose else "",
                                            tmpdir=tmpdir,
                                            path = parent),
      RUNTIME_FILES,
      ## copy source to tmp dir for processing. a softlink won't work here.
      "cp {v} {outfile} {tmpdir}/{path}{renamed}".format(v = "-v" if verbose else "",
                                                          outfile = src.path,
                                                          tmpdir = tmpdir,
                                                          path = parent,
                                                          renamed = "/"
                                                          # renamed = "/" + module_name
                                                          ),

      # "cp {v} {src} {renamed_src}".format(v = "-v" if verbose else "",
      #                                     src = src.basename,
      #                                     renamed_src = module_name),
      "pushd _obazl_",

      # "echo BINDIR: {bin}".format(bin = ctx.bin_dir.path),
      # "echo EXE short_path: {exe}".format(exe = ctx.executable.ppx.short_path),
      # "echo EXE path: {exe}".format(exe = ctx.executable.ppx.path),
      # "echo CTX.VAR bindir: {ep}".format(ep = ctx.var["BINDIR"]),
      "{exe} $@".format(exe = "../" + ctx.executable.ppx.path),
      "popd"
  ])

  runner = ctx.actions.declare_file(ctx.attr.name + "_ppx.sh")

  if debug:
      print("RUNNER:")
      print(command)

  ctx.actions.write(
      output  = runner,
      content = command,
      is_executable = True,
  )

  ctx.actions.run(
      env = env,
      executable = runner,  ## ctx.executable.ppx,
      arguments = [args],
      inputs = dep_graph,
      outputs = [outfile], #outputs.values(),
      tools = [ctx.executable.ppx],
      mnemonic = "PpxTransformAction",
      progress_message = "ppx_transform: @{ws}//{pkg}:{tgt}{msg} (rule: {rule})".format(
          ws  = ctx.label.workspace_name,
          pkg = ctx.label.package,
          rule=rule,
          tgt=ctx.label.name,
          msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
      )
  )

  # print("TRANSFORM result: %s" % outfile)
  # return struct(impl = outputs["impl"], intf = outputs["intf"] if "intf" in outputs else None)
  return (tmpdir + "/", outfile) # FIXME: omit trailing "/"
