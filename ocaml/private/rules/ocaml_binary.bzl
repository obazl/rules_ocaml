load("//opam:opam.bzl",
     "OPAMROOT")
load("//ocaml/private:common.bzl",
     "OCAML_VERSION")
load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     "compile_new_srcs")
load("//ocaml/private/actions:ocaml.bzl",
     "ocaml_compile")
load("//ocaml/private/actions:batch.bzl", "copy_srcs_to_tmp")
load("//ocaml/private:providers.bzl",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("//ocaml/private:utils.bzl",
     "get_all_deps",
     "get_opamroot",
     "get_sdkpath",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

# def _ocaml_interface_impl(ctx):
#   ctx.actions.run_shell(
#       inputs = [ctx.file.src, ctx.executable._ocamlc],
#       outputs = [ctx.label.name + "mli"], # [ctx.outputs.mli],
#       progress_message = "Compiling interface file %s" % ctx.label,
#       mnemonic="OCamlc",
#       command = "%s -i -c %s > %s" % (ctx.executable._ocamlc.path, ctx.file.src.path, ctx.outputs.mli.path),
#   )

#   return struct(mli = ctx.outputs.mli.path)

# ocaml_interface = rule(
#     implementation = _ocaml_interface_impl,
#     attrs = dict(
#       _ocaml_tools_attrs,
#       src = attr.label(
#         allow_files = OCAML_FILETYPES,
#         # allow_single_file = True,
#         )
#     ),
#     # outputs = { "mli": "%{name}.mli" },
# )

################################################################
def _compile_without_ppx(ctx):

  # print("ALL DEPS for %s" % ctx.label.name)
  # print(ctx.files.deps)
  mydeps = get_all_deps(ctx.attr.deps)
  # print("ALL DEPS for %s" % ctx.label.name)
  # print(mydeps)

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  srcs = copy_srcs_to_tmp(ctx)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  if ctx.attr.exe_name:
    outfilename = ctx.attr.exe_name
    outbinary = ctx.actions.declare_file(outfilename)
  else:
    outfilename = ctx.label.name
    outbinary = ctx.actions.declare_file(outfilename)
  # we will wait to add the -o flag until after we compile the interface files

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  args_intf = ctx.actions.args()
  args_impl = ctx.actions.args()
  args_intf.add("ocamlc")
  args_intf.add("-c")
  args_impl.add("ocamlopt")
  args_intf.add_all(ctx.attr.opts)
  args_impl.add_all(ctx.attr.opts)

  ## we don't want to do this, it reorders the deps
  # opamdeps = []
  # xdeps = []
  # for dep in ctx.attr.deps:
  #   if OpamPkgInfo in dep:
  #     opamdeps.append(dep[OpamPkgInfo].pkg)
  #   else:
  #     ##FIXME: filter for PpxInfo deps
  #     xdeps.append(dep[PpxInfo].ppx)
  # # non-ocamlfind-enabled deps:
  # args_intf.add_joined(xdeps, join_with=" ")
  # # for ocamlfind-enabled deps, use -package
  # args_intf.add_joined("-package", opamdeps, join_with=",")

  ## deps are the same for all sources (.mli, .ml)
  ## we need to accumulate them so we can add them to the action inputs arg,
  ## in order to  register the dependency with Bazel.
  build_deps = []
  includes = []
  args_impl.add("-linkpkg")  ## an ocamlfind parameter
  # print("OPAM_DEPS: %s" % mydeps.opam)
  for dep in mydeps.opam.to_list():
    # print("OPAM DEP: %s" % dep)
    for depdep in dep.to_list():
      # print("OPAM DEPDEP: %s" % depdep)
      args_impl.add("-package", depdep.name)
  # args_impl.add_all([dep.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  # print("NOPAM_DEPS for {bin}: {deps}".format(bin=ctx.label.name, deps=mydeps.nopam))
  for dep in mydeps.nopam.to_list():  # ctx.attr.deps:
    # print("NOPAM_DEP: %s" % dep)
    if hasattr(dep, "clib"):
      build_deps = build_deps + dep.clib.files.to_list()
      args_impl.add("-cclib", "-lrakia")
    if hasattr(dep, "cmx"):    ## composited lib
      build_deps.append(dep.cmx)
      includes.append(dep.cmx.dirname)
      args_impl.add(dep.cmx)
    # elif hasattr(dep, "modules"):  ## batched lib
    #   nopam_modules = dep.modules
    #   for module in nopam_modules:
    #     build_deps.append(module)
    #     includes.append(module.dirname)
    #     args_impl.add(module)

    # if OpamPkgInfo in dep:
    #   if not linkpkg:
    #     ##FIXME: reorder - put this first
    #     linkpkg = True
    #     args_impl.add("-linkpkg")  ## an ocamlfind parameter
    #   # opam_dep = dep[OpamPkgInfo].pkg.to_list()[0].name
    #   # args_intf.add("-package", opam_dep)
    #   # args_impl.add("-package", opam_dep)
    #   # build_deps.append(dep[OpamPkgInfo].pkg)
    # else:
    #   for g in dep[DefaultInfo].files.to_list():
    #     args_intf.add(g)
    #     args_impl.add(g)
    #     includes.append(g.dirname)
    #     build_deps.append(g)
    #     # if g.path.endswith(".cmx"):
    #     #   args_intf.add(g)
    #     #   args_impl.add(g)
    #     #   includes.append(g.dirname)
    #     #   build_deps.append(g)
    #     # if g.path.endswith(".cmxa"):
    #     #   args_intf.add(g)
    #     #   args_impl.add(g)
    #     #   includes.append(g.dirname)
    #     #   build_deps.append(g)

      # if PpxInfo in dep:
      #   print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
      #   build_deps.append(dep[PpxInfo].cmxa)
      #   build_deps.append(dep[PpxInfo].a)
      # else:
      #   print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
      #   for g in dep[DefaultInfo].files.to_list():
      #     print(g)
      #     if g.path.endswith(".cmx"):
      #       build_deps.append(g)
      #       args_intf.add("-I", g.dirname)

  args_intf.add_all(includes, before_each="-I", uniquify = True)
  args_impl.add_all(includes, before_each="-I", uniquify = True)

  ## srcs: deal with .mli and .ml separately
  srcs_mli = []
  outs_cmi = []
  srcs_ml  = []
  outs_cmx = []

  for src in srcs: ## ctx.files.srcs:
    if src.path.endswith(".mli"):
      srcs_mli.append(src)
      # register cmi outfile with Bazel
      outfname = src.basename.rstrip(".mli") + ".cmi"
      outf = ctx.actions.declare_file(outfname)
      outs_cmi.append(outf)
    else:
      if src.path.endswith(".ml"):
        srcs_ml.append(src)
        args_impl.add("-I", src.dirname)
        # register cmx outfile with Bazel
        # outfname = src.basename.rstrip(".ml") + ".cmx"
        # outf = ctx.actions.declare_file(outfname)
        # outs_cmx.append(outf)
      else:
        fail("Not an OCaml source file: %s" % src.path)

  ## without this, the compiler may not be able to find the cmi files:
  includes_mli = []
  for src in srcs_mli:
    includes_mli.append(src.dirname)
  args_impl.add_all(includes_mli, before_each="-I", uniquify = True)

  # args_impl.add_all(outs_cmi)

  args_intf.add_all(srcs_mli)
  args_impl.add_all(srcs_ml)

  # first compile interface files
  if srcs_mli:
    ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args_intf],
      inputs = srcs_mli,
      outputs = outs_cmi,
      progress_message = "ocaml_compile({}): compiling interfaces {}".format(
        ctx.label.name, ctx.attr.message,
      )
    )

  args_impl.add("-o", outbinary)

  if ctx.attr.strip_data_prefixes:
    myrunfiles = ctx.runfiles(
      files = ctx.files.data,
      symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
    )
  else:
    myrunfiles = ctx.runfiles(
      files = ctx.files.data,
    )

  # print("BUILD DEPS: %s" % build_deps)

  # then compile implementation files and produce executable
  # if srcs_ml:
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args_impl],
    inputs = srcs_ml + outs_cmi + build_deps,
    outputs = [outbinary],
    # tools = build_deps,
      progress_message = "ocaml_binary({}): compiling implementations {}".format(
        ctx.label.name, ctx.attr.message
      )
  )

  return [DefaultInfo(executable = outbinary,
                      runfiles = myrunfiles)]

