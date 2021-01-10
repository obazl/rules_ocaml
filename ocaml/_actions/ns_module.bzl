load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlNsModulePayload",
     "OcamlNsModuleProvider")
load("//ppx:_providers.bzl", "PpxCompilationModeSettingProvider")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ppx:_providers.bzl", "PpxNsModuleProvider")
load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
)

tmpdir = "_obazl_/"

# NOTE: Submodules are Bazel dependencies, but they are not OCaml
# deps. They are added to the dep graph, which means they must exist
# and if they change a rebuild of the ns module will be triggered,,
# but they are not used by OCaml to build the ns module.  So we do not
# need to check for transitive deps.
def ns_module_compile(ctx):
  # print("ns_module_compile: %s" % ctx.label.name)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  ## generate content: one alias per submodule
  aliases = []
  ## declare ns module file, as input to compile action
  ns_module_name = ctx.attr.ns
  # print("NS_MODULE_NAME %s" % ns_module_name)
  pfx = capitalize_initial_char(ctx.attr.ns) + ctx.attr.ns_sep
  dep_graph = []
  for sm in ctx.files.submodules:
    # add submodules to dep graph, bazel will ensure they exist
    dep_graph.append(sm)
    # now construct alias statement
    sm_parts = paths.split_extension(sm.basename)
    module = sm_parts[0]
    if (module.lower() == ns_module_name.lower()):
      ns_module_name = ns_module_name + ctx.attr.ns_sep
    else:
      alias = "module {sm} = {pfx}{sm}".format(
        sm=capitalize_initial_char(module),
        pfx = pfx
      )
      aliases.append(alias)

  mode = None
  if CompilationModeSettingProvider in ctx.attr._mode:
      mode = ctx.attr._mode[CompilationModeSettingProvider].value
  else:
      mode = ctx.attr._mode[PpxCompilationModeSettingProvider].value

  # module_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".ml"
  module_src = ctx.actions.declare_file(tmpdir + ns_module_name + ".ml")
  dep_graph.append(module_src)
  # print("NS MODULE SRC: %s" % module_src)

  ## action: generate ns module file with alias content
  ctx.actions.write(
      output = module_src,
      content = "\n".join(aliases) + "\n"
  )

  ## now declare compilation outputs. compiling always produces 3 files:
  obj_cmi_fname = ns_module_name + ".cmi"
  obj_cmi = ctx.actions.declare_file(tmpdir + obj_cmi_fname)
  if mode == "native":
      obj_cm__fname = ns_module_name + ".cmx" # tc.objext
  else:
      obj_cm__fname = ns_module_name + ".cmo" # tc.objext
  obj_cm_ = ctx.actions.declare_file(tmpdir + obj_cm__fname)

  outputs = []
  directs = []
  ## action: compile ns module

  ################################
  args = ctx.actions.args()
  # args.add("ocamlopt")
  # if CompilationModeSettingProvider in ctx.attr._mode:
  if mode == "bytecode":
      args.add(tc.ocamlc.basename)
  else:
      args.add(tc.ocamlopt.basename)
      obj_o_fname = ns_module_name + ".o"
      obj_o = ctx.actions.declare_file(tmpdir + obj_o_fname)
      outputs.append(obj_o)
      directs.append(obj_o)

  directs.append(obj_cm_)
  #?? directs.append(obj_cmi)
  outputs.append(obj_cm_)
  outputs.append(obj_cmi)

  if ctx.attr._warnings:
      # print("WARNINGS: %s" % ctx.attr.warnings[BuildSettingInfo].value)
      args.add_all(ctx.attr._warnings[BuildSettingInfo].value, before_each="-w", uniquify=True)

  if hasattr(ctx.attr, "opts"):
      args.add_all(ctx.attr.opts)

  ## This flag is REQUIRED for ns modules; see https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html
  args.add("-no-alias-deps")
  # args.add("-opaque")
  # if ctx.attr.alwayslink: args.add("-linkall")
  # args.add("-linkall")
  # args.add("-w", "-49")

  args.add("-c")
  args.add("-o", obj_cm_)
  args.add(module_src.path)

  ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args],
      inputs = dep_graph, # [module_src],
      outputs = outputs,
      tools = [tc.ocamlfind, tc.ocamlopt],
      mnemonic = "NsModuleAction",
      progress_message = "compiling: @{ws}//{pkg}:{tgt} (rule {rule})".format(
          ws  = ctx.workspace_name,
          pkg = ctx.label.package,
          rule= "ocaml_ns",
          tgt=ctx.label.name,
          # msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
      )
      # progress_message = "ns_module_compile for {rule}{msg}".format(
      #     rule = ctx.attr._rule,
      #     # target = ctx.label.name,
      #     msg = ": " + ctx.attr.msg if ctx.attr.msg else ""
      # )
  )

  provider = None
  # if ctx.attr._rule == "ocaml_ns":
  if CompilationModeSettingProvider in ctx.attr._mode:
      ## ocaml_ns
      if mode == "native":
          payload = OcamlNsModulePayload(
              ns  = ctx.attr.ns,
              sep = ctx.attr.ns_sep,
              # we don't need cmi unless it comes from an mli, when never happens with ns_modules?
              cmi = obj_cmi,
              cmx  = obj_cm_,
              o   = obj_o
          )
      else:
          payload = OcamlNsModulePayload(
              ns  = ctx.attr.ns,
              sep = ctx.attr.ns_sep,
              # we don't need cmi unless it comes from an mli, when never happens with ns_modules?
              cmi = obj_cmi,
              cmo  = obj_cm_,
          )
      provider = OcamlNsModuleProvider(
          payload = payload,
          deps = struct(
              opam  = depset(),
              nopam = depset()
          )
      )
  else:
      ## ppx_ns
      if mode == "native":
          payload = struct(
              ns  = ctx.attr.ns,
              sep = ctx.attr.ns_sep,
              # we don't need cmi unless it comes from an mli, when never happens with ns_modules?
              cmi = obj_cmi,
              cmx  = obj_cm_,
              o   = obj_o
          )
      else:
          payload = struct(
              ns  = ctx.attr.ns,
              sep = ctx.attr.ns_sep,
              # we don't need cmi unless it comes from an mli, when never happens with ns_modules?
              cmi = obj_cmi,
              cmo  = obj_cm_,
          )

      provider = PpxNsModuleProvider(
          payload = payload,
          deps = struct(
              opam  = depset(),
              nopam = depset()
          )
      )

  return [
      DefaultInfo(files = depset(directs)),
      provider
  ]
# OutputGroupInfo(bin = depset([bin_output]))]
