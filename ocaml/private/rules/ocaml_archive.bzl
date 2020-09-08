load("//ocaml/private:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")

load("//ocaml/private:deps.bzl", "get_all_deps")

load("//ocaml/private:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
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
  if (ctx.label.name == "snarky_libsnark_bindings"):
      debug = True

  if debug:
      print("ARCHIVE TARGET: %s" % ctx.label.name)

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  mydeps = get_all_deps("ocaml_archive", ctx)
  if debug:
      print("ALL DEPS for target %s" % ctx.label.name)
      print(mydeps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  ## declare outputs
  obj_files = []
  obj_cmxa = None
  obj_cmxs = None
  obj_a    = None
  if ctx.attr.archive_name:
    if ctx.attr.linkshared:
      obj_cmxs = ctx.actions.declare_file(ctx.attr.archive_name + ".cmxs")
    else:
      obj_cmxa = ctx.actions.declare_file(ctx.attr.archive_name + ".cmxa")
      obj_a = ctx.actions.declare_file(ctx.attr.archive_name + ".a")
  else:
    if ctx.attr.linkshared:
      obj_cmxs = ctx.actions.declare_file(ctx.label.name + ".cmxs")
    else:
      obj_cmxa = ctx.actions.declare_file(ctx.label.name + ".cmxa")
      obj_a = ctx.actions.declare_file(ctx.label.name + ".a")

  args = ctx.actions.args()
  args.add("ocamlopt")
  args.add("-w", ctx.attr.warnings)
  options = tc.opts + ctx.attr.opts
  # if ctx.attr.nocopts:
  args.add_all(options)
  if ctx.attr.alwayslink:
    args.add("-linkall")

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
  for src in ctx.files.srcs:
    if src.path.endswith(".ml"):
      obj_files.append(ctx.actions.declare_file(src.basename.rstrip(".ml") + ".o"))
    # elif src is archive:
    #   emit archive unchanged

  # print("OBJ_FILES")
  # print(obj_files)

  build_deps = []  # for the command line
  includes = []
  dep_graph = []  # for the run action inputs

  args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")
  # args.add_all([dep.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  # for dep in mydeps.nopam.to_list():
  #   print("NOPAM DEP: %s" % dep)

  cclib_deps = []
  dso_deps = []

  for dep in mydeps.nopam.to_list():
    if debug:
        print("NOPAM DEP: %s" % dep)
    if dep.basename.endswith(".cmx"):
        # if (not dep.basename.endswith(".o")) and (not dep.basename.endswith(".a")) and (not dep.basename.endswith(".cmxa")):
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.basename.endswith(".cmxa"):
        includes.append(dep.dirname)
        dep_graph.append(dep)
        # build_deps.append(dep)
        # for g in dep[OcamlArchiveProvider].deps.nopam.to_list():
        #     if g.path.endswith(".cmx"):
        #         includes.append(g.dirname)
        #         build_deps.append(g)
        #         dep_graph.append(g)
    elif dep.basename.endswith(".o"):
        build_deps.append(dep)
        dep_graph.append(dep)
    elif dep.basename.endswith(".a"):
        build_deps.append(dep)
        dep_graph.append(dep)
    elif dep.basename.endswith(".so"):
        dso_deps.append(dep)
    else:
        if debug:
            print("NOMAP DEP not .cmx, ,cmxa, .o, .so: %s" % dep.path)

  for dso in dso_deps:
      if (dso.extension == "so"):
          libname = dso.basename[:-3]
          libname = libname[3:]
          # print("LIBNAME: %s" % libname)
          args.add("-ccopt", "-L" + dso.dirname)
          args.add("-cclib", "-l" + libname)
          # cclib_deps.append(dso)
      elif (dso.extension == "dylib"):
          libname = dso.basename[:6]
          libname = libname[3:]
          args.add("-ccopt", "-L" + dso.dirname)
          args.add("-cclib", "-l" + libname)
          includes.append(dso.dirname)

  ## this does not eliminate dups:
  for dep in ctx.attr.deps:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".cmxa"):
          for h in dep[OcamlArchiveProvider].deps.nopam.to_list():
            if h.path.endswith(".cmx"):
              includes.append(h.dirname)
              # build_deps.append(h)
              dep_graph.append(h)
        else:
          dep_graph.append(g)
  #       includes.append(g.dirname)
  #       # if g.path.endswith(".cmi"):
  #       #   build_deps.append(g)
  #       if g.path.endswith(".cmx"):
  #         dep_graph.append(g)
  #         build_deps.append(g)

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
                includes.append(depfile.dirname)
    elif dep[1] == "dynamic":
        if debug:
            print("DYNAMIC lib: %s" % dep[0])
        for depfile in dep[0].files.to_list():
            if debug:
                print("DEPFILE extension: %s" % depfile.extension)
            if (depfile.extension == "so"):
                libname = depfile.basename[:-3]
                print("LIBNAME: %s" % libname)
                libname = libname[3:]
                print("LIBNAME: %s" % libname)
                args.add("-ccopt", "-L" + depfile.dirname)
                args.add("-cclib", "-l" + libname)
                # cclib_deps.append(depfile)
            elif (depfile.extension == "dylib"):
                libname = depfile.basename[:-6]
                libname = libname[3:]
                print("LIBNAME: %s:" % libname)
                args.add("-ccopt", "-L" + depfile.dirname)
                args.add("-cclib", "-l" + libname)
                includes.append(depfile.dirname)
            else:
                if debug:
                    print("IGNORING: %s" % depfile)

  # cclib_deps = []
  # for dep in ctx.attr.cc_deps:
  #   if debug:
  #       print("CCLIB DEP: %s" % dep)
  #   for depfile in dep.files.to_list():
  #     if debug:
  #         print("CCLIB DEP FILE: %s" % depfile)

  #     ##FIXME:  if linkstatic
  #     if depfile.extension == "a":
  #       # if debug:
  #       #     print("SKIPPING %s" % depfile)
  #       ## -dllib is for bytecode only
  #       # args.add("-dllib", "lrakia")
  #       # libname = depfile.basename.rstrip("a")
  #       # libname = libname.rstrip(".")
  #       # libname = libname.lstrip("lib")
  #       # args.add("-cclib", "-l" + libname)
  #       includes.append(depfile.dirname)
  #       cclib_deps.append(depfile)
  #     elif depfile.extension == "dylib":
  #       libname = depfile.basename.rstrip("dylib")
  #       libname = libname.rstrip(".")
  #       libname = libname.lstrip("lib")
  #       args.add("-cclib", "-l" + libname)
  #       # cclib_deps.append(depfile)
  #     elif depfile.extension == "so":
  #       ## incredibly, starlark's rstrip function does not strip suffix strings, only char classes.
  #       ## rstrip(".so") would take snarky_stubs.so to snarky_stub
  #       ## so we have to hack it:
  #       libname = depfile.basename.rstrip("o")
  #       libname = libname.rstrip("s")
  #       libname = libname.rstrip(".")
  #       libname = libname.lstrip("lib")
  #       args.add("-cclib", "-l" + libname)
  #       # cclib_deps.append(depfile)

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
  args.add_all(cclib_deps)
  args.add_all(ctx.files.srcs)

  dep_graph = dep_graph + build_deps + cclib_deps + ctx.files.srcs
  if debug:
      print("INPUT_ARGS:")
      print(dep_graph)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = dep_graph,
    outputs = obj_files,
    tools = [tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlLibrary",
    progress_message = "ocaml_archive({}): {}".format(
        ctx.label.name, ctx.attr.msg
      )
  )

  archiveProvider = OcamlArchiveProvider(
    payload = struct(
      archive = ctx.label.name,
      cmxa = obj_cmxa,
      cmxs = obj_cmxs,
      a    = obj_a,
      # modules = build_deps + cclib_deps
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
        direct = obj_files,
        # transitive = [depset(build_deps + cclib_deps)]
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
    preprocessor = attr.label(
      providers = [PpxInfo],
      executable = True,
      cfg = "exec",
      # allow_single_file = True
    ),
    srcs = attr.label_list(
      doc = "OCaml source files",
      allow_files = OCAML_FILETYPES
    ),
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
                   [OcamlInterfaceProvider],
                   [OcamlModuleProvider],
                   [OcamlNsModuleProvider],
                   # [OcamlLibraryProvider],
                   [OcamlArchiveProvider]],
    ),
    cc_deps = attr.label_keyed_string_dict(
      doc = "C/C++ library dependencies",
      providers = [[CcInfo]]
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
