load("@bazel_skylib//lib:paths.bzl", "paths")

# load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlDepsetProvider",
     "OcamlInterfaceProvider",
     "OcamlModulePayload",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider",
     "OcamlSDK")

load("//ppx:_providers.bzl",
     "PpxExecutableProvider",
     "PpxModuleProvider",
     "PpxNsModuleProvider")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_rules/utils:rename.bzl", "rename_module")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name",
)

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

#####################
def impl_module(ctx):

  debug = False
  # if ctx.label.name == "_Red":
  #     debug = True

  if debug:
      print("MODULE TARGET: %s" % ctx.label.name)

  if ctx.attr._rule == "ocaml_module":
      mode = ctx.attr._mode[CompilationModeSettingProvider].value
      if len(ctx.attr.ppx_tags) > 1:
          fail("Only one ppx_tag allowed currently.")
  else:
      mode = ctx.attr._mode[0][CompilationModeSettingProvider].value

  mydeps = get_all_deps(ctx.attr._rule, ctx)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx),
         ## FIXME: make this work (issue 16):
         "OCAMLFIND_IGNORE_DUPS_IN": ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"
         }

  xsrc   = None
  dep_graph = []
  includes   = []
  outputs   = []

  tmpdir = "_obazl_/"
  if ctx.attr.ppx:
      ## this will also handle ns
      (tmpdir, xsrc) = impl_ppx_transform(rule, ctx, ctx.file.src)
      dep_graph.append(ctx.file.ppx)
      # a ppx executable may have adjunct deps; they are handled by get_all_deps
  # elif ctx.attr.ns:
  #     # rename this module to put it in the namespace
  #     xsrc = rename_module(ctx, ctx.file.src) #, ctx.attr.ns)
  elif ctx.attr.ns_init:
      # rename this module to put it in the namespace
      xsrc = rename_module(ctx, ctx.file.src) #, ctx.attr.ns)
  else:
      xsrc = ctx.file.src

  if mode == "native":
      cmxfname = paths.replace_extension(xsrc.basename, ".cmx")
      obj_cmx = ctx.actions.declare_file(tmpdir + cmxfname)
  else:
      cmofname = paths.replace_extension(xsrc.basename, ".cmo")
      obj_cmo = ctx.actions.declare_file(tmpdir + cmofname)

  if debug:
      if mode == "native":
          print("CMX FNAME: %s" % cmxfname)
          print("OBJ_CMX: %s" % obj_cmx)
      else:
          print("CMO FNAME: %s" % cmofname)
          print("OBJ_CMO: %s" % obj_cmo)
  obj_cmi = None
  obj_cmt = None

  #########################
  args = ctx.actions.args()
  if mode == "native":
      args.add(tc.ocamlopt.basename)
      outputs.append(obj_cmx)
      includes.append(obj_cmx.dirname)
      ofname = paths.replace_extension(xsrc.basename, ".o")
      obj_o = ctx.actions.declare_file(tmpdir + ofname)
      outputs.append(obj_o)
  else:
      outputs.append(obj_cmo)
      includes.append(obj_cmo.dirname)
      args.add(tc.ocamlc.basename)

  options = get_options(rule, ctx)
  args.add_all(options)

  build_deps = []
  cc_deps  = []
  link_search = []

  directs = []
  indirects = []

  # if ctx.attr.ns_init:
  #     for f in ctx.files.ns_init:
  #         # print("FFFFFFFFFFFFFFFF: %s" % f)
  #         dep_graph.append(f)
  #         indirects.append(f)

      # ## This is a namespaced module
      # if OcamlNsModuleProvider in ctx.attr.ns_init:
      #     if mode == "native":
      #         ns_cm = ctx.attr.ns_init[OcamlNsModuleProvider].payload.cmx
      #     else:
      #         ns_cm = ctx.attr.ns_init[OcamlNsModuleProvider].payload.cmo
      # elif PpxNsModuleProvider in ctx.attr.ns_init:
      #     if mode == "native":
      #         ns_cm = ctx.attr.ns_init[PpxNsModuleProvider].payload.cmx
      #     else:
      #         ns_cm = ctx.attr.ns_init[PpxNsModuleProvider].payload.cmo
      # else:
      #     print(ctx.attr.ns_init)
      #     fail("XXXXXXXXXXXXXXXX")
      # ns_module = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
      # args.add("-no-alias-deps") ## REQUIRED for namespaced modules
      # args.add("-open", ns_module)
      # args.add("-w", "-49") # ignore Warning 49: no cmi file was found in path for module x

  if ctx.attr.intf:
    ## FIXME: support .mli file?
    if ctx.file.intf.extension == "cmi":
        obj_cmi = ctx.attr.intf[OcamlInterfaceProvider].payload.cmi
        dep_graph.append(ctx.file.intf)
        dep_graph.append(ctx.attr.intf[OcamlInterfaceProvider].payload.mli)
        ## FIXME: issue #17
        # if ctx.attr.cmt or ("-bin-annot" in ctx.attr.opts):
        if "-bin-annot" in options:
            if hasattr(ctx.attr.intf[OcamlInterfaceProvider].payload, "cmt"):
                obj_cmt = ctx.attr.intf[OcamlInterfaceProvider].payload.cmt

  else:
    ## compiler will infer and emit .cmi from .ml src
    cmifname = paths.replace_extension(xsrc.basename, ".cmi")
    obj_cmi = ctx.actions.declare_file(tmpdir + cmifname)
    if "-bin-annot" in ctx.attr.opts:  ## Issue #17
        ## FIXME: only do this if no cmi intf provided
        obj_cmt = ctx.actions.declare_file(tmpdir + paths.replace_extension(xsrc.basename, ".cmt"))
        outputs.append(obj_cmt)

  # if we have an input cmi, we will add it to our Provider output,
  # but it is not an output of the action:
  dep_mli = None
  if ctx.attr.intf:
      if ctx.file.intf.extension == "cmi":
          dep_mli = ctx.attr.intf[OcamlInterfaceProvider].payload.mli
      elif ctx.file.intf.extension == "mli":
          dep_mli = ctx.file.intf
          outputs.append(obj_cmi)
  else:
      outputs.append(obj_cmi)

  if ctx.attr.intf:
    if ctx.file.intf.extension == "mli":
        dep_graph.append(ctx.file.intf)
        args.add("-intf", ctx.file.intf)
    else:
        provider = ctx.attr.intf[OcamlInterfaceProvider]
        dep_graph.append(provider.payload.cmi)
        includes.append(provider.payload.cmi.dirname)
        dep_graph.append(provider.payload.mli)
        includes.append(provider.payload.mli.dirname)
        # cmi inputs have deps too!
        for dep in provider.deps.nopam.to_list():
            if dep.extension == "cmx":
                dep_graph.append(dep)
                includes.append(dep.dirname)
            elif dep.extension == "cmo":
                dep_graph.append(dep)
                includes.append(dep.dirname)
            elif dep.extension == "cmi":
                dep_graph.append(dep)
                includes.append(dep.dirname)
            elif dep.extension == "mli":
                dep_graph.append(dep)
                includes.append(dep.dirname)

  for dep in mydeps.nopam.to_list():
      # print("NOPAM DEP: %s" % dep)
      if dep.extension == "cmx":
          dep_graph.append(dep)
          includes.append(dep.dirname)
      elif dep.extension == "cmo":
          dep_graph.append(dep)
          includes.append(dep.dirname)
      elif dep.extension == "o":
          dep_graph.append(dep)
          includes.append(dep.dirname)
      elif dep.extension == "cmi":
          ## The compiler must be able to find the cmi files.
          dep_graph.append(dep)
          includes.append(dep.dirname)
        ## cmi ignored if mli not present!
      elif dep.extension == "mli":
           dep_graph.append(dep)
           includes.append(dep.dirname)
      elif dep.extension == "cma":
          dep_graph.append(dep)
          includes.append(dep.dirname)
      elif dep.extension == "cmxa":
          dep_graph.append(dep)
          includes.append(dep.dirname)
      elif dep.extension == "a":
          dep_graph.append(dep)
          link_search.append("-L" + dep.dirname)
          build_deps.append(dep)

