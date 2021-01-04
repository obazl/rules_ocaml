load("//ocaml/_providers:ocaml.bzl", "CompilationModeSettingProvider")
load("//ocaml/_providers:ocaml.bzl",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider",
     "OcamlSDK")
load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")
load("//ppx:_providers.bzl", "PpxArchiveProvider")

load("//ocaml/_deps:archive_deps.bzl", "get_archive_deps")
load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "file_to_lib_name",
     "strip_ml_extension",
     "split_srcs",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

##################################################
######## RULE DECL:  OCAML_LIBRARY  #########
#  Build .cmxa, .a
##################################################
def _ocaml_library_impl(ctx):

  debug = False
  # if (ctx.label.name == "zexe_backend_common"):
  #     debug = True

  if debug:
      print("ARCHIVE TARGET: %s" % ctx.label.name)

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  mydeps = get_all_deps("ocaml_library", ctx)
  # mydeps = get_archive_deps("ocaml_library", ctx)
  if debug:
      print("ALL DEPS for target %s" % ctx.label.name)
      print(mydeps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  # lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  mode = ctx.attr._mode[CompilationModeSettingProvider].value

  ## declare outputs
  # tmpdir = "_obazl_/"
  # obj_files = []
  # obj_cm_a = None
  # obj_cmxs = None
  # obj_a    = None
  # if ctx.attr.archive_name:
  #   if ctx.attr.linkshared:
  #     obj_cmxs = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".cmxs")
  #   else:
  #     obj_cm_a = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + tc.archext)
  #     if mode == "native":
  #         obj_a = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".a")
  # else:
  #   if ctx.attr.linkshared:
  #     obj_cmxs = ctx.actions.declare_file(tmpdir + ctx.label.name + ".cmxs")
  #   else:
  #     obj_cm_a = ctx.actions.declare_file(tmpdir + ctx.label.name + tc.archext)
  #     if mode == "native":
  #         obj_a = ctx.actions.declare_file(tmpdir + ctx.label.name + ".a")

  build_deps = []  # for the command line
  includes = []
  dep_graph = []  # for the run action inputs

  ################################################################
  # args = ctx.actions.args()
  # # args.add(tc.compiler.basename)
  # if mode == "native":
  #     args.add(tc.ocamlopt.basename)
  # else:
  #     args.add(tc.ocamlc.basename)

  # # args.add("-w", ctx.attr.warnings)
  # options = tc.opts + ctx.attr.opts
  # # if ctx.attr.nocopts:
  # args.add_all(options)
  # if ctx.attr.alwayslink:
  #   args.add("-linkall")

  # args.add_all(ctx.attr.cc_linkopts, before_each="-ccopt")
  # # if len(ctx.addr.cc_linkall) > 0:
  # #     for cc_dep in ctx.files.linkall:


  ## We also need to add the .o files as outputs. Why? Because -
  ## assuming we use lazy linking - a change to a source file that
  ## does not affect an interface will not result in a change to the
  ## cm_a file, so downstream targets that depend only on cm_a will
  ## not rebuilt. So we need the dependency to be on both the cm_a and
  ## the associated object files.

  # currently we do not support direct dep on source files
  # for src in ctx.files.srcs:
  #   if src.path.endswith(".ml"):
  #     obj_files.append(ctx.actions.declare_file(src.basename.rstrip(".ml") + ".o"))

    # elif src is archive:
    #   emit archive unchanged

  # print("OBJ_FILES")
  # print(obj_files)

  # if hasattr(ctx.attr, "cc_linkall"):
  #     if debug:
  #         print("DEPSET CC_LINKALL: %s" % ctx.attr.cc_linkall)
  #     for cc_dep in ctx.files.cc_linkall:
  #         if cc_dep.extension == "a":
  #             dep_graph.append(cc_dep)
  #             path = cc_dep.path
  #             # if tc.os == "macos":
  #             args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))
  #             # elif tc.os == "linux":
  #             # "-Wl,--push-state,-whole-archive",
  #             # "-lrocksdb",
  #             # "-Wl,--pop-state",


  # # args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")
  # if len(mydeps.opam.to_list()) > 0:
  #     ## DO NOT USE -linkpkg, it puts .cmxa files on command, yielding
  #     ## `Option -a cannot be used with .cmxa input files.`
  #     args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  # # for dep in mydeps.nopam.to_list():
  # #   print("NOPAM DEP: %s" % dep)

  # cc_deps   = []
  # link_search  = []

  # # for dep in ctx.files.deps:
  # #     if dep.extension == "cmx":
  # #         includes.append(dep.dirname)
  # #         dep_graph.append(dep)
  # #         build_deps.append(dep)

  # for dep in mydeps.nopam.to_list():
  #   if debug:
  #         print("\nNOPAM DEP: %s\n\n" % dep)
  #   if dep.extension == "cmxa":
  #       ## We ignore cmxa deps, since "Option -a cannot be used with .cmxa input files."
  #       ## But the depgraph contains everything contained in the cmxa, so we're covered.
  #       dep_graph.append(dep)
  #   ## mode == bytecode
  #   elif dep.extension == "cma":
  #       ## We ignore cma deps, since "Option -a cannot be used with .cmxa input files."
  #       ## But the depgraph contains everything contained in the cmxa, so we're covered.
  #       dep_graph.append(dep)
  #   elif dep.extension == "cmx":
  #       ## This will include cmx that are direct deps of cmxa files.
  #       includes.append(dep.dirname)
  #       dep_graph.append(dep)
  #       build_deps.append(dep)
  #   ## mode == bytecode
  #   elif dep.extension == "cmo":
  #       ## This will include cmo that are direct deps of cmxa files.
  #       includes.append(dep.dirname)
  #       dep_graph.append(dep)
  #       build_deps.append(dep)
  #   elif dep.extension == "cmi":
  #       dep_graph.append(dep)
  #       includes.append(dep.dirname)
  #   elif dep.extension == "mli":
  #       dep_graph.append(dep)
  #       includes.append(dep.dirname)
  #   elif dep.extension == "o":
  #       # build_deps.append(dep)
  #       dep_graph.append(dep)
  #       includes.append(dep.dirname)
  #   elif dep.extension == "so":
  #       if debug:
  #           print("NOPAM .so DEP: %s" % dep)
  #       dep_graph.append(dep)
  #       link_search.append("-L" + dep.dirname)
  #       libname = file_to_lib_name(dep)
  #       cc_deps.append("-l" + libname)
  #       # args.add("-ccopt", "-L" + dep.dirname)
  #       # args.add("-cclib", "-l" + libname)
  #   elif dep.extension == "dylib":
  #       if debug:
  #           print("NOPAM .dylib DEP: %s" % dep)
  #       dep_graph.append(dep)
  #       link_search.append("-L" + dep.dirname)
  #       libname = file_to_lib_name(dep)
  #       cc_deps.append("-l" + libname)
  #       # args.add("-ccopt", "-L" + dep.dirname)
  #       # args.add("-cclib", "-l" + libname)
  #       # includes.append(dep.dirname)
  #   elif dep.extension == "a":
  #       dep_graph.append(dep)
  #       build_deps.append(dep)
  #   else:
  #       if debug:
  #           print("NOMAP DEP not .cmx, cmxa, cmo, cma, .o, .lo, .so, .dylib: %s" % dep.path)

  # args.add_all(link_search, before_each="-ccopt", uniquify = True)
  # args.add_all(cc_deps, before_each="-cclib", uniquify = True)

  # args.add_all(includes, before_each="-I", uniquify = True)

  # WARNING: including this causes search for mli file for intf, which fails
  # if len(ctx.files.srcs) > 1:
  #     args.add("-intf-suffix", ".ml")

  # args.add("-no-alias-deps")
  # args.add("-opaque")

  ## IMPORTANT!  from the ocamlopt docs:
  ## -o exec-file   Specify the name of the output file produced by the linker.
  ## That covers both executables and library archives (-a).
  ## If you're just compiling (-c), no need to pass -o.
  ## By contrast, the output files must be listed in the action output arg
  ## in order to be registered in the action dependency graph.

  ## finally, pass the input source file:
  # if len(ctx.files.srcs) > 1:
  #     for s in ctx.files.srcs:
  #         args.add(s)
  # else:
  # args.add("-impl", src_file)

  ## since we're building an archive, we need all members on command line
  # args.add_all(build_deps)
  # args.add_all(ctx.files.srcs)

  # if ctx.attr.linkshared:
  #   args.add("-shared")
  #   args.add("-o", obj_cmxs)
  #   obj_files.append(obj_cmxs)
  # else:
  #   if mode == "native":
  #       obj_files.append(obj_a)
  #   obj_files.append(obj_cm_a)
  #   args.add("-a")
  #   args.add("-o", obj_cm_a)


  # dep_graph = dep_graph + build_deps
  # if debug:
  #     print("INPUT_ARGS: ")
      # print(dep_graph)

  # ctx.actions.run(
  #     env = env,
  #     executable = tc.ocamlfind,
  #     arguments = [args],
  #     inputs = dep_graph,
  #     outputs = obj_files,
  #     tools = [tc.ocamlfind, tc.ocamlopt],
  #     mnemonic = "OcamlArchive",
  #     progress_message = "compiling ocaml_library: @{ws}//{pkg}:{tgt}{msg}".format(
  #         ws  = ctx.label.workspace_name,
  #         pkg = ctx.label.package,
  #         tgt=ctx.label.name,
  #         msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
  #     )
  #   # progress_message = "ocaml_library({}): {}".format(
  #   #     ctx.label.name, ctx.attr.msg
  #   #   )
  # )

  ctx.actions.do_nothing(
      mnemonic = "OcamlLibrary",
      inputs = mydeps.nopam.to_list()
  )

  # if mode == "native":
  #     payload = struct(
  #         library = ctx.label.name,
  #         # cm_a = obj_cm_a,
  #         # cmxs = obj_cmxs,
  #         # a    = obj_a,
  #         # modules = build_deps + cc_deps
  #     )
  # else:
  #     payload = struct(
  #         library = ctx.label.name,
  #         # cm_a = obj_cm_a,
  #         # cmxs = obj_cmxs,
  #     )

  libraryProvider = OcamlLibraryProvider(
      # payload = payload,
      deps = struct(
          opam = mydeps.opam,
          nopam = mydeps.nopam
      )
  )

  # print("LIBRARYPROVIDER for {arch}: {ap}".format(arch=ctx.label.name, ap=libraryProvider))
  return [
    DefaultInfo(
      files = depset(
          order = "postorder",
          direct = ctx.files.deps
        # transitive = [depset(build_deps + cc_deps)]
      )),
    libraryProvider,
  ]

################################################################
ocaml_library = rule(
    doc = """Generates an OCaml library file (.cmxa or .cma) and a C library file (.a).""",
    implementation = _ocaml_library_impl,
    attrs = dict(
       _sdkpath = attr.label( ## FIXME: delete?
            default = Label("@ocaml//:path")
        ),
        lib_name = attr.string(),
        doc = attr.string(),
        ## FIXME: remove opts
        opts                    = attr.string_list(),
        ## FIXME: 'srcs' instead of 'deps'
        srcs = attr.label_list(
            providers = [[OpamPkgInfo],
                         [OcamlImportProvider],
                         [OcamlInterfaceProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsModuleProvider],
                         [OcamlArchiveProvider],
                         [PpxArchiveProvider]],
        ),
        deps = attr.label_list(
            providers = [[OpamPkgInfo],
                         [OcamlImportProvider],
                         [OcamlInterfaceProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsModuleProvider],
                         [OcamlArchiveProvider],
                         [PpxArchiveProvider]],
        ),
        cc_deps = attr.label_keyed_string_dict(
            doc = "Target labels of hermetic (bazelized) C/C++ library dependencies.",
            providers = [[CcInfo]]
        ),
        cc_linkopts = attr.string_list(
            doc = "Non-hermetic C/C++ options, e.g. -lopenssl",
        ),
        cc_linkall = attr.label_list(
            doc     = "List of libs using -whole-archive (GCC toolchain) or -force_load (Clang toolchain)",
            providers = [CcInfo],
        ),
        # cc_linkstatic = attr.bool(
        #     doc     = "Control linkage of C/C++ dependencies. True: link to .a file; False: link to shared object file (.so or .dylib)",
        #     default = True # False
        # ),
        _mode = attr.label(  ## FIXME: not needed?
            default = "@ocaml//mode"
        ),
        msg = attr.string(),
    ),
    provides = [OcamlLibraryProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
