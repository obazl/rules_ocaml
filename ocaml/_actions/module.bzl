load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_providers:ocaml.bzl",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_providers:ppx.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("//ocaml/_actions:ppx_transform.bzl", "ppx_transform_action")
load("//ocaml/_actions:rename.bzl", "rename_module")

load("//implementation:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

################################################################
def compile_module(rule, ctx, mydeps):
  debug = False
  # if (ctx.label.name == "snark0.cm_"):
  # if ctx.label.name == "Register_event":
  #     debug = True

  if debug:
      print("COMPILE_MODULE: %s" % ctx.label.name)
      print("DEPSET:")
      print(mydeps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  xsrc   = None
  dep_graph = []
  outputs   = []

  tmpdir = "_obazl_/"
  if ctx.attr.ppx:
      ## this will also handle ns
      (tmpdir, xsrc) = ppx_transform_action(rule, ctx, ctx.file.src)
      dep_graph.append(ctx.file.ppx)
      # a ppx executable may have lazy deps; they are handled by get_all_deps
  elif ctx.attr.ns:
      # rename this module to put it in the namespace
      xsrc = rename_module(ctx, ctx.file.src) #, ctx.attr.ns)
      # tmpdir = ""
  else:
      xsrc = ctx.file.src
      # tmpdir = ""

  # cmxfname = ctx.file.src.basename.rstrip("ml") + "cmx"
  cmxfname = paths.replace_extension(xsrc.basename, tc.objext)
  obj_cmx = ctx.actions.declare_file(tmpdir + cmxfname)
  if debug:
      print("CMX FNAME: %s" % cmxfname)
      print("OBJ_CMX: %s" % obj_cmx)
  obj_cmi = None
  obj_cmt = None
  if ctx.attr.intf:
    # if ctx.file.intf.extension == "mli":
    #     cmifname = paths.replace_extension(ctx.file.intf.basename, ".cmi")
    #     obj_cmi = ctx.actions.declare_file(tmpdir + "/" + cmifname)
    if ctx.file.intf.extension == "cmi":
        obj_cmi = ctx.attr.intf[OcamlInterfaceProvider].payload.cmi
        dep_graph.append(ctx.file.intf)
        dep_graph.append(ctx.attr.intf[OcamlInterfaceProvider].payload.mli)
        if "-bin-annot" in ctx.attr.opts:
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
  ofname = paths.replace_extension(xsrc.basename, ".o")
  obj_o = ctx.actions.declare_file(tmpdir + ofname)
  # cmxfname = paths.replace_extension(ctx.file.src.basename, tc.objext)
  # obj_cmx = ctx.actions.declare_file(cmxfname)
  # ofname = paths.replace_extension(ctx.file.src.basename, ".o")
  # obj_o = ctx.actions.declare_file(ofname)

  #########################
  args = ctx.actions.args()
  args.add(tc.compiler.basename)
  # args.add("-w", ctx.attr.warnings)
  # options = tc.opts + ctx.attr.opts
  # args.add_all(options)
  args.add_all(ctx.attr.opts)
  if ctx.attr.alwayslink:
      args.add("-linkall")

  # modules are always compile-only
  args.add("-c")

  # we need to enumerate all build deps so we can add them to the
  # action dep_graph, and add a -I arg for them (we do not need to list
  # them as command line inputs, just the dirs where they can be found).
  build_deps = []

  #FIXME: async is a hack to deal with the situation where the target
  #depends on local async_kernel but a dep depends on opam asyn.
  async = False

  cclib_deps = []

  includes   = []

  if ctx.attr.ns:
      ## FIXME: make user reponsible for these args?
      # args.add("-w", "-49") # ignore Warning 49: no cmi file was found in path for module x
      # args.add("-no-alias-deps")
      # args.add("-opaque")
      ns_cm = ctx.attr.ns[OcamlNsModuleProvider].payload.cm
      ns_mod = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
      args.add("-open", ns_mod)

  # later we will add opam deps to CL using -package
  opam_deps = []
  nopam_deps = []

  # for datum in ctx.attr.data:
  #     dep_graph.extend(datum.files.to_list())

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
            # args.add("-I", ctx.file.cmi.dirname)
        includes.append(provider.payload.cmi.dirname)
        includes.append(provider.payload.mli.dirname)
        # cmi inputs have deps too!
        for dep in provider.deps.nopam.to_list():
            # if debug:
            #     print("XXXXXXXXXXXXXXXX: %s" % dep)
            if dep.extension == "cmx":
                # build_deps.append(dep)
                includes.append(dep.dirname)
            elif dep.extension == "cmi":
                dep_graph.append(dep)
                includes.append(dep.dirname)
            elif dep.extension == "mli":
                dep_graph.append(dep)
                includes.append(dep.dirname)

  # args.add("-I", obj_cmx.dirname)
  includes.append(obj_cmx.dirname)

  # nopam deps must be added to dep_graph, but need not be added to CL?
  for dep in mydeps.nopam.to_list():
      # if debug:
      #     print("\nNOPAM DEP: %s\n\n" % dep)
      if dep.extension == "mli":
          dep_graph.append(dep)
          includes.append(dep.dirname)
      elif dep.extension == "cmi":
          dep_graph.append(dep)
          ## THIS IS THE CRITICAL BIT for compiling! The compiler must be able to find the cmi files.
          includes.append(dep.dirname)
          ## cmi ignored if mli not present!
      elif dep.extension == "cmx":
          dep_graph.append(dep)
          # Just to make sure (cmx and cmi should be in same dir?)
          includes.append(dep.dirname)
          # We do not need to list cmx files, the compiler will find them in the search path.
      elif dep.extension == "o":
          dep_graph.append(dep)
          includes.append(dep.dirname)
      elif dep.extension == "cmxa":
          build_deps.append(dep)
          dep_graph.append(dep)
          includes.append(dep.dirname)
          ## we need the dir on the search path, so the subcomponents can be found.
          ## alternatively, we can add each subcomponent cmx to the command line
          ## cc deps
      elif dep.extension == "a":
          dep_graph.append(dep)
          args.add(dep)
      elif dep.extension == "lo":
        if debug:
            print("NOPAM .lo DEP: %s" % dep)
            dep_graph.append(dep)
            args.add("-ccopt", "-l" + dep.path)
      elif dep.extension == "so":
          if debug:
              print("ADDING DSO FILE: %s" % dep)
              libname = dep.basename[:-3]
              libname = libname[3:]
              args.add("-ccopt", "-L" + dep.dirname)
              args.add("-cclib", "-l" + libname)
              cclib_deps.append(dep)
      elif dep.extension == "dylib":
          if debug:
              print("ADDING DYLIB: %s" % dep)
              libname = dep.basename[:-6]
              libname = libname[3:]
              args.add("-ccopt", "-L" + dep.dirname)
              args.add("-cclib", "-l" + libname)
              includes.append(dep.dirname)
              cclib_deps.append(dep)
      elif dep.extension == ".cmxs":
          includes.append(dep.dirname)

  ## lazy deps: we're compiling a module, so make them eager
  ## NO: only use lazy deps from ppx to compile this module,
  ## the lazy deps in the deps tree are propagated.
  ## which should only happen for ppx_* rules.
  ## i.e. if an ocaml_module depends on a ppx lib, then it too is a ppx lib.
  ## FIXME: do not allow ocaml_modules to depend on ppx_*?

  # for dep in mydeps.nopam_lazy.to_list():
  #     ## get provider from dep: module? archive?
  #     print("NOPAM LAZY DEP: %s" % dep)
  #     if dep.extension == "cmx":
  #         # includes.append(dep.dirname)
  #         dep_graph.append(dep)
  #         args.add(dep)
  #     elif dep.extension == "cmxa":
  #         includes.append(dep.dirname)
  #         dep_graph.append(dep)
  #     elif dep.extension == "o":
  #         # includes.append(dep.dirname)
  #         dep_graph.append(dep)
  #     elif dep.extension == "cmi":
  #         # includes.append(dep.dirname)
  #         dep_graph.append(dep)
  #     elif dep.extension == "mli":
  #         # includes.append(dep.dirname)
  #         dep_graph.append(dep)

      # if OcamlModuleProvider in dep:
      #     print("NOPAM LAZY OcamlModuleProvider DEP: %s" % dep)
      # elif OcamlArchiveProvider in dep:
      #     print("NOPAM LAZY DEP: %s" % dep[OcamlArchiveProvider])
      # elif PpxModuleProvider in dep:
      #     print("NOPAM LAZY DEP: %s" % dep[PpxModuleProvider])
      # elif PpxArchiveProvider in dep:
      #     print("NOPAM LAZY DEP: %s" % dep[PpxArchiveProvider])


  ####  TODO:  transitive cc_deps
  for dep in ctx.attr.cc_deps.items():
    if debug:
        print("CCLIB DEP: ")
        print(dep)
    if dep[1] == "static":
        if debug:
            print("STATIC lib: %s:" % dep[0])
        for depfile in dep[0].files.to_list():
            if (depfile.extension == "a"):
                cclib_deps.append(depfile)
                args.add(depfile)
                includes.append(depfile.dirname)
    elif dep[1] == "dynamic":
        if debug:
            print("DYNAMIC lib: %s" % dep[0])
        for depfile in dep[0].files.to_list():
            print("DEPFILE extension: %s" % depfile.extension)
            if (depfile.extension == "so"):
                libname = depfile.basename[:-3]
                libname = libname[3:]
                print("SOLIBNAME: %s" % depfile.basename)
                print("SO PARAM: -l%s" % libname)
                args.add("-cclib", "-l" + libname)
                cclib_deps.append(depfile)
            elif (depfile.extension == "dylib"):
                libname = depfile.basename[:-6]
                libname = libname[3:]
                print("DYLIBNAME: %s:" % libname)
                args.add("-cclib", "-l" + libname)
                includes.append(depfile.dirname)
                cclib_deps.append(depfile)

    # for depfile in dep[0].files.to_list():
    #   # print("CCLIB DEP FILE: %s" % depfile)
    #   # print("CCLIB DEP FILE extension: %s" % depfile.extension)

    #   ##FIXME:  if linkstatic
    #   ## -dllib is for bytecode only
    #   # if depfile.extension == "a":
    #   elif depfile.extension == "lo":
    #     libname = depfile.basename.rstrip("o")
    #     libname = libname.rstrip("l")
    #     libname = libname.rstrip(".")
    #     libname = libname.lstrip("lib")
    #     args.add("-cclib", "-l" + libname)
    #     cclib_deps.append(depfile)
    #   elif depfile.extension == "dylib":
    #     libname = depfile.basename.rstrip("dylib")
    #     libname = libname.lstrip("lib")
    #     args.add("-cclib", "-l" + libname)
    #     cclib_deps.append(depfile)
    #   elif depfile.extension == "so":
    #     ## starlark's rstrip function does not strip suffix strings, only char classes.
    #     ## rstrip(".so") would take snarky_stubs.so to snarky_stub
    #     ## so we have to hack it:
    #     libname = depfile.basename.rstrip("o")
    #     libname = libname.rstrip("s")
    #     libname = libname.rstrip(".")
    #     libname = libname.lstrip("lib")
    #     args.add("-cclib", "-l" + libname)
    #     cclib_deps.append(depfile)

  # if ctx.attr.cc_opts != None:
  args.add_all(ctx.attr.cc_opts, before_each="-ccopt")

  args.add_all(includes, before_each="-I", uniquify = True)

  for dep in mydeps.opam.to_list():
      for x in dep.pkg.to_list():
          opam_deps.append(x.name)

  ## lazy deps in the dep graph are NOT compile deps of this module.
  ## only the lazy deps of the ppx are.
  # for dep in mydeps.opam_lazy.to_list():
  #     opam_deps.append(dep.pkg.to_list()[0].name)

  if len(opam_deps) > 0:
      args.add("-linkpkg") # adds OPAM cmxa files to command
      for dep in opam_deps:
          args.add("-package", dep) # adds directories of OPAM files to search path using -I
          # if not dep.ppx_driver:
          #     if dep.pkg.to_list()[0].name == "async":
          #         if async:
          #             args.add("-package", dep.pkg.to_list()[0].name)
          #         else:
          #             args.add("-package", dep.pkg.to_list()[0].name)

  if ctx.attr.ppx:
      ## add lazy_deps from ppx provider
      ppx_provider = ctx.attr.ppx[PpxExecutableProvider]
      if debug:
          print("PPX Provider: %s" % ppx_provider)
      for dep in ppx_provider.deps.opam_lazy.to_list():
          if debug:
              print("OPAM lazy dep: %s" % dep)
          args.add("-package", dep.pkg.to_list()[0].name)
      for dep in ppx_provider.deps.nopam_lazy.to_list():
          if debug:
              print("NOPAM lazy dep: %s" % dep)
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

  args.add_all(build_deps)
  # args.add_all(cclib_deps)

  # according the the User Manual, -o is for executables and archives, not modules?
  args.add("-o", obj_cmx)

  if ctx.attr.intf:
    if ctx.file.intf.extension == "mli":
        args.add(ctx.file.intf.path)
        # args.add(xsrc)
  args.add("-impl", xsrc)

  # dep_graph = dep_graph + build_deps + cclib_deps + [xsrc] #  [ctx.file.src]  # ctx.files.src
  dep_graph.extend(build_deps)
  dep_graph.extend(cclib_deps)
  dep_graph.append(xsrc)

  # if ctx.attr.ns:
  #   dep_graph.append(ctx.attr.ns[OcamlNsModuleProvider].payload.cm)

  # print("DEP_GRAPH:")
  # print(dep_graph)

  # cwd = paths.dirname(ctx.build_file_path)
  # print("CWD: %s" % cwd)

  outputs.append(obj_cmx)
  outputs.append(obj_o)

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

  if debug:
      print("\n\t\t================ INPUTS (DEP_GRAPH) ================\n\n")
      for dep in dep_graph:
          print("\nINPUT: %s\n\n" % dep)

  if debug:
      print("\n\t\t================ OUTPUTS ================\n\n")
      for dep in outputs:
          print("\nOUTPUT: %s\n\n" % dep)

  ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args],
      inputs = dep_graph,
      outputs = outputs,
      tools = [tc.ocamlfind, tc.ocamlopt],
      mnemonic = "CompileModuleAction",
      progress_message = "Action compile_module: {rule}({tgt}){msg}".format(
          rule=rule,
          tgt=ctx.label.name,
          msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
      )
  )

  return struct(
      cmi = obj_cmi,  # ctx.file.intf if ctx.file.intf else None,
      mli = dep_mli,
      cm  = obj_cmx,
      cmt = obj_cmt,
      o   = obj_o,
      opam = mydeps.opam,
      nopam = mydeps.nopam
  )

