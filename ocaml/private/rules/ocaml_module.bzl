load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider",
     "OpamPkgInfo",
     "PpxArchiveProvider",
     "PpxBinaryProvider",
     "PpxModuleProvider")
load("//ocaml/private/actions:batch.bzl", "copy_srcs_to_tmp")
load("//ocaml/private/actions:module.bzl", "rename_ocaml_module", "ppx_transform_action")
load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")

load("//ocaml/private:deps.bzl", "get_all_deps")

load("//ocaml/private:utils.bzl",
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
########## RULE:  OCAML_MODULE  ################
def _ocaml_module_impl(ctx):

  debug = False
  if (ctx.label.name == "libsnark.cm_"):
      debug = True

  if debug:
      print("MODULE TARGET: %s" % ctx.label.name)

  mydeps = get_all_deps("ocaml_module", ctx)
  if debug:
      print("ALL DEPS for target %s:" % ctx.label.name)
      print(mydeps)

      # print("IMPL: %s" % ctx.file.impl.path)
  # srcs = copy_srcs_to_tmp(ctx)
  # print("SRCS: %s" % srcs)
  # impl_file = srcs[0]

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  output_deps = None

  dep_graph = []

  if ctx.attr.ppx_bin:
    output_deps = ctx.attr.ppx_bin[PpxBinaryProvider].deps.transform
    ## this will also handle ns
    outfile = ppx_transform_action("ocaml_module", ctx, ctx.file.impl)
    # print("PPX DEP: %s" % ctx.attr.ppx_bin)
    # print("PPX DEP DEFAULT PROVIDER: %s" % ctx.attr.ppx_bin[DefaultInfo])
    # print("PPX DEP PROVIDER: %s" % ctx.attr.ppx_bin[PpxBinaryProvider])
    # print("PPX DEP FILE: %s" % ctx.file.ppx_bin)
    dep_graph.append(ctx.file.ppx_bin)
  elif ctx.attr.ns_module:
    outfile = rename_ocaml_module(ctx, ctx.file.impl) #, ctx.attr.ns)
  else:
    outfile = ctx.file.impl

  # cmxfname = ctx.file.impl.basename.rstrip("ml") + "cmx"
  cmxfname = paths.replace_extension(outfile.basename, tc.objext)
  obj_cmx = ctx.actions.declare_file(cmxfname)
  obj_cmi = None
  if ctx.attr.cmi:
    obj_cmi = ctx.attr.cmi.files.to_list()[0]
  else:
    cmifname = paths.replace_extension(outfile.basename, ".cmi")
    obj_cmi = ctx.actions.declare_file(cmifname)

  ofname = paths.replace_extension(outfile.basename, ".o")
  obj_o = ctx.actions.declare_file(ofname)
  # cmxfname = paths.replace_extension(ctx.file.impl.basename, tc.objext)
  # obj_cmx = ctx.actions.declare_file(cmxfname)
  # ofname = paths.replace_extension(ctx.file.impl.basename, ".o")
  # obj_o = ctx.actions.declare_file(ofname)

  ################################################################
  args = ctx.actions.args()
  args.add(tc.compiler.basename)
  options = tc.opts + ctx.attr.opts
  args.add_all(options)
  if ctx.attr.alwayslink:
    args.add("-linkall")

  # modules are always compile-only
  args.add("-c")

  includes   = []

  # if ctx.attr.ns:
  #   args.add("-open", ctx.attr.ns)
  if ctx.attr.ns_module:
    args.add("-no-alias-deps")
    args.add("-opaque")
    ns_cm = ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm
    includes.append(ns_cm.dirname)
    ns_mod = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
    args.add("-open", ns_mod)
    # capitalize_initial_char(ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.ns))

  args.add("-no-alias-deps")
  args.add("-opaque")

  if output_deps:
    args.add_all([dep for dep in output_deps], before_each="-package")

  for datum in ctx.attr.data:
    dep_graph.extend(datum.files.to_list())
  if ctx.attr.cmi:
    # print("CMI: %s" % ctx.attr.cmi[OcamlInterfaceProvider])
    dep_graph.append(ctx.file.cmi)
    # args.add("-I", ctx.file.cmi.dirname)
    includes.append(ctx.file.cmi.dirname)
  # args.add("-I", obj_cmx.dirname)
  includes.append(obj_cmx.dirname)

  # we need to enumerate all build deps so we can add them to the
  # action dep_graph, and add a -I arg for them (we do not need to list
  # them as command line inputs, just the dirs where they can be found).
  build_deps = []

  #FIXME: async is a hack to deal with the situation where the target
  #depends on local async_kernel but a dep depends on opam asyn.
  async = False

  cclib_deps = []
  for dep in mydeps.nopam.to_list():
      if debug:
          print("NOPAM DEP: %s" % dep)
          print("NOPAM EXTENSION: %s" % dep.extension)
      if dep.extension == "cmx":
        if debug:
              print("CMX DEP: %s" % dep)
        build_deps.append(dep)
        includes.append(dep.dirname)
      elif dep.extension == "cmxa":
          if debug:
              print("CMXA DEP: %s" % dep)
          build_deps.append(dep)
          includes.append(dep.dirname)
          # for h in dep[OcamlModuleProvider].deps.nopam.to_list():
          #     if h.path.endswith(".cmx"):
          #         includes.append(h.dirname)
      elif dep.extension == "o":
        if debug:
            print("NOPAM .o DEP: %s" % dep)
        dep_graph.append(dep)
        args.add(dep)
      elif dep.extension == "a":
        if debug:
            print("NOPAM .a DEP: %s" % dep)
        dep_graph.append(dep)
        # args.add(dep)
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

  # print("BUILD DEPS: %s" % build_deps)

    # if not dep.basename.endswith(".o"):
    #   includes.append(dep.dirname)
    #   args.add(dep)
    #   build_deps.append(dep)

  # for dep in ctx.attr.deps:
  #   if debug:
  #       print("ATTR DEP: %s" % dep)
  #   for g in dep[DefaultInfo].files.to_list():
  #       if debug:
  #           print("ATTR DEP FILE: %s" % g)
  #       dep_graph.append(g)
  #       if g.path.endswith(".cmx"):
  #           build_deps.append(g)
  #           includes.append(g.dirname)
  #       elif g.path.endswith(".cmxa"):
  #           build_deps.append(g)
  #           includes.append(g.dirname)
  #           ## expose cmi files of deps for linking
  #           for h in dep[OcamlArchiveProvider].deps.nopam.to_list():
  #               if h.path.endswith(".cmx"):
  #                   includes.append(h.dirname)
  #       elif g.path.endswith(".cmxs"):
  #           includes.append(g.dirname)

    # print("DEP:  %s" % dep)
    # if dep.name == "async":
    #   async = True
    # if hasattr(dep, "cm"):
    #   build_deps.append(dep.cm)
    #   includes.append(dep.cm.dirname)
    # elif hasattr(dep, "cmxa"):
    #   build_deps.append(dep.cmxa)
    #   includes.append(dep.cmxa.dirname)

  # for dep in ctx.attr.cc_deps.items():
  #   if debug:
  #       print("CCLIB DEP: ")
  #       print(dep)
  #   if dep[1] == "static":
  #       if debug:
  #           print("STATIC lib: %s:" % dep[0])
  #       for depfile in dep[0].files.to_list():
  #           if (depfile.extension == "a"):
  #               cclib_deps.append(depfile)
  #               args.add(depfile)
  #               includes.append(depfile.dirname)
  #   elif dep[1] == "dynamic":
  #       if debug:
  #           print("DYNAMIC lib: %s" % dep[0])
  #       for depfile in dep[0].files.to_list():
  #           print("DEPFILE extension: %s" % depfile.extension)
  #           if (depfile.extension == "so"):
  #               libname = depfile.basename[:-3]
  #               libname = libname[3:]
  #               print("SOLIBNAME: %s" % depfile.basename)
  #               print("SO PARAM: -l%s" % libname)
  #               args.add("-cclib", "-l" + libname)
  #               cclib_deps.append(depfile)
  #           elif (depfile.extension == "dylib"):
  #               libname = depfile.basename[:-6]
  #               libname = libname[3:]
  #               print("DYLIBNAME: %s:" % libname)
  #               args.add("-cclib", "-l" + libname)
  #               includes.append(depfile.dirname)
  #               cclib_deps.append(depfile)

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

  args.add_all(includes, before_each="-I", uniquify = True)

  ## transitive opam deps - filter out ppx_driver-based libs
  args.add("-linkpkg")
  for dep in mydeps.opam.to_list():
    if not dep.ppx_driver:
      if dep.pkg.to_list()[0].name == "async":
        if async:
          args.add("-package", dep.pkg.to_list()[0].name)
      else:
          args.add("-package", dep.pkg.to_list()[0].name)

  args.add_all(build_deps)
  # args.add_all(cclib_deps)

  args.add("-o", obj_cmx)

  args.add("-impl", outfile)

  dep_graph = dep_graph + build_deps + cclib_deps + [outfile] #  [ctx.file.impl]  # ctx.files.impl

  if ctx.attr.ns_module:
    dep_graph.append(ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm)

  # print("DEP_GRAPH:")
  # print(dep_graph)

  # cwd = paths.dirname(ctx.build_file_path)
  # print("CWD: %s" % cwd)

  outputs = [obj_cmx, obj_o]
  if not ctx.attr.cmi:
    outputs.append(obj_cmi)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = dep_graph,
    outputs = outputs,
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlModule",
    progress_message = "ocaml_module({}), compiling impl {}".format(
      ctx.label.name, ctx.attr.msg
      )
  )

  module_provider = OcamlModuleProvider(
    payload = struct(
      cmi = obj_cmi,  # ctx.file.cmi if ctx.file.cmi else None,
      cm = obj_cmx,
      o   = obj_o
    ),
    deps = struct(
      opam = mydeps.opam,
      nopam = mydeps.nopam
    )
  )

  if debug:
      print("OCAML MODULE PROVIDER: %s" % module_provider)

  defaultInfo = DefaultInfo(
    # payload
      files = depset(
          order = "postorder",
          direct = [obj_cmx, obj_o, obj_cmi],
        # transitive = depset(mydeps.nopam.to_list())
      )
  )

  # print("\n\n\t\t\tOCAML_MODULE DEFAULTINFO: %s\n\n" % defaultInfo)

  return [
    defaultInfo,
    module_provider
  ]

