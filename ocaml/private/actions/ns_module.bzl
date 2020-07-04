load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml/private:providers.bzl",
     "OcamlModuleProvider",
     "PpxModuleProvider")
load("//ocaml/private:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     # "get_src_root",
     # "strip_ml_extension",
     # "OCAML_FILETYPES",
     # "OCAML_IMPL_FILETYPES",
     # "OCAML_INTF_FILETYPES",
     # "WARNING_FLAGS"
)

def ns_module_action(ctx):
  # print("ns_module_action: %s" % ctx)
  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  ## generate content: one alias per submodule
  aliases = []
  pfx = capitalize_initial_char(ctx.attr.ns)
  for sm in ctx.files.submodules:
      alias = "module {sm} = {pfx}{sm}".format(
          sm=capitalize_initial_char(paths.split_extension(sm.basename)[0]),
          pfx = pfx
      )
      aliases.append(alias)
      # print("ALIASES: %s" % aliases)

  ## declare ns module file, as input to compile action
  module_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".ml"
  module_src = ctx.actions.declare_file(module_fname)
  # print("NS MODULE SRC: %s" % module_src)

  ## action: generate ns module file with alias content
  ctx.actions.write(
      output = module_src,
      content = "\n".join(aliases) + "\n"
  )

  ## now declare compilation outputs. compiling always produces 3 files:
  obj_cmi_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".cmi"
  obj_cmi = ctx.actions.declare_file(obj_cmi_fname)
  obj_cmx_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".cmx"
  obj_cmx = ctx.actions.declare_file(obj_cmx_fname)
  obj_o_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".o"
  obj_o = ctx.actions.declare_file(obj_o_fname)

  ## action: compile ns module
  args = ctx.actions.args()
  args.add("ocamlopt")
  args.add_all(ctx.attr.opts)
  args.add("-c")
  args.add("-o", obj_cmx)
  args.add(module_src.path)
  ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args],
      inputs = [module_src],
      outputs = [obj_cmx, obj_o, obj_cmi],
      tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
      mnemonic = "NsModuleAction",
      progress_message = "ns_module_action for rule {rule}{msg}".format(
          rule = ctx.attr._rule, target = ctx.label.name,
          msg = ": " + ctx.attr.msg if ctx.attr.msg else ""
      )
  )

  provider = None
  if ctx.attr._rule == "ocaml_ns_module":
      provider = OcamlModuleProvider(
          module = struct(
              cmi = obj_cmi,
              cm  = obj_cmx,
              o   = obj_o
          ),
          deps = struct(
              opam  = depset(),
              nopam = depset()
          )
      )
  else:
      provider = PpxModuleProvider(
          payload = struct(
              cmi = obj_cmi,
              cm  = obj_cmx,
              o   = obj_o
          ),
          deps = struct(
              opam  = depset(),
              nopam = depset()
          )
      )

  return [
      DefaultInfo(files = depset(direct = [obj_cmx, obj_cmi, obj_o])),
      provider
  ]
# OutputGroupInfo(bin = depset([bin_output]))]
