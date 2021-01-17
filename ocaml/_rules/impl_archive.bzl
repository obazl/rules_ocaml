load("@bazel_skylib//rules:common_settings.bzl",
     "BuildSettingInfo")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlArchivePayload",
     "OcamlArchiveProvider",
     "OcamlDepsetProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider")

load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxDepsetProvider")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name"
)

load("//ocaml/_rules:options_ocaml.bzl", "options_ocaml")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

##################################################
# def impl_archive(rule, ctx, mode, mydeps):
def impl_archive(ctx):

  debug = False
  # if (ctx.label.name == "zexe_backend_common"):
  #     debug = True

  if debug:
      print("ARCHIVE TARGET: %s" % ctx.label.name)

  if ctx.attr._rule == "ppx_module":
      mode = ctx.attr._mode[0]
  else:
      mode = ctx.attr._mode[CompilationModeSettingProvider].value

  mydeps = get_all_deps(ctx.attr._rule, ctx)

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  if debug:
      print("ALL DEPS for target %s" % ctx.label.name)
      print(mydeps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  ext  = ".cmxa" if  mode == "native" else ".cma"

  if ctx.attr._rule == "ppx_archive":
      ## -linkpkg is an ocamlfind parameter
      if "-linkpkg" in ctx.attr.opts:
          fail("-linkpkg option not supported for ppx_archive rule")

  ## declare outputs
  tmpdir = "_obazl_/"
  obj_files = []
  obj_cm_a = None
  obj_a    = None
  if ctx.attr.archive_name:
    obj_cm_a = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ext)
    if mode == "native":
        obj_a = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".a")
  else:
    obj_cm_a = ctx.actions.declare_file(tmpdir + ctx.label.name + ext)
    if mode == "native":
        obj_a = ctx.actions.declare_file(tmpdir + ctx.label.name + ".a")

  build_deps = []  # for the command line
  includes = []
  dep_graph = []  # for the run action inputs

  ################################################################
  args = ctx.actions.args()

  if mode == "native":
      args.add(tc.ocamlopt.basename)
  else:
      args.add(tc.ocamlc.basename)

  cc_linkmode = tc.linkmode            # used below to determine dep linkmode
  if ctx.attr._cc_linkmode:
      if ctx.attr._cc_linkmode[BuildSettingInfo].value == "static": # override toolchain default?
          cc_linkmode = "static"
          if mode == "bytecode":
              args.add("-custom")

  configurable_defaults = get_options(ctx.attr._rule, ctx)
  args.add_all(configurable_defaults)

  args.add_all(ctx.attr.cc_linkopts, before_each="-ccopt")

  for (dep, linkmode) in ctx.attr.cc_deps.items():
      # print("CC_DEP: {dep} mode: {m}".format(dep = dep, m = linkmode))
      if linkmode == "static-linkall":
          # if debug:
          # print("CC_DEP STATIC_LINKALL: %s" % dep) # ctx.attr.cc_linkall)
          for f in dep.files.to_list():
              if f.extension == "a":
                  dep_graph.append(f)
                  path = f.path # relative to execution root
                  # if tc.os == "macos". path can be relative
                  args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))

          # for cc_dep in ctx.files.cc_linkall:
          #     if cc_dep.extension == "a":
          #         dep_graph.append(cc_dep)
          #         path = cc_dep.path
          #         # if tc.os == "macos". path can be relative
          #         args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))
                  # elif tc.os == "linux":
                  # "-Wl,--push-state,-whole-archive",
                  # "-lrocksdb",
                  # "-Wl,--pop-state",

  ## Do we need opam deps for an archive? Will -linkall take care of this?
  # if len(mydeps.opam.to_list()) > 0:
  #     ## DO NOT USE -linkpkg, it puts .cmxa files on command, yielding
  #     ## `Option -a cannot be used with .cmxa input files.`
  #     args.add_all([dep.pkg.name for dep in mydeps.opam.to_list()], before_each="-package")

  # for dep in mydeps.nopam.to_list():
  #   print("NOPAM DEP: %s" % dep)

  cc_deps   = []
  link_search  = []

  for dep in mydeps.nopam.to_list():
    if debug:
          print("\nNOPAM DEP: %s\n\n" % dep)
    ## We ignore cma and cmxa deps, since "Option -a cannot be used with .cmxa/.cma input files."
    ## But the depgraph contains everything contained in the archive, so we're covered.
    if dep.extension == "cmxa":
        dep_graph.append(dep)
    elif dep.extension == "cma":
        dep_graph.append(dep)

    ## we include the object file deps instead
    elif dep.extension == "cmx":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.extension == "cmo":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.extension == "o":
        dep_graph.append(dep)
        includes.append(dep.dirname)
        # build_deps.append(dep)

    ## and interface files
    elif dep.extension == "cmi":
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "mli":
        dep_graph.append(dep)
        includes.append(dep.dirname)

    ## cc deps
    elif dep.extension == "a":
        if cc_linkmode == "static":
            dep_graph.append(dep)
            build_deps.append(dep)
    elif dep.extension == "so":
        dep_graph.append(dep)
        if debug:
            print("NOPAM .so DEP: %s" % dep)
        if cc_linkmode == "dynamic":
            libname = file_to_lib_name(dep)
        if mode == "native":
            link_search.append("-L" + dep.dirname)
            cc_deps.append("-l" + libname)
        else:
            link_search.append(dep.dirname)
            cc_deps.append("-l" + libname)
    elif dep.extension == "dylib":
        if debug:
            print("NOPAM .dylib DEP: %s" % dep)
        if cc_linkmode == "dynamic":
            dep_graph.append(dep)
            libname = file_to_lib_name(dep)
            if mode == "native":
                link_search.append("-L" + dep.dirname)
                cc_deps.append("-l" + libname)
            else:
                link_search.append(dep.dirname)
                cc_deps.append(libname)
    else:
        if debug:
            print("NOMAP DEP not .cmx, cmxa, cmo, cma, .o, .lo, .so, .dylib: %s" % dep.path)

  args.add_all(link_search, before_each="-ccopt", uniquify = True)
  if mode == "native":
      args.add_all(cc_deps, before_each="-cclib", uniquify = True)
  else:
      args.add_all(link_search, before_each="-dllpath", uniquify = True)
      args.add_all(cc_deps, before_each="-dllib", uniquify = True)

  args.add_all(includes, before_each="-I", uniquify = True)

  ## IMPORTANT!  from the ocamlopt docs:
  ## -o exec-file   Specify the name of the output file produced by the linker.
  ## That covers both executables and library archives (-a).
  ## If you're just compiling (-c), no need to pass -o.
  ## By contrast, the output files must be listed in the action output arg
  ## in order to be registered in the action dependency graph.

  ## since we're building an archive, we need all members on command line
  args.add_all(build_deps)

  if mode == "native":
      obj_files.append(obj_a)

  obj_files.append(obj_cm_a)

  args.add("-a")
  args.add("-o", obj_cm_a)

  dep_graph = dep_graph + build_deps
  if debug:
      print("INPUT_ARGS: ")
      print(dep_graph)

  ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args],
      inputs = dep_graph,
      outputs = obj_files,
      tools = [tc.ocamlfind, tc.ocamlopt],
      mnemonic = "OcamlArchive",
      progress_message = "{mode} compiling ocaml_archive: @{ws}//{pkg}:{tgt}".format(
          mode = mode,
          ws  = ctx.label.workspace_name,
          pkg = ctx.label.package,
          tgt=ctx.label.name,
          # msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
      )
  )

  if ctx.attr._rule == "ocaml_archive":
      if mode == "native":
          payload = OcamlArchivePayload(
              archive = ctx.label.name,
              cmxa = obj_cm_a, # result.cmxa,
              a    = obj_a     #result.a,
          )
          directs = [obj_cm_a, obj_a]
          # directs = [result.cmxa, result.a]
      else:
          payload = OcamlArchivePayload(
              archive = ctx.label.name,
              cma     = obj_cm_a  ## result.cma
          )
          directs = [obj_cm_a]  ## result.cma]

      archiveProvider = OcamlArchiveProvider(
          payload = payload,
          deps = OcamlDepsetProvider(
              opam = mydeps.opam,
              nopam = mydeps.nopam
          )
      )
  elif ctx.attr._rule == "ppx_archive":
      if mode == "native":
          payload = OcamlArchivePayload(
              archive = ctx.label.name,
              cmxa    = obj_cm_a, ## result.cmxa, ## obj["cmxa"] if "cmxa" in obj else None,
              a       = obj_a     ## result.a     ## obj["a"] if "a" in obj else None
          )
          directs = [obj_cm_a, obj_a]  ## result.cmxa, result.a]
      else:
          payload = OcamlArchivePayload(
              archive = ctx.label.name,
              cma     = obj_cm_a   ## result.cma,  ## obj["cm_a"] if "cm_a" in obj else None,
          )
          directs = [obj_cm_a]  ## result.cma]

      archiveProvider = PpxArchiveProvider(
          payload = payload,
          deps = PpxDepsetProvider(
              opam  = mydeps.opam,
              opam_adjunct = mydeps.opam_adjunct,
              nopam = mydeps.nopam,
              nopam_adjunct = mydeps.nopam_adjunct
          )
      )

  return [
    DefaultInfo(
      files = depset(
          order = "postorder", # "preorder",
          direct = directs
        # transitive = [depset(build_deps + cc_deps)]
      )
    ),
    archiveProvider,
  ]


  # if mode == "native":
  #     return struct(
  #         cmxa  = obj_cm_a,
  #         a    = obj_a,
  #         opam = mydeps.opam,
  #         nopam = mydeps.nopam
  #     )
  # else:
  #     return struct(
  #         cma  = obj_cm_a,
  #         opam = mydeps.opam,
  #         nopam = mydeps.nopam
  #     )

  # if mode == "native":
  #     payload = OcamlArchivePayload(
  #         archive = ctx.label.name,
  #         cma = obj_cm_a,
  #         a    = obj_a,
  #         # modules = build_deps + cc_deps
  #     )
  # else:
  #     payload = OcamlArchivePayload(
  #         archive = ctx.label.name,
  #         cma = obj_cm_a,
  #     )

  # archiveProvider = OcamlArchiveProvider(
  #     payload = payload,
  #     deps = OcamlDepsetProvider(
  #         opam = mydeps.opam,
  #         nopam = mydeps.nopam
  #     )
  # )

  # # print("ARCHIVEPROVIDER for {arch}: {ap}".format(arch=ctx.label.name, ap=archiveProvider))
  # return [
  #   DefaultInfo(
  #     files = depset(
  #         order = "preorder",
  #         direct = obj_files,
  #       # transitive = [depset(build_deps + cc_deps)]
  #     )),
  #   archiveProvider,
  # ]