#############################################
########## DECL:  OCAML_MODULE  ################
ocaml_module = rule(
  implementation = _ocaml_module_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    module_name   = attr.string(
      doc = "Module name."
    ),
    # ns   = attr.string(
    #   doc = "Namespace string; will be used as module name prefix."
    # ),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__'",
      default = "__"
    ),
    ns_module = attr.label(
      doc = "Label of an ocaml_ns_module target. Used to derive namespace, output name, -open arg, etc.",
    ),
    impl = attr.label(
      mandatory = True,
      doc = "A single .ml source file label.",
      allow_single_file = OCAML_IMPL_FILETYPES
    ),
    cmi = attr.label(
      doc = "Single label of a target providing a single .cmi file (not a .mli source file). Optional",
      allow_single_file = [".cmi"],
      providers = [OcamlInterfaceProvider],
    ),
    alwayslink = attr.bool(
      doc = "If true, use OCaml -linkall switch. Default: False",
      default = False,
    ),
    ##FIXME: ppx_bin => ppx?
    ppx_bin  = attr.label(
      doc = "PPX binary (executable).",
      allow_single_file = True,
      providers = [PpxBinaryProvider]
    ),
    ppx_bin_opts  = attr.string_list(
      doc = "Options to pass to PPX binary.",
    ),
    ppx_format = attr.string(
      values = ["binary", "text"],
      default = "binary"
    ),
    ##FIXME: ppx => ppx_libs
    ppx = attr.label_keyed_string_dict(
      doc = """Dictionary of one entry. Key is a ppx target, val string is arguments."""
    ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    data = attr.label_list(
    ),
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlArchiveProvider],
                   [OcamlInterfaceProvider],
                   [OcamlLibraryProvider],
                   [OcamlModuleProvider],
                   [PpxArchiveProvider],
                   [PpxModuleProvider],
                   [CcInfo]],
    ),
    cc_deps = attr.label_keyed_string_dict(
      doc = "C/C++ library dependencies",
      providers = [[CcInfo]]
    ),
    ## FIXME: call this cc_deps_default_type or some such
    cc_linkstatic = attr.bool(
      doc     = "Control linkage of C/C++ dependencies. True: link to .a file; False: link to shared object file (.so or .dylib)",
      default = True # False  ## false on macos, true on linux?
    ),
    mode = attr.string(default = "native"),
    msg = attr.string(),
  ),
  provides = [OcamlModuleProvider],
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
