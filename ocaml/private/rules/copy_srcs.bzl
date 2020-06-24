  # copy all srcs to working dir
  # we need to do this because the OCaml compiler (or ocamlfind) spawns processes outside of Bazel's control.

  # The OCaml compiler generates commands like this:
  # clang -arch x86_64 -Wno-trigraphs -c -o 'bazel-out/darwin-fastbuild/bin/tmp/src/digestif_by.o' '/var/folders/wz/dx0cgvqx5qn802qmc3d4hcfr0000gp/T/camlasm6ccdc6.s'
  # copying to a tmp dir puts the srcs in the bazel work area (bazel-out etc.). if we don't do this,
  # the command will look like:
  # clang -arch x86_64 -Wno-trigraphs -c -o 'src/digestif_by.o' '/var/folders/wz/dx0cgvqx5qn802qmc3d4hcfr0000gp/T/camlasm6ccdc6.s'

  # which doesn't work, we want bazel-out/darwin-fastbuild/bin/src,
  # not just src.  But that output dir is up to the OCaml compiler,
  # which just uses the input dir. so we need to create our own input
  # dir, in the form of a tmp dir.

  # note that this will not work with a depgraph file passed with
  # -args, since we cannot rewrite the paths in the depgraph file
  # before we pass them to the OCaml compiler.  IOW, if we pass the
  # list of input files as labels to the srcs param, this puts them in
  # the Bazel system. If we pass them as lines in a depgraph file,
  # we're going around the Bazel system.  OTOH, we could make depfiles
  # work if we prefix the file paths appropriately. So TODO: write a
  # tool that transforms the depgraph file into a form suitable for
  # Bazel, by prepending ctx.bin_dir.

#### TODO: figure out how to use symlinks

def copy_srcs_to_tmp(ctx):
  print("****************  RUN SHELL COPY ****************\n\n")
  # srcs = ctx.files.srcs
  srcs = []
  cmd = ""
  bindir = ctx.bin_dir.path
  tmpdir = "_obazl/"
  for src in ctx.files.srcs:
    srcs.append(ctx.actions.declare_file(tmpdir + src.path))
    # cmd = cmd + "touch {dest}; ".format(dest = bindir + "/" + tmpdir + src.path)
    cmd = cmd + "mkdir -vp {destdir} && cp -v {src} {dest} && ".format(
      src = src.path,
      destdir = tmpdir + src.dirname,
      dest = bindir + "/" + tmpdir + src.path
    )
  cmd = cmd + " true;"
  print("CMD: %s" % cmd)
  print("CP SRCS")
  print(srcs)

  ctx.actions.run_shell(
    # env = env,
    command = cmd,
    inputs = ctx.files.srcs,
    outputs = srcs, #  + [tmp_depgraph],
    progress_message = "ocaml_library_batch({}): copying {}".format(
      ctx.label.name, src.path
    )
  )
  return srcs
