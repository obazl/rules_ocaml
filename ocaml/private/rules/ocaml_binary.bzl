load("@obazl//opam:opam.bzl",
    "OPAMROOT")
load("@obazl//ocaml/private:common.bzl",
     "OCAML_VERSION")
load("@obazl//ocaml/private:actions/ppx.bzl",
     "apply_ppx",
     "compile_new_srcs")
load("@obazl//ocaml/private:actions/ocaml.bzl",
     "ocaml_compile")
load("@obazl//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("@obazl//ocaml/private:utils.bzl",
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
  tc = ctx.toolchains["@obazl//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

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
  # build_deps = []
  includes = []
  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args_intf.add("-package", dep[OpamPkgInfo].pkg)
      args_impl.add("-package", dep[OpamPkgInfo].pkg)
      # build_deps.append(dep[OpamPkgInfo].pkg)
    else:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".cmx"):
          args_intf.add(g)
          args_impl.add(g)
          includes.append(g.dirname)
          # build_deps.append(g)
        if g.path.endswith(".cmxa"):
          args_intf.add(g)
          args_impl.add(g)
          includes.append(g.dirname)
          # build_deps.append(g)
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

  for src in ctx.files.srcs:
    if src.path.endswith(".mli"):
      srcs_mli.append(src)
      # register cmi outfile with Bazel
      outfname = src.basename.rstrip(".mli") + ".cmi"
      outf = ctx.actions.declare_file(outfname)
      outs_cmi.append(outf)
    else:
      if src.path.endswith(".ml"):
        srcs_ml.append(src)
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

  # then compile implementation files and produce executable
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args_impl],
    inputs = srcs_ml + outs_cmi,
    outputs = [outbinary],
    # tools = [], # ppx_dep] # , tc.opam, tc.ocamlfind, tc.ocamlopt]
    progress_message = "ocaml_compile({}): compiling implementations {}".format(
      ctx.label.name, ctx.attr.message
    )
  )

  return [DefaultInfo(executable = outbinary)]

################################################################
def _compile_with_ppx(ctx):
  tc = ctx.toolchains["@obazl//ocaml:toolchain"]
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
  args.add("-verbose")
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
    _sdkpath = attr.label(
      default = Label("@ocaml_sdk//:path")
    ),
    srcs = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    srcs_impl = attr.label_list(
      allow_files = OCAML_IMPL_FILETYPES
    ),
    srcs_intf = attr.label_list(
      allow_files = OCAML_INTF_FILETYPES
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
      doc = "Dependencies. Do not include preprocessor (PPX) deps."
    ),
    mode = attr.string(default = "native"), # or "bytecode"
    message = attr.string()
  ),
  executable = True,
  toolchains = ["@obazl//ocaml:toolchain"],
)


  # interface_inputs = []
  # intf_out = ctx.actions.declare_file("hello_world_test.cmi")
  # interface_outputs = [intf_out]
  # for s in ctx.attr.srcs_intf:
  #   interface_inputs.append(s.label.name)
  #   # interface_outputs.append(s.files.to_list()[0])
  # print("INTERFACE FILES:")
  # print(interface_inputs)

  # implementation_inputs = []
  # impl_out = ctx.actions.declare_file("hello_world_test")
  # implementation_outputs = [impl_out]
  # for s in ctx.attr.srcs_impl:
  #   implementation_inputs.append(s.label.name)
  #   # implementation_outputs.append(s.files.to_list()[0])
  # # print("IMPLEMENTATION FILES:")
  # # print(implementation_inputs)

  # ################ compile interface files ################
  # command = " ".join([
  #   opam_env_command,
  #   ocamlfind, # .path,
  #   "ocamlopt",
  #   "-verbose",
  #   # ocamlbuild_opts,
  #   " ".join(ctx.attr.copts),
  #   ppx,
  #   lflags,
  #   # pkgs,
  #   "-linkpkg -package base -package ppxlib",
  #   # "-c ",
  #   "-linkall",
  #   "-o hello_world_test.cmi",
  #   # interface_outputs[0].basename,
  #   # src_root,
  #   " ".join(interface_inputs),
  #   # "&& cp -L %s %s" % (intermediate_bin, ctx.outputs.executable.path)
  # ])
  # print("command: " + command)
  # ctx.actions.run_shell(
  #   inputs = ctx.files.srcs_intf,
  #   # NOTE: here the tools attrib establishes the dependency of this
  #   # action on the preprocessor target. Without it, the ppx will not
  #   # be built.
  #   tools = [ppx_dep],
  #   # tools = [ocamlfind, ocamlbuild, opam],
  #   outputs = interface_outputs,
  #   command = command,
  #   mnemonic = "Ocamlbuild",
  #   progress_message = "Compiling OCaml interface files %s" % ctx.label.name,
  #   # This is (unfortunately) not hermetic yet.
  #     use_default_shell_env = True,
  #   execution_requirements = {"local": "1"},
  # )