# linkall (gcc):
#         "-cclib",
#         "-Wl,--push-state,-Bstatic",
#         "-cclib",
#         "-lmylib",
#         "-cclib",
#         "-Wl,--pop-state",

      elif dep.extension == "so":
          dep_graph.append(dep)
          link_search.append("-L" + dep.dirname)
          libname = file_to_lib_name(dep)
          cc_deps.append("-l" + libname)
      elif dep.extension == "dylib":
          dep_graph.append(dep)
          link_search.append("-L" + dep.dirname)
          libname = file_to_lib_name(dep)
          cc_deps.append("-l" + libname)
      elif dep.extension == ".cmxs":
          includes.append(dep.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)

  opam_deps = mydeps.opam.to_list()
  if len(opam_deps) > 0:
      ## FIXME: -linkpkg tells ocamlfind to add OPAM cma/cmxa files to command line.
      ## Do we need it for modules?
      # args.add("-linkpkg")
      for dep in opam_deps:
          args.add("-package", dep.pkg.name) # tell ocamlfind to add OPAM file dirs to search path with -I

  ## add adjunct_deps from ppx provider
  ## adjunct deps in the dep graph are NOT compile deps of this module.
  ## only the adjunct deps of the ppx are.
  if ctx.attr.ppx:
      ppx_provider = ctx.attr.ppx[PpxExecutableProvider]
      for dep in ppx_provider.deps.opam_adjunct.to_list():
          args.add("-package", dep.pkg.name)
      for dep in ppx_provider.deps.nopam_adjunct.to_list():
          if dep.extension == "cmxa":
              dep_graph.append(dep)
              includes.append(dep.dirname)
          if dep.extension == "cmx":
              dep_graph.append(dep)
              includes.append(dep.dirname)
          if dep.extension == "cmi":
              includes.append(dep.dirname)
              dep_graph.append(dep)

  if len(cc_deps) > 0:
      ## FIXME: correctly handle static v. dynamic linking in bytecode mode ('-custom' flag)
      if tc.linkmode == "static":
          if mode == "bytecode":
              args.add("-custom")
      args.add_all(link_search, before_each="-ccopt", uniquify = True)
      args.add_all(cc_deps, before_each="-cclib", uniquify = True)

  args.add_all(build_deps)

  ns = None
  ## ns_init target produces two files, module and interface
  if ctx.files.ns_init:
      for dep in ctx.files.ns_init:
          # print("NS_INIT DEP: %s" % dep)
          bn = dep.basename
          # print("NS_INIT DEP BASENAME: %s" % bn)
          ext = dep.extension
          ns = bn[:-(len(ext)+1)]
          # print("NS: %s" % ns)
          if dep.extension == "cmo":
              dep_graph.append(dep)
              # args.add(dep)
          if dep.extension == "cmi":
              dep_graph.append(dep)

  if ns != None:
      args.add("-no-alias-deps")
      args.add("-open", ns)

  args.add("-c")

  if mode == "bytecode":
      args.add("-o", obj_cmo)
  else:
      args.add("-o", obj_cmx)

  args.add("-impl", xsrc)

  dep_graph.extend(build_deps)
  dep_graph.append(xsrc)

  if debug:
      print("\n\t\t================ INPUTS (DEP_GRAPH) ================\n\n")
      for dep in dep_graph:
          print("\nINPUT: %s\n\n" % dep)

  if debug:
      print("\n\t\t================ OUTPUTS ================\n\n")
      for dep in outputs:
          print("\nOUTPUT: %s\n\n" % dep)

  action_args = struct(
      args = [args],
      inputs = dep_graph,
      outputs = outputs
  )

  ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = action_args.args,
      inputs    = action_args.inputs,
      outputs   = action_args.outputs,
      tools = [tc.ocamlfind, tc.ocamlopt, tc.ocamlc],
      mnemonic = "OCamlModuleCompile" if ctx.attr._rule == "ocaml_module" else "PpxModuleCompile",
      progress_message = "{mode} compiling {rule}: @{ws}//{pkg}:{tgt}{msg}".format(
          mode = mode,
          rule=ctx.attr._rule,
          ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
          pkg = ctx.label.package,
          tgt=ctx.label.name,
          msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
      )
  )

  result = struct(
      cmi = obj_cmi,
      mli = dep_mli,
      cmx  = obj_cmx if mode == "native" else None,
      cmo  = obj_cmo if mode == "bytecode" else None,
      cmt = obj_cmt,
      o   = obj_o if mode == "native" else None,
      opam = mydeps.opam,
      nopam = mydeps.nopam,
      cc_deps = mydeps.cc_deps
  )

  ################################################################

  if ctx.attr._rule == "ocaml_module":
      if mode == "native":
          payload = OcamlModulePayload(
              cmi = result.cmi,
              mli = result.mli,
              cmx  = result.cmx,
              cmt = result.cmt,
              o   = result.o
          )
      else:
          payload = OcamlModulePayload(
              cmi = result.cmi,
              mli = result.mli,
              cmo  = result.cmo,
              cmt = result.cmt,
          )
      module_provider = OcamlModuleProvider(
          payload = payload,
          deps = OcamlDepsetProvider(
              opam    = result.opam,
              nopam   = result.nopam,
              cc_deps = result.cc_deps
          )
      )
  elif ctx.attr._rule == "ppx_module":
      payload = struct(
          cmi = result.cmi,
          mli = result.mli,
          cmx  = result.cmx,
          cmo  = result.cmo,
          cmt = result.cmt,
          o   = result.o
      )
      module_provider = PpxModuleProvider(
          payload = payload,
          deps = struct(
              opam  = result.opam,
              opam_adjunct = mydeps.opam_adjunct,
              nopam = result.nopam,
              nopam_adjunct = mydeps.nopam_adjunct,
              cc_deps = result.cc_deps
          )
      )

  if result.cmo: directs.append(result.cmo)
  if result.cmx: directs.append(result.cmx)
  if result.o:   directs.append(result.o)
  if result.cmi: directs.append(result.cmi)
  if result.mli: directs.append(result.mli)
  if result.cmt: directs.append(result.cmt)
  defaultInfo = DefaultInfo(
      files = depset(
          order = "postorder",
          direct = directs,
          # transitive = [depset( order = "postorder", direct = indirects )]
      )
  )
  # print("DEFAULT: %s" % defaultInfo)

  return [defaultInfo, module_provider]
