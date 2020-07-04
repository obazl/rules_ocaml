load("//opam:opam.bzl",
    "OPAMROOT")
load("//ocaml/private:common.bzl",
     "OCAML_VERSION")
load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     "compile_new_srcs")
load("//ocaml/private/actions:ocaml.bzl",
     "ocaml_compile")
load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("//ocaml/private:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

# /Users/gar/.opam/4.07.1/bin/ocamldep.opt
# -modules
# -impl src-ocaml/baijiu_blake2b.ml
# > _build/default/src-ocaml/.digestif_ocaml.objs/baijiu_blake2b.ml.d

################################################################
def _ocaml_deps_impl(ctx):
  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  args = ctx.actions.args()
  args.add_all(ctx.attr.opts)

  deps = []

  ordered_srcs = sorted(ctx.files.srcs)

  depfile = ctx.actions.declare_file(ctx.label.name + ".depends")
  cmd = ""
  for src in [x for x in ctx.files.srcs if not x.path.endswith(".mli")]:
    # depfile = ctx.actions.declare_file(src.basename + ".depends")
    # deps.append(depfile)

    cmd = cmd + tc.ocamldep.path + " -modules -native -one-line -impl " + src.path + " >> " + depfile.path + ";\n"

  ctx.actions.run_shell(
    env = env,
    tools = [tc.ocamldep],
    command = cmd,
    # command = tc.ocamldep.path + " $1 -impl $2 >> " + depfile.path,
    # arguments = [args, src.path, depfile.path],
    inputs = ctx.files.srcs,
    outputs = [depfile],
    progress_message = "ocaml_deps({}): {}".format(
      ctx.label.name, src.path
    )
  )
  print(ordered_srcs)
  return [DefaultInfo(files = depset(direct = ordered_srcs + [depfile]))]

################################################################
ocaml_deps = rule(
  implementation = _ocaml_deps_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    srcs = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    opts = attr.string_list(),
    copts = attr.string_list(),
    linkopts = attr.string_list(),
    deps = attr.label_list(
      doc = "Dependencies. Do not include preprocessor (PPX) deps."
    ),
    mode = attr.string(default = "native"), # or "bytecode"
    message = attr.string()
  ),
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
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

