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
  srcs = ctx.files.srcs
  outfilename = ctx.label.name
  outbinary = ctx.actions.declare_file(outfilename)
  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  args = ctx.actions.args()
  args.add("ocamlopt")

  args.add_all(ctx.attr.opts)
  #TODO: if --verbose
  # args.add("-verbose")
  # args.add("-ccopt", "-v")
  args.add("-o", outbinary)
  # args.add("-w", "-24")
  # args.add("-linkpkg") # create executable
  # args.add("-linkall")
  opamdeps = []
  xdeps = []
  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      opamdeps.append(dep[OpamPkgInfo].pkg)
    else:
      ##FIXME: filter for PpxInfo deps
      xdeps.append(dep[PpxInfo].ppx)

  # non-ocamlfind-enabled deps:
  args.add_joined(xdeps, join_with=" ")

  # for ocamlfind-enabled deps, use -package
  args.add_joined("-package", opamdeps, join_with=",")

  args.add_all(srcs)

  #### REGISTER ACTION: OCAML_BINARY ####
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    # inputs = ctx.files.srcs_impl + ctx.files.srcs_intf,
    inputs = srcs,
    outputs = [outbinary],
    # force dependency resolution?
    tools = [], # ppx_dep] # , tc.opam, tc.ocamlfind, tc.ocamlopt]
    progress_message = "ocaml_compile({}): {}".format(
      ctx.label.name, ctx.attr.message,
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

