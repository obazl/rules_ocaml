load("@bazel_skylib//lib:paths.bzl", "paths")

# load("//ppx/_transitions:transitions.bzl", "ppx_mode_transition")

# load("//ocaml/_transistions:mode_transitions.bzl",
#      "ocaml_mode_transition_incoming",
#      "ocaml_mode_transition_outgoing",)

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

# load("//ocaml/_transitions:ns_transitions.bzl",
#      "ocaml_ns_transition_incoming",
#      "ocaml_ns_transition_reset")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlDepsetProvider",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModulePayload",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider",
     "OcamlSDK")

load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider",
     "PpxNsModuleProvider")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_actions:rename.bzl", "rename_module")

load("//ocaml/_actions:utils.bzl", "get_options")

# load("//ocaml/_actions:compile_module.bzl", "compile_module")
load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name",
)

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load(":options_ocaml.bzl", "options_ocaml")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

tmpdir = "_obazl_/"

################################################################
########## RULE:  OCAML_MODULE  ################
def impl_module(ctx):

  debug = False
  # if ctx.label.name == "structured_log_events":
  #     debug = True

  # for [k, v] in ctx.var.items():
  #     print("VARS: {k} = {v}".format(k = k, v = v))

  # x = ["STAMPFILES %s" % f.path for f in (ctx.info_file, ctx.version_file)]
  # print(x)

  if debug:
      print("MODULE TARGET: %s" % ctx.label.name)

  if ctx.attr._rule == "ocaml_module":
      mode = ctx.attr._mode[CompilationModeSettingProvider].value
      if len(ctx.attr.ppx_tags) > 1:
          fail("Only one ppx_tag allowed currently.")
  else:
      mode = ctx.attr._mode[0][CompilationModeSettingProvider].value

  mydeps = get_all_deps(ctx.attr._rule, ctx)
  # if debug:
  #     print("ALL DEPS for target %s:" % ctx.label.name)
  #     print(mydeps)

  # if mode == "dual":
  #     native_result = compile_module("ocaml_module", ctx, "native", mydeps)
  #     bc_result     = compile_module("ocaml_module", ctx, "bytecode", mydeps)
  # else:
  # result        = compile_module("ocaml_module", ctx, mode, mydeps)

  ################################################################
  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx),
         "OCAMLFIND_IGNORE_DUPS_IN": ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"
         # /home/nomaddo/.opam/4.03.0/lib/ocaml/compiler-libs
         }

  # mode = None
  # # print("_MODE: %s" % ctx.attr._mode)
  # if rule == "ocaml_module":
  #     mode = ctx.attr._mode[CompilationModeSettingProvider].value
  # elif rule == "ppx_module":
  #     mode = ctx.attr._mode[0][PpxCompilationModeSettingProvider].value
  # # print("RESOLVED MODE: %s" % mode)

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
  elif ctx.attr.ns:
      # rename this module to put it in the namespace
      xsrc = rename_module(ctx, ctx.file.src) #, ctx.attr.ns)
      # tmpdir = ""
  else:
      xsrc = ctx.file.src
      # tmpdir = ""

  # cm_fname = ctx.file.src.basename.rstrip("ml") + "cmx"
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

  # print("^^^^^^^^^^^^^^^^ VAR: %s" % ctx.var)
  # for (k,v) in ctx.var.items():
  #     print("VAR ITEM: {k} = {v}".format(k=k, v=v))

  options = get_options(rule, ctx)
  args.add_all(options)

  # we need to enumerate all build deps so we can add them to the
  # action dep_graph, and add a -I arg for them (we do not need to list
  # them as command line inputs, just the dirs where they can be found).
  build_deps = []

  cc_deps  = []
  link_search = []

  if ctx.attr.ns:
      ## This is a namespaced module
      if OcamlNsModuleProvider in ctx.attr.ns:
          if mode == "native":
              ns_cm = ctx.attr.ns[OcamlNsModuleProvider].payload.cmx
          else:
              ns_cm = ctx.attr.ns[OcamlNsModuleProvider].payload.cmo
      else:
          if mode == "native":
              ns_cm = ctx.attr.ns[PpxNsModuleProvider].payload.cmx
          else:
              ns_cm = ctx.attr.ns[PpxNsModuleProvider].payload.cmo
      ns_module = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
      ## -no-alias-deps is REQUIRED for namespaced modules
      args.add("-no-alias-deps")
      args.add("-open", ns_module)
      # args.add("-w", "-49") # ignore Warning 49: no cmi file was found in path for module x

  # for datum in ctx.attr.data:
  #     dep_graph.extend(datum.files.to_list())

  if ctx.attr.intf:
    # if ctx.file.intf.extension == "mli":
    #     cmifname = paths.replace_extension(ctx.file.intf.basename, ".cmi")
    #     obj_cmi = ctx.actions.declare_file(tmpdir + "/" + cmifname)
    if ctx.file.intf.extension == "cmi":
        obj_cmi = ctx.attr.intf[OcamlInterfaceProvider].payload.cmi
        dep_graph.append(ctx.file.intf)
        dep_graph.append(ctx.attr.intf[OcamlInterfaceProvider].payload.mli)
        # if ctx.attr.cmt or ("-bin-annot" in ctx.attr.opts):
        if "-bin-annot" in options:
            if hasattr(ctx.attr.intf[OcamlInterfaceProvider].payload, "cmt"):
                obj_cmt = ctx.attr.intf[OcamlInterfaceProvider].payload.cmt

        if debug:
            print("Incoming .cmi: %s" % obj_cmi)
            # obj_cmi = ctx.attr.intf.files.to_list()[0]
  else:
      ## compiler will infer and emit .cmi from .ml src
    cmifname = paths.replace_extension(xsrc.basename, ".cmi")
    obj_cmi = ctx.actions.declare_file(tmpdir + cmifname)
    if "-bin-annot" in ctx.attr.opts:
        ## FIXME: only do this if no cmi intf provided
        obj_cmt = ctx.actions.declare_file(tmpdir + paths.replace_extension(xsrc.basename, ".cmt"))
        outputs.append(obj_cmt)
  if debug:
      print("OBJ_CMI: %s" % obj_cmi)
  # cm_fname = paths.replace_extension(ctx.file.src.basename, tc.objext)
  # obj_cm_ = ctx.actions.declare_file(cm_fname)
  # ofname = paths.replace_extension(ctx.file.src.basename, ".o")
  # obj_o = ctx.actions.declare_file(ofname)

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
        # args.add(ctx.file.intf.path)
        # args.add("-intf", ctx.file.intf.path)
        dep_graph.append(ctx.file.intf)
        args.add("-intf", ctx.file.intf)
    else:
        provider = ctx.attr.intf[OcamlInterfaceProvider]
        if debug:
            print("CMI: %s" % provider.payload.cmi)
            print("MLI: %s" % provider.payload.mli)
            print("CMI PROVIDER: %s" % provider)
            dep_graph.append(provider.payload.cmi)
            dep_graph.append(provider.payload.mli)
        includes.append(provider.payload.cmi.dirname)
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
      # if debug:
      #     print("NOPAM DEP: %s\n\n" % dep)
      if dep.extension == "cmx":
          dep_graph.append(dep)
          includes.append(dep.dirname)
      elif dep.extension == "cmo":
          dep_graph.append(dep)
          includes.append(dep.dirname)
        ## .cmo always accompanied by .o
      elif dep.extension == "o":
          dep_graph.append(dep)
          includes.append(dep.dirname)
      ## cmo/x files will always be accompanied by mli/cmi files
      elif dep.extension == "cmi":
          dep_graph.append(dep)
          ## THIS IS THE CRITICAL BIT for compiling! The compiler must be able to find the cmi files.
          includes.append(dep.dirname)
        ## cmi ignored if mli not present!
      elif dep.extension == "mli":
           dep_graph.append(dep)
           includes.append(dep.dirname)
      elif dep.extension == "cma":
          # build_deps.append(dep)
          dep_graph.append(dep)
          includes.append(dep.dirname)
      elif dep.extension == "cmxa":
          # build_deps.append(dep)
          dep_graph.append(dep)
          includes.append(dep.dirname)
        ## .cmxa always accompanied by .a file
      elif dep.extension == "a":
          # print("STATIC %s" % dep)
          # if its in the nopam list, add it - it was approved by get_all_deps
          # linkmode filtering only for direct deps
          # if tc.linkmode == "static":
          # print("LINKING STATIC %s" % dep)

          ## TODO: if dep in mydeps.cc_alwayslink then 

          dep_graph.append(dep)
          link_search.append("-L" + dep.dirname)
          build_deps.append(dep)

