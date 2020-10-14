load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_providers:ocaml.bzl", "OcamlNsModuleProvider")
load("//implementation:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
)

# NOTE: Submodules are Bazel dependencies, but they are not OCaml
# deps. They are added to the dep graph, which means they must exist
# and if they change a rebuild of the ns module will be triggered,,
# but they are not used by OCaml to build the ns module.  So we do not
# need to check for transitive deps.
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
  inputs = []
  for sm in ctx.files.submodules:
    # add submodules to dep graph, bazel will ensure they exist
    inputs.append(sm)
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
  inputs.append(module_src)
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
  if ctx.attr.alwayslink:
    args.add("-linkall")
  args.add("-w", "-49") # Error (warning 49): no cmi file was found in path for module <m>
  args.add("-c")
  args.add("-no-alias-deps")
  args.add("-opaque")
  args.add("-o", obj_cmx)
  args.add(module_src.path)
  ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args],
      inputs = inputs, # [module_src],
      outputs = [obj_cmx, obj_o, obj_cmi],
      tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
      mnemonic = "NsModuleAction",
      progress_message = "ns_module_action for {rule}{msg}".format(
          rule = ctx.attr._rule,
          # target = ctx.label.name,
          msg = ": " + ctx.attr.msg if ctx.attr.msg else ""
      )
  )

  provider = None
  if ctx.attr._rule == "ocaml_ns_module":
      provider = OcamlNsModuleProvider(
          payload = struct(
              ns  = ctx.attr.ns,
              # we don't need cmi unless it comes from an mli, when never happens with ns_modules?
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
      DefaultInfo(files = depset(direct = [obj_cmx, obj_o])), # obj_cmi])),
      provider
  ]
# OutputGroupInfo(bin = depset([bin_output]))]
