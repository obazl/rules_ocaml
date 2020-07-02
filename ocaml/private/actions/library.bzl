load("@bazel_skylib//lib:paths.bzl", "paths")

load("@obazl//ocaml/private:actions/batch.bzl", "copy_srcs_to_tmp")
load("@obazl//ocaml/private:providers.bzl",
     "OcamlLibraryProvider",
     "PpxLibraryProvider",
     "OpamPkgInfo")

load("@obazl//ocaml/private:utils.bzl",
     "get_all_deps",
     "get_opamroot",
     "get_sdkpath",
)


def library_action(ctx):
  """Build an OCaml or PPX library.  A library is a collection of modules without an archive file."""

  mydeps = get_all_deps(ctx.attr.deps)
  # print("MYDEPS for {lib}: {deps}".format(lib=ctx.label.name, deps=mydeps))

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  ## no input srcs means we're being used just to force dep builds, so
  ## we just pass input deps as our outputs
  dset = []
  for dep in mydeps.nopam.to_list(): #] # ctx.attr.deps]
    print("DEP: %s" % dep)
    if hasattr(dep, "cm"):
        print("CM DEP: %s" % dep)
        dset.append(dep.cm)
  # flatten
  # dset = [val for sublist in dset for val in sublist]
  if not ctx.files.srcs:
    ctx.actions.do_nothing(mnemonic = "pass-through", inputs = dset)

    provider = None
    if ctx.attr._rule == "ocaml_library":
        provider = OcamlLibraryProvider(
            payload = struct(
                name = ctx.label.name,
                modules = ctx.attr.deps
            ),
            deps = struct(
                opam = mydeps.opam,
                nopam = mydeps.nopam
            )
        )
    else:
        provider = PpxLibraryProvider(
            payload = struct(
                name = ctx.label.name,
                modules = ctx.attr.deps
            ),
            deps = struct(
                opam = mydeps.opam,
                nopam = mydeps.nopam
            )
        )
    print("LIBPROVIDER: %s" % provider)
    return [
        DefaultInfo(files = depset(direct = dset)),
        provider
    ]

  ################################################################
  # print("CTX SRCS")
  # print([src.path for src in ctx.files.srcs])

  # copy all srcs to working dir
  # we need to do this because the OCaml compiler (or ocamlfind) spawns processes outside of Bazel's control.
  srcs = copy_srcs_to_tmp(ctx)
  # return [DefaultInfo(files=depset(direct=srcs)),OcamlLibraryProvider()]

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  args = ctx.actions.args()
  args.add(tc.compiler.basename)
  args.add("-w", ctx.attr.warnings)
  options = tc.opts + ctx.attr.opts
  args.add_all(ctx.attr.opts)

  # if "-a" in ctx.attr.opts:
  #   args.add("-o", obj_cmxa)
  # else:
  #   args.add("-o", obj_cmx)

  build_deps = []
  includes = []

  ## transitive opam deps
  args.add_all([dep.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  ## direct deps
  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
    else:
      for g in dep[DefaultInfo].files.to_list():
        # print(g)
        if g.path.endswith(".cmi"):
          build_deps.append(g)
        if g.path.endswith(".cmx"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          build_deps.append(g)
          includes.append(g.dirname)
        # if g.path.endswith(".o"):
        #   build_deps.append(g)
        # if g.path.endswith(".cmxa"):
        #   build_deps.append(g)
        #   args.add(g) # dep[DefaultInfo].files)
        # else:
        #   args.add(g) # dep[DefaultInfo].files)

  ## Use case: srcs include paths. i.e. they're in subdirs of the pkg dir,
  ## In that case we want to include their dirs, that's where to output goes
  ## so we need to include them in case following files want to link
  ## input files could involve any number of subdirs, we need to add them all.
  ## Alternatively, we could -o all output files to one dir, but that would risk name clashes?
  # abs = "/Users/gar/coda/digestif/"

  bindir = ctx.bin_dir.path

  for src in srcs: # ctx.files.srcs:
    includes.append(src.dirname)

  # args.add("-I", bindir)

  args.add_all(includes, before_each="-I", uniquify = True)

  args.add_all(build_deps)
  # print("DEPS")
  # print(build_deps)

  if ctx.attr.depgraph:
    # args.add("-args", tmp_depgraph) # ctx.file.depgraph.path)
    args.add("-args", ctx.file.depgraph.path)
  else:
    args.add_all([src.path for src in srcs])

  in_files = [] # [ctx.file.depgraph]
  # includes = []
  out_files = []
  # print("CTX.BIN_DIR (root): %s" % ctx.bin_dir.path)
  # print("CTX.BUILD_FILE_PATH: %s" % ctx.build_file_path)
  cwd = paths.dirname(ctx.build_file_path)
  # print("CWD: %s" % cwd)

  ## declare outfiles for srcs
  for src in srcs: #  ctx.files.srcs:
    if src.path.endswith("ml"):
      # print("LIB SRC: %s" % src.path)
      in_files.append(src)
      ## declare outputs
      path_pfx = ctx.bin_dir.path + "/" + cwd
      relpath = paths.relativize(src.path, path_pfx)
      # print("LIB RELPATH: %s" % relpath)
      # outfname = src.short_path.rstrip("ml") + tc.objext
      # outfname = paths.replace_extension(src.short_path, tc.objext)
      cmx_outfname = paths.replace_extension(relpath, tc.objext)
      # print("LIB CMX_OUTFNAME: %s" % cmx_outfname)
      obj_cmx = ctx.actions.declare_file(cmx_outfname)
      # print("LIB OBJ_CMX: %s" % obj_cmx.path)
      o_outfname = paths.replace_extension(relpath, ".o")
      # obj_o = ctx.actions.declare_file(src.short_path.rstrip("ml") + "o")
      obj_o = ctx.actions.declare_file(o_outfname)
      # obj_cmx = ctx.actions.declare_file(
      #   src.basename.rstrip("ml") + "cmx",
      #   sibling = src
      # )
      # obj_o = ctx.actions.declare_file(
      #   src.basename.rstrip("ml") + "o",
      #   sibling = src
      # )
      out_files.append(obj_cmx)
      out_files.append(obj_o)
  # args.add_all(includes, before_each="-I", uniquify = True)
  # print("INS:")
  # print(in_files)
  # print("OUTS:")
  # print(out_files)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = in_files,
    outputs = out_files,
    tools = [tc.ocamlfind, tc.compiler],
    mnemonic = "OcamlLibrary",
    progress_message = "ocaml_library({}): {}".format(
      ctx.label.name, ctx.attr.msg
    )
  )

  return [
    DefaultInfo(files = depset(direct = out_files)),
    OcamlLibraryProvider(
      library = struct(
        name = ctx.label.name,
        modules = out_files,
      ),
      deps = struct(
        opam = mydeps.opam,
        nopam = mydeps.nopam
      )
    )
  ]