# LINKOPTS = select({
#     "//bzl/host:macos": ["-cclib", "-lsodium"],
#     "//bzl/host:linux": [
#         "-cclib",
#         "-Wl,--push-state,-Bstatic",
#         "-cclib",
#         "-lsodium",
#         "-cclib",
#         "-Wl,--pop-state",
#     ],
# }, no_match_error = "Unsupported host.  MacOS and Linux only.")


          # libname = file_to_lib_name(dep)
          # cc_deps.append("-l" + dep.basename)
          ## FIXME
          # cc_deps.append("-lmarlin_plonk_stubs--1745127302.a")
          # else:
          #     print("XXXXXXXXXXXXXXXX OR WHAT")

      ####  BINARIES  ####
      elif dep.extension == "lo":
        if debug:
            # print("NOPAM .lo DEP: %s" % dep)
            dep_graph.append(dep)
            args.add("-ccopt", "-l" + dep.path)
      elif dep.extension == "so":
          # print("SO %s" % dep)
          # if tc.linkmode == "dynamic":
          # print("LINKING SO %s" % dep)
          dep_graph.append(dep)
          link_search.append("-L" + dep.dirname)
          libname = file_to_lib_name(dep)
          cc_deps.append("-l" + libname)
      elif dep.extension == "dylib":
          # print("DYLIB %s" % dep)
          # if tc.linkmode == "dynamic":
          # print("LINKING DYLIB %s" % dep)
          # print("LINK PATH %s" % dep.dirname)
          dep_graph.append(dep)
          link_search.append("-L" + dep.dirname)
          libname = file_to_lib_name(dep)
          cc_deps.append("-l" + libname)
      elif dep.extension == ".cmxs":
          includes.append(dep.dirname)

  ## adjunct deps: we're compiling a module, so make them eager
  ## NO: only use adjunct deps from ppx to compile this module,
  ## the adjunct deps in the deps tree are propagated.
  ## which should only happen for ppx_* rules.
  ## i.e. if an ocaml_module depends on a ppx lib, then it too is a ppx lib.
  ## FIXME: do not allow ocaml_modules to depend on ppx_*?

  ## FIXME: we do not compile cc code, no need for this?
  ## we only use ocamlfind's -ccopt for link flags
  # args.add_all(ctx.attr.cc_opts, before_each="-ccopt")

  args.add_all(includes, before_each="-I", uniquify = True)

  opam_deps = mydeps.opam.to_list()
  if len(opam_deps) > 0:
      ## FIXME: -linkpkg not needed for modules?
      args.add("-linkpkg") # adds OPAM cmxa files to command
      for dep in opam_deps:
          args.add("-package", dep.pkg.name) # adds directories of OPAM files to search path using -I

  ## add adjunct_deps from ppx provider
  ## adjunct deps in the dep graph are NOT compile deps of this module.
  ## only the adjunct deps of the ppx are.
  if ctx.attr.ppx:
      ppx_provider = ctx.attr.ppx[PpxExecutableProvider]
      if debug:
          print("PPX Provider: %s" % ppx_provider)
      for dep in ppx_provider.deps.opam_adjunct.to_list():
          if debug:
              print("OPAM adjunct dep: %s" % dep)
          args.add("-package", dep.pkg.name)
          # args.add("-package", dep.pkg.to_list()[0].name)
      for dep in ppx_provider.deps.nopam_adjunct.to_list():
          if debug:
              print("NOPAM adjunct dep: %s" % dep)
          if dep.extension == "cmxa":
              dep_graph.append(dep)
              includes.append(dep.dirname)
          if dep.extension == "cmx":
              dep_graph.append(dep)
              # Just to make sure (cmx and cmi should be in same dir?)
              includes.append(dep.dirname)
              # We do not need to list cmx files, the compiler will find them in the search path.
              # args.add(dep)
          # # no need to add .o? adding .cmx covers it?
          # if dep.extension == "o":
          #     includes.append(dep.dirname)
          if dep.extension == "cmi":
              includes.append(dep.dirname)
              dep_graph.append(dep)

  if len(cc_deps) > 0:
      if tc.linkmode == "static":
          if mode == "bytecode":
              args.add("-custom")
      args.add_all(link_search, before_each="-ccopt", uniquify = True)
      args.add_all(cc_deps, before_each="-cclib", uniquify = True)

  args.add_all(build_deps)

  # modules are always compile-only
  args.add("-c")

  if mode == "native":
      args.add("-o", obj_cmx)
  else:
      args.add("-o", obj_cmo)

  args.add("-impl", xsrc)

  dep_graph.extend(build_deps)
  # dep_graph.extend(cclib_deps)
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
      mnemonic = "CompileModuleAction",
      progress_message = "{mode} compiling {rule}: @{ws}//{pkg}:{tgt}{msg}".format(
          mode = mode,
          rule=rule,
          ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
          pkg = ctx.label.package,
          tgt=ctx.label.name,
          msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
      )
  )

  # if mode == "native":
  result = struct(
      cmi = obj_cmi,  # ctx.file.intf if ctx.file.intf else None,
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

  if debug:
      print("OCAML_MODULE COMPILE RESULT:")
      print(result)

  directs = []

  if ctx.attr._rule == "ocaml_module":
      if mode == "native":
          payload = OcamlModulePayload(
              # if we have an incoming cmi, its in the nopam deps
              # otherwise, we create it so it goes here(?)
              # what about the mli?
              cmi = result.cmi,  # ctx.file.intf if ctx.file.intf else None,
              mli = result.mli,
              cmx  = result.cmx,
              cmt = result.cmt,
              o   = result.o
          )
          # directs = [result.cmx, result.o, result.cmi]
      else:
          payload = OcamlModulePayload(
              # if we have an incoming cmi, its in the nopam deps
              # otherwise, we create it so it goes here(?)
              # what about the mli?
              cmi = result.cmi,  # ctx.file.intf if ctx.file.intf else None,
              mli = result.mli,
              cmo  = result.cmo,
              cmt = result.cmt,
          )
          # directs = [result.cmo, result.cmi]

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
          cmi = result.cmi,  #obj["cmi"] if "cmi" in obj else None,
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
              # opam_adjunct = depset(order = "postorder",
              #                    direct = opam_adjunct_deps),
              nopam = result.nopam,
              nopam_adjunct = mydeps.nopam_adjunct,
              # nopam_adjunct = depset(order = "postorder",
              #                    direct = nopam_adjunct_deps),
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
          direct = directs
      )
  )

  result = [defaultInfo, module_provider]

  if debug:
      print("OcamlModuleProvider RESULT:")
      print(result)

  return result