################################################################
def _compile_with_ppx(ctx):
  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  # 1. preprocess sources
  new_intfs, new_impls = apply_ppx(ctx, env)

  # 2. compile to get *.cmi, *.cmx from preprocessed sources
  new_intfs, new_impls = compile_new_srcs(ctx, env, tc, new_intfs, new_impls)

  # 3. link and produce executable

  outbinary = ctx.actions.declare_file(ctx.label.name)

  args = ctx.actions.args()
  args.add("ocamlopt")
  #TODO: if --verbose
  # args.add("-verbose")
  args.add("-ccopt", "-v")
  args.add("-w", WARNING_FLAGS)
  args.add_all(["-strict-sequence", "-strict-formats", "-short-paths",
                "-keep-locs", "-g"])
  args.add("-o", outbinary)
  # args.add_all(new_intfs)
  for f in new_impls:
    if f.extension == "cmx":
      args.add(f) # add_all(new_impls)

  ocaml_compile(ctx,
                env = env,
                pgm = tc.ocamlfind,
                args = [args],
                inputs = new_intfs + new_impls,
                outputs = [outbinary],
                tools = [], # ppx_dep] # , tc.opam, tc.ocamlfind, tc.ocamlopt]
                progress_message = "with ppx"
  )

  return [DefaultInfo(executable = outbinary)]

################
def _ocaml_binary_impl(ctx):

  # if ctx.attr.preprocessor:
  # # if hasattr(ctx.attr, ("preprocessor"):
  #   ##FIXME: how to pass parameters to ppx?
  #   return _compile_with_ppx(ctx)
  # else:
  return _compile_without_ppx(ctx)

################################################################
ocaml_binary = rule(
  implementation = _ocaml_binary_impl,
  attrs = dict(
    exe_name = attr.string(),
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    srcs = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    # srcs_impl = attr.label_list(
    #   allow_files = OCAML_IMPL_FILETYPES
    # ),
    # srcs_intf = attr.label_list(
    #   allow_files = OCAML_INTF_FILETYPES
    # ),
    data = attr.label_list(
      allow_files = True,
      doc = "Data files used by this executable."
    ),
    strip_data_prefixes = attr.bool(
      doc = "Symlink each data file to the basename part in the runfiles root directory. E.g. test/foo.data -> foo.data.",
      default = False
    ),
    opts = attr.string_list(),
    copts = attr.string_list(),
    linkopts = attr.string_list(),
    preprocessor = attr.label(
      doc = "Preprocessor. Must be a single PPX executable.",
      allow_single_file = True,
      providers = [PpxInfo],
      executable = True,
      cfg = "exec",
    ),
    deps = attr.label_list(
      doc = "Dependencies. Do not include preprocessor (PPX) deps.",
      providers = [[OpamPkgInfo],
                   [OcamlLibraryProvider], [OcamlModuleProvider],
                   # [OcamlInterfaceProvider]]
                   [CcInfo]],
    ),
    mode = attr.string(default = "native"), # or "bytecode"
    message = attr.string()
  ),
  executable = True,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
