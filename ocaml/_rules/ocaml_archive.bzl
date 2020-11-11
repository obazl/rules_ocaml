load("//ocaml/_providers:ocaml.bzl",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider",
     "OcamlSDK")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_providers:ppx.bzl", "PpxArchiveProvider")

load("//ocaml/_deps:archive_deps.bzl", "get_archive_deps")
load("//ocaml/_utils:deps.bzl", "get_all_deps")

load("//implementation:utils.bzl",
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
######## RULE DECL:  OCAML_ARCHIVE  #########
#  Build .cmxa, .a
##################################################
def _ocaml_archive_impl(ctx):

  debug = False
  # if (ctx.label.name == "zexe_backend_common"):
  #     debug = True

  if debug:
      print("ARCHIVE TARGET: %s" % ctx.label.name)

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  mydeps = get_all_deps("ocaml_archive", ctx)
  # mydeps = get_archive_deps("ocaml_archive", ctx)
  if debug:
      print("ALL DEPS for target %s" % ctx.label.name)
      print(mydeps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  ## declare outputs
  tmpdir = "_obazl_/"
  obj_files = []
  obj_cmxa = None
  obj_cmxs = None
  obj_a    = None
  if ctx.attr.archive_name:
    if ctx.attr.linkshared:
      obj_cmxs = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".cmxs")
    else:
      obj_cmxa = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".cmxa")
      obj_a = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".a")
  else:
    if ctx.attr.linkshared:
      obj_cmxs = ctx.actions.declare_file(tmpdir + ctx.label.name + ".cmxs")
    else:
      obj_cmxa = ctx.actions.declare_file(tmpdir + ctx.label.name + ".cmxa")
      obj_a = ctx.actions.declare_file(tmpdir + ctx.label.name + ".a")

  build_deps = []  # for the command line
  includes = []
  dep_graph = []  # for the run action inputs

  ################################################################
  args = ctx.actions.args()
  args.add(tc.compiler.basename)
  # args.add("-w", ctx.attr.warnings)
  options = tc.opts + ctx.attr.opts
  # if ctx.attr.nocopts:
  args.add_all(options)
  if ctx.attr.alwayslink:
    args.add("-linkall")

  args.add_all(ctx.attr.cc_linkopts, before_each="-ccopt")
  # if len(ctx.addr.cc_linkall) > 0:
  #     for cc_dep in ctx.files.linkall:


  if ctx.attr.linkshared:
    args.add("-shared")
    args.add("-o", obj_cmxs)
    obj_files.append(obj_cmxs)
  else:
    args.add("-a")
    args.add("-o", obj_cmxa)
    obj_files.append(obj_cmxa)
    obj_files.append(obj_a)

  ## We also need to add the .o files as outputs. Why? Because -
  ## assuming we use lazy linking - a change to a source file that
  ## does not affect an interface will not result in a change to the
  ## cmxa file, so downstream targets that depend only on cmxa will
  ## not rebuilt. So we need the dependency to be on both the cmxa and
  ## the associated object files.

  # currently we do not support direct dep on source files
  # for src in ctx.files.srcs:
  #   if src.path.endswith(".ml"):
  #     obj_files.append(ctx.actions.declare_file(src.basename.rstrip(".ml") + ".o"))

    # elif src is archive:
    #   emit archive unchanged

  # print("OBJ_FILES")
  # print(obj_files)

  if hasattr(ctx.attr, "cc_linkall"):
      if debug:
          print("DEPSET CC_LINKALL: %s" % ctx.attr.cc_linkall)
      for cc_dep in ctx.files.cc_linkall:
          if cc_dep.extension == "a":
              dep_graph.append(cc_dep)
              path = cc_dep.path
              # if tc.os == "macos":
              args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))
              # elif tc.os == "linux":
              # "-Wl,--push-state,-whole-archive",
              # "-lrocksdb",
              # "-Wl,--pop-state",


  # args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")
  if len(mydeps.opam.to_list()) > 0:
      ## DO NOT USE -linkpkg, it puts .cmxa files on command, yielding
      ## `Option -a cannot be used with .cmxa input files.`
      args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  # for dep in mydeps.nopam.to_list():
  #   print("NOPAM DEP: %s" % dep)

  cc_deps   = []
  link_search  = []

  # for dep in ctx.files.deps:
  #     if dep.extension == "cmx":
  #         includes.append(dep.dirname)
  #         dep_graph.append(dep)
  #         build_deps.append(dep)

  for dep in mydeps.nopam.to_list():
    if debug:
          print("\nNOPAM DEP: %s\n\n" % dep)
    if dep.extension == "cmxa":
        ## We ignore cmxa deps, since "Option -a cannot be used with .cmxa input files."
        ## But the depgraph contains everything contained in the cmxa, so we're covered.
        dep_graph.append(dep)
    elif dep.extension == "cmx":
        ## This will include cmx that are direct deps of cmxa files.
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.extension == "cmi":
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "mli":
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "o":
        # build_deps.append(dep)
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "so":
        if debug:
            print("NOPAM .so DEP: %s" % dep)
        dep_graph.append(dep)
        link_search.append("-L" + dep.dirname)
        libname = file_to_lib_name(dep)
        cc_deps.append("-l" + libname)
        # args.add("-ccopt", "-L" + dep.dirname)
        # args.add("-cclib", "-l" + libname)
    elif dep.extension == "dylib":
        if debug:
            print("NOPAM .dylib DEP: %s" % dep)
        dep_graph.append(dep)
        link_search.append("-L" + dep.dirname)
        libname = file_to_lib_name(dep)
        cc_deps.append("-l" + libname)
        # args.add("-ccopt", "-L" + dep.dirname)
        # args.add("-cclib", "-l" + libname)
        # includes.append(dep.dirname)
    elif dep.extension == "a":
        dep_graph.append(dep)
        build_deps.append(dep)
    else:
        if debug:
            print("NOMAP DEP not .cmx, ,cmxa, .o, .lo, .so, .dylib: %s" % dep.path)

  args.add_all(link_search, before_each="-ccopt", uniquify = True)
  args.add_all(cc_deps, before_each="-cclib", uniquify = True)

  args.add_all(includes, before_each="-I", uniquify = True)

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
  args.add_all(build_deps)
  # args.add_all(ctx.files.srcs)

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
      progress_message = "compiling ocaml_archive: @{ws}//{pkg}:{tgt}{msg}".format(
          ws  = ctx.label.workspace_name,
          pkg = ctx.label.package,
          tgt=ctx.label.name,
          msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
      )
    # progress_message = "ocaml_archive({}): {}".format(
    #     ctx.label.name, ctx.attr.msg
    #   )
  )

  archiveProvider = OcamlArchiveProvider(
    payload = struct(
      archive = ctx.label.name,
      cmxa = obj_cmxa,
      cmxs = obj_cmxs,
      a    = obj_a,
      # modules = build_deps + cc_deps
    ),
    deps = struct(
      opam = mydeps.opam,
      nopam = mydeps.nopam
    )
  )

  # print("ARCHIVEPROVIDER for {arch}: {ap}".format(arch=ctx.label.name, ap=archiveProvider))
  return [
    DefaultInfo(
      files = depset(
          order = "preorder",
          direct = obj_files,
        # transitive = [depset(build_deps + cc_deps)]
      )),
    archiveProvider,
    # libProvider
  ]

