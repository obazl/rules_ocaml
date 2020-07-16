load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml/private:providers.bzl",
     "OcamlNsModuleProvider",
     "PpxNsModuleProvider",
)
load("//ocaml/private:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
)

def ns_module_action(ctx):
  # print("ns_module_action: %s" % ctx.label.name)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  ## generate content: one alias per submodule
  aliases = []
  ## declare ns module file, as input to compile action
  ns_module_name = ctx.attr.ns
  # print("NS_MODULE_NAME %s" % ns_module_name)
  pfx = capitalize_initial_char(ctx.attr.ns) + ctx.attr.ns_sep
  for sm in ctx.files.submodules:
    sm_parts = paths.split_extension(sm.basename)
    module = sm_parts[0]
    # print("NS MODULE %s" % module)
    if (module.lower() == ns_module_name.lower()):
      # print("NS MATCH!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
      ns_module_name = ns_module_name + ctx.attr.ns_sep
    else:
      alias = "module {sm} = {pfx}{sm}".format(
        sm=capitalize_initial_char(module),
        pfx = pfx
      )
      aliases.append(alias)

  # module_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".ml"
  module_src = ctx.actions.declare_file(ns_module_name + ".ml")
  # print("NS MODULE SRC: %s" % module_src)

  ## action: generate ns module file with alias content
  ctx.actions.write(
      output = module_src,
      content = "\n".join(aliases) + "\n"
  )

  ## now declare compilation outputs. compiling always produces 3 files:
  obj_cmi_fname = ns_module_name + ".cmi"
  obj_cmi = ctx.actions.declare_file(obj_cmi_fname)
  obj_cmx_fname = ns_module_name + ".cmx"
  obj_cmx = ctx.actions.declare_file(obj_cmx_fname)
  obj_o_fname = ns_module_name + ".o"
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
      provider = OcamlNsModuleProvider(
          payload = struct(
              ns  = ctx.attr.ns,
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
      provider = PpxNsModuleProvider(
          payload = struct(
              ns  = ctx.attr.ns,
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
