load("@bazel_skylib//rules:common_settings.bzl",
     # "bool_flag",
     # "int_flag",
     # "string_flag", "string_setting",
     "BuildSettingInfo")

load("//ocaml/_providers:ocaml.bzl", "CompilationModeSettingProvider")
load("//ocaml/_providers:ocaml.bzl",
     "OcamlArchivePayload",
     "OcamlArchiveProvider",
     "OcamlDepsetProvider",
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
     "WARNING_FLAGS"
)
load(":options_ocaml.bzl", "options_ocaml")
load("//ocaml/_actions:utils.bzl", "get_options")

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

  mode = ctx.attr._mode[CompilationModeSettingProvider].value
  ext  = ".cmxa" if  mode == "native" else ".cma"

  ## declare outputs
  tmpdir = "_obazl_/"
  obj_files = []
  obj_cm_a = None
  obj_cmxs = None
  obj_a    = None
  if ctx.attr.archive_name:
    if ctx.attr.linkshared:
      obj_cmxs = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".cmxs")
    else:
      obj_cm_a = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ext)
      if mode == "native":
          obj_a = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".a")
  else:
    if ctx.attr.linkshared:
      obj_cmxs = ctx.actions.declare_file(tmpdir + ctx.label.name + ".cmxs")
    else:
      obj_cm_a = ctx.actions.declare_file(tmpdir + ctx.label.name + ext)
      if mode == "native":
          obj_a = ctx.actions.declare_file(tmpdir + ctx.label.name + ".a")

  build_deps = []  # for the command line
  includes = []
  dep_graph = []  # for the run action inputs

  ################################################################
  args = ctx.actions.args()
  # args.add(tc.compiler.basename)
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

  configurable_defaults = get_options(rule, ctx)
  args.add_all(configurable_defaults)

  args.add_all(ctx.attr.cc_linkopts, before_each="-ccopt")
  # if len(ctx.addr.cc_linkall) > 0:
  #     for cc_dep in ctx.files.linkall:


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

  # args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")
  if len(mydeps.opam.to_list()) > 0:
      ## DO NOT USE -linkpkg, it puts .cmxa files on command, yielding
      ## `Option -a cannot be used with .cmxa input files.`
      args.add_all([dep.pkg.name for dep in mydeps.opam.to_list()], before_each="-package")
      # args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

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
    ## mode == bytecode
    elif dep.extension == "cma":
        ## We ignore cma deps, since "Option -a cannot be used with .cmxa input files."
        ## But the depgraph contains everything contained in the cmxa, so we're covered.
        dep_graph.append(dep)
    elif dep.extension == "cmx":
        ## This will include cmx that are direct deps of cmxa files.
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
    ## mode == bytecode
    elif dep.extension == "cmo":
        ## This will include cmo that are direct deps of cmxa files.
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
        # args.add("-ccopt", "-L" + dep.dirname)
        # args.add("-cclib", "-l" + libname)
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
        # args.add("-ccopt", "-L" + dep.dirname)
        # args.add("-cclib", "-l" + libname)
        # includes.append(dep.dirname)
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

  if ctx.attr.linkshared:
    args.add("-shared")
    args.add("-o", obj_cmxs)
    obj_files.append(obj_cmxs)
  else:
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
    # progress_message = "ocaml_archive({}): {}".format(
    #     ctx.label.name, ctx.attr.msg
    #   )
  )

  if mode == "native":
      payload = OcamlArchivePayload(
          archive = ctx.label.name,
          cma = obj_cm_a,
          cmxs = obj_cmxs,
          a    = obj_a,
          # modules = build_deps + cc_deps
      )
  else:
      payload = OcamlArchivePayload(
          archive = ctx.label.name,
          cma = obj_cm_a,
          cmxs = obj_cmxs,
      )

  archiveProvider = OcamlArchiveProvider(
      payload = payload,
      deps = OcamlDepsetProvider(
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
    implementation = _ocaml_archive_impl,
    doc = """Generates an OCaml archive file. Provides: [OcamlArchiveProvider](providers_ocaml.md#ocamlarchiveprovider).

**<a name="deps">Dependencies</a>**: each entry in the `deps` list must provide one or more of the following Providers:

- [OpamPkgInfo](providers_ocaml.md#opampkginfo)
- [OcamlArchiveProvider](providers_ocaml.md#ocamlarchiveprovider) The OCaml compiler does not allow an archive to depend on an archive, but the OBazl rules support this.
- [OcamlInterfaceProvider](providers_ocaml.md#ocamlinterfaceprovider)
- [OcamlModuleProvider](providers_ocaml.md#ocamlmoduleprovider)
- [OcamlNsModuleProvider](providers_ocaml.md#ocamlnsmoduleprovider)
- [PpxArchiveProvider](providers_ppx.md#ppxarchiveprovider)

See [OCaml Dependencies](../ug/ocaml_deps.md) for more information on OCaml dependencies.

    """,
# - [OcamlImportProvider](providers_ocaml.md#ocamlimportprovider)
# - [OcamlLibraryProvider](providers_ocaml.md#ocamllibraryprovider)

    attrs = dict(
        options_ocaml,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//archive:linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//archive:threads"),
        _warnings  = attr.label(default = "@ocaml//archive:warnings"),
        # linkopts = attr.string_list(
        #     doc = "List of OCaml link options."
        # ),
        linkshared = attr.bool(
            doc = "Build a .cmxs ('plugin') for dynamic loading. Native mode only.",
            default = False
        ),
        #### end options ####
        archive_name = attr.string(
            doc = "Name of output file. Overrides default, which is derived from _name_ attribute."
        ),
        doc = attr.string( doc = "Deprecated" ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies. See [Dependencies](#deps) for details.",
            providers = [[OpamPkgInfo],
                         [OcamlImportProvider],
                         [OcamlInterfaceProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsModuleProvider],
                         [OcamlArchiveProvider],
                         [PpxArchiveProvider]
                         ],
        ),

        cc_deps = attr.label_keyed_string_dict(

            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            providers = [[CcInfo]]
        ),

        cc_linkopts = attr.string_list(
            doc = "List of C/C++ link options. E.g. `[\"-lstd++\"]`.",
        ),
        cc_linkall = attr.label_list(
            doc     = "True: use -whole-archive (GCC toolchain) or -force_load (Clang toolchain). Deps in this attribute must also be listed in cc_deps.",
            providers = [CcInfo],
        ),
        ## FIXME: make cc_linkmode a configurable default
        # cc_linkstatic = attr.bool( ## FIXME: rename cc_linkmode = static | dynamice
        #     doc     = "Override platform-dependent link mode (static or dynamic).",
        #     # default = False  # "@ocaml//:linkstatic"
        # ),
        ## FIXME: should this be hidden? yes - to set all cc_deps for
        ## one rule application, use the cc_deps attrib values.
        _cc_linkmode = attr.label(
            doc     = "Override platform-dependent link mode (static or dynamic). Configurable default is platform-dependent: static on Linux, dynamic on MacOS.",
            # no default, but settable to static or dynamic
            # default = "@ocaml//linkmode:static"
        ),
        _mode = attr.label(
            default = "@ocaml//mode"
        ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        # msg = attr.string(),
    ),
    provides = [OcamlArchiveProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