################################################################
ocaml_archive = rule(
  doc = """Generates an OCaml archive file (.cmxa) and a C archive file (.a).

  Here is an example, from the 'digestif' library:

ocaml_archive(
    name = "common_archive",
    msg = "digestif, common",
    opts = ["-I", "src", "-open", "Digestif_by"],
    deps = [
        ":digestif_by",
        ":digestif_bi",
        ":digestif_conv",
        ":digestif_eq",
        ":digestif_hash",
        ":digestif_mli", # this will be ignored, archives do not understand cmi files
    ]
)


""",
  implementation = _ocaml_archive_impl,
  attrs = dict(
    archive_name = attr.string(),
    doc = attr.string(),
    # preprocessor = attr.label(
    #   providers = [PpxInfo],
    #   executable = True,
    #   cfg = "exec",
    #   # allow_single_file = True
    # ),
    # srcs = attr.label_list(
    #   doc = "OCaml source files",
    #   allow_files = OCAML_FILETYPES
    # ),
    # src_root = attr.label(
    #   allow_single_file = True,
    #   mandatory = True,
    # ),
    ####  OPTIONS  ####
    ##Flags. We set some flags by default; these params
    ## allow user to override.
    ## Problem is, this target registers two actions,
    ## compile and link, and each has its own params.
    ## for now, these affect the compile action:
    # strict_sequence         = attr.bool(default = True),
    # strict_formats          = attr.bool(default = True),
    # short_paths             = attr.bool(default = True),
    compile_strict_sequence = attr.bool(default = True),
    link_strict_sequence    = attr.bool(default = True),
    keep_locs               = attr.bool(default = True),
    opaque                  = attr.bool(default = True),
    no_alias_deps           = attr.bool(default = True),
    debug                   = attr.bool(default = True),
    ## use these to pass additional args
    opts                    = attr.string_list(),
    linkopts                = attr.string_list(),
    warnings                = attr.string(
      default               = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"
    ),
    alwayslink = attr.bool(
      doc = "If true (default), use OCaml -linkall switch. Default: False",
      default = False,
    ),
    # nocopts = attr.string(),
    linkshared = attr.bool(default = False),
    #### end options ####
    # lib = attr.bool(default = False)
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlImportProvider],
                   [OcamlInterfaceProvider],
                   [OcamlModuleProvider],
                   [OcamlNsModuleProvider],
                   [OcamlArchiveProvider],
                   [PpxArchiveProvider]],
    ),
    cc_deps = attr.label_keyed_string_dict(
      doc = "C/C++ library dependencies",
      providers = [[CcInfo]]
    ),
    cc_linkopts = attr.string_list(
      doc = "C/C++ options",
    ),
    cc_linkall = attr.label_list(
        doc     = "True: use -whole-archive (GCC toolchain) or -force_load (Clang toolchain)",
        providers = [CcInfo],
    ),
    cc_linkstatic = attr.bool(
      doc     = "Control linkage of C/C++ dependencies. True: link to .a file; False: link to shared object file (.so or .dylib)",
      default = True # False
    ),
    mode = attr.string(default = "native"),
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    msg = attr.string(),
    # outputs = attr.output_list(
    #   # default = ["%{name}.pp.ml",
    #   #           "%{name}.pp.ml.d"],
    # )
  ),
  provides = [OcamlArchiveProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
  # outputs = { "build_dir": "_build_%{name}" },
)
