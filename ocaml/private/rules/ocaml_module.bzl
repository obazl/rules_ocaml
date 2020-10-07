load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
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
  # if (ctx.label.name == "snark0.cm_"):
  # if ctx.label.name == "RefList":
  #     debug = True

  if debug:
      print("MODULE TARGET: %s" % ctx.label.name)

  mydeps = get_all_deps("ocaml_module", ctx)
  # if debug:
  #     print("ALL DEPS for target %s:" % ctx.label.name)
  #     print(mydeps)

      # print("IMPL: %s" % ctx.file.impl.path)
  # srcs = copy_srcs_to_tmp(ctx)
  # print("SRCS: %s" % srcs)
  # impl_file = srcs[0]

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  entailed_deps = None

  dep_graph = []
  outputs   = []

  # ppx = None

  # if ctx.attr.ppx:
  #   for key in ctx.attr.ppx.keys():
  #         # print("KEY LABEL: %s" % key.label[PpxBinaryProvider])
  #         if debug:
  #             print("PPX KEY: %s" % key)
  #             if PpxBinaryProvider in key:
  #                 ppx = key
  #                 # print("PPX EXE[0] : %s" % ppx[0])
  #                 print("PPX EXE: %s" % key[PpxBinaryProvider])
  #                 print("PPX VAL: %s" % ctx.attr.ppx[key])

  if ctx.attr.ppx:
    # print("PPX EXE2: %s" % ppx[PpxBinaryProvider])
    # if not ppx:
    ppx = ctx.attr.ppx
    entailed_deps = ppx[PpxBinaryProvider].deps.x
    ## this will also handle ns
    outfile = ppx_transform_action("ocaml_module", ctx, ctx.file.impl)
    # print("PPX DEP: %s" % ctx.attr.ppx)
    # print("PPX DEP DEFAULT PROVIDER: %s" % ctx.attr.ppx[DefaultInfo])
    # print("PPX DEP PROVIDER: %s" % ctx.attr.ppx[PpxBinaryProvider])
    # print("PPX DEP FILE: %s" % ctx.file.ppx)
    dep_graph.append(ctx.file.ppx)
  elif ctx.attr.ns_module:
    # rename this module to put it in the namespace
    outfile = rename_ocaml_module(ctx, ctx.file.impl) #, ctx.attr.ns)
    # e.g. vector.ml -> Camlsnark_c_bindings__Vector.ml
  else:
    outfile = ctx.file.impl

  # cmxfname = ctx.file.impl.basename.rstrip("ml") + "cmx"
  cmxfname = paths.replace_extension(outfile.basename, tc.objext)
  # print("CMX FNAME: %s" % cmxfname)
  obj_cmx = ctx.actions.declare_file(cmxfname)
  # print("OBJ_CMX: %s" % obj_cmx)
  obj_cmi = None
  obj_cmt = None
  if ctx.attr.intf:
    if ctx.file.intf.extension == "mli":
        cmifname = paths.replace_extension(ctx.file.intf.basename, ".cmi")
        obj_cmi = ctx.actions.declare_file(cmifname)
    elif ctx.file.intf.extension == "cmi":
        obj_cmi = ctx.attr.intf[OcamlInterfaceProvider].payload.cmi
        if "-bin-annot" in ctx.attr.opts:
            if hasattr(ctx.attr.intf[OcamlInterfaceProvider].payload, "cmt"):
                obj_cmt = ctx.attr.intf[OcamlInterfaceProvider].payload.cmt

        if debug:
            print("MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM")
            print("CMI: %s" % obj_cmi)
            # obj_cmi = ctx.attr.intf.files.to_list()[0]
  else:
    cmifname = paths.replace_extension(outfile.basename, ".cmi")
    obj_cmi = ctx.actions.declare_file(cmifname)
    if "-bin-annot" in ctx.attr.opts:
        obj_cmt = ctx.actions.declare_file(paths.replace_extension(outfile.basename, ".cmt"))
        outputs.append(obj_cmt)

  ofname = paths.replace_extension(outfile.basename, ".o")
  obj_o = ctx.actions.declare_file(ofname)
  # cmxfname = paths.replace_extension(ctx.file.impl.basename, tc.objext)
  # obj_cmx = ctx.actions.declare_file(cmxfname)
  # ofname = paths.replace_extension(ctx.file.impl.basename, ".o")
  # obj_o = ctx.actions.declare_file(ofname)

  ################################################################
  args = ctx.actions.args()
  args.add(tc.compiler.basename)
  # args.add("-w", ctx.attr.warnings)
  options = tc.opts + ctx.attr.opts
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

  # if ctx.attr.ns:
  #   args.add("-open", ctx.attr.ns)
  if ctx.attr.ns_module:
    args.add("-no-alias-deps")
    args.add("-opaque")
    ns_cm = ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm
    ## NOTE: dep_graph and includes covered by mydeps.nopam
    # dep_graph.append(ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm)
    # dep_graph.append(ctx.attr.ns_module[OcamlNsModuleProvider].payload.cmi)
    # includes.append(ns_cm.dirname)
    ns_mod = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
    args.add("-open", ns_mod)
    # capitalize_initial_char(ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.ns))

  # args.add("-no-alias-deps")
  # args.add("-opaque")

  opam_deps = []
  if entailed_deps:
    for x_dep in entailed_deps.to_list():
        if OpamPkgInfo in x_dep:
            for x in x_dep[OpamPkgInfo].pkg.to_list():
                opam_deps.append(x.name)

  for datum in ctx.attr.data:
    dep_graph.extend(datum.files.to_list())

  if ctx.attr.intf:
    if ctx.file.intf.extension == "mli":
        # args.add(ctx.file.intf.path)
        # args.add("-intf", ctx.file.intf.path)
        dep_graph.append(ctx.file.intf)
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
                # includes.append(dep.dirname)

  # args.add("-I", obj_cmx.dirname)
  includes.append(obj_cmx.dirname)

  for dep in mydeps.nopam.to_list():
      # if debug:
      #     print("\nNOPAM DEP: %s\n\n" % dep)
      if dep.extension == "cmx":
        dep_graph.append(dep)
        # build_deps.append(dep)
        includes.append(dep.dirname)
      elif dep.extension == "cmi":
        dep_graph.append(dep)
        # includes.append(dep.dirname)
      ## cmi ignored if mli not present!
      elif dep.extension == "mli":
        dep_graph.append(dep)
        includes.append(dep.dirname)
      elif dep.extension == "o":
        # build_deps.append(dep)
        dep_graph.append(dep)
      elif dep.extension == "cmxa":
          build_deps.append(dep)
          dep_graph.append(dep)
          # includes.append(dep.dirname)
      ## cc deps
      elif dep.extension == "a":
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

  ####  TODO:  transitive cc_deps
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

  ## opam_deps already includes x_deps, now add transitive opam deps
  ## transitive opam deps - filter out ppx_driver-based libs
  # deps.extend(mydeps.opam.to_list())
  for dep in mydeps.opam.to_list():
      for x in dep.pkg.to_list():
          opam_deps.append(x.name)

  if len(opam_deps) > 0:
      # args.add("-linkpkg")
      for dep in opam_deps:  # mydeps.opam.to_list():
          args.add("-package", dep)
          # if not dep.ppx_driver:
          #     if dep.pkg.to_list()[0].name == "async":
          #         if async:
          #             args.add("-package", dep.pkg.to_list()[0].name)
          #         else:
          #             args.add("-package", dep.pkg.to_list()[0].name)

  args.add_all(build_deps)
  # args.add_all(cclib_deps)

  # according the the User Manual, -o is for executables and archives, not modules?
  args.add("-o", obj_cmx)

  if ctx.attr.intf:
    if ctx.file.intf.extension == "mli":
        args.add(ctx.file.intf.path)
  args.add(outfile)
  # args.add("-impl", outfile)

  # dep_graph = dep_graph + build_deps + cclib_deps + [outfile] #  [ctx.file.impl]  # ctx.files.impl
  dep_graph.extend(build_deps)
  dep_graph.extend(cclib_deps)
  dep_graph.append(outfile)

  # if ctx.attr.ns_module:
  #   dep_graph.append(ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm)

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
      else:
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
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlModule",
    progress_message = "ocaml_module({}), compiling impl {}".format(
      ctx.label.name, ctx.attr.msg
      )
  )

  module_provider = OcamlModuleProvider(
      payload = struct(
          # if we have an incoming cmi, its in the nopam deps
          # otherwise, we create it so it goes here(?)
          # what about the mli?
          cmi = obj_cmi,  # ctx.file.intf if ctx.file.intf else None,
          mli = dep_mli,
          cm  = obj_cmx,
          cmt = obj_cmt,
          o   = obj_o
      ),
    deps = struct(
      opam = mydeps.opam,
      nopam = mydeps.nopam
    )
  )

  if debug:
      print("\n\n================ OCAML MODULE PROVIDER PAYLOAD ================\n\n")
      print("CMI: %s\n\n" % module_provider.payload.cmi)
      print("MLI: %s\n\n" % module_provider.payload.mli)
      print("CM:  %s\n\n" % module_provider.payload.cm)
      print("CMT:  %s\n\n" % module_provider.payload.cmt)
      print("O:   %s\n\n" % module_provider.payload.o)

  directs = [obj_cmx, obj_o, obj_cmi]
  if obj_cmt: directs.append(obj_cmt)
  defaultInfo = DefaultInfo(
    # payload
      files = depset(
          order = "postorder",
          direct = directs
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
    doc = attr.string(
        doc = "Docstring for module"
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
        default = None
    ),
    impl = attr.label(
      mandatory = True,
      doc = "A single .ml source file label.",
      allow_single_file = OCAML_IMPL_FILETYPES
    ),
    intf = attr.label(
      doc = "Single label of a target providing a single .cmi or .mli file. Optional. Currently only supports .cmi input.",
      allow_single_file = [".cmi", ".mli"],
      # providers = [[DefaultInfo], [OcamlInterfaceProvider]],
    ),
    alwayslink = attr.bool(
      doc = "If true, use OCaml -linkall switch. Default: False",
      default = False,
    ),
    ##FIXME: ppx => ppx?
    ppx  = attr.label(
      doc = "PPX binary (executable).",
      allow_single_file = True,
      providers = [PpxBinaryProvider]
    ),
    ppx_args  = attr.string_list(
      doc = "Options to pass to PPX binary.",
    ),
    ppx_x = attr.label_keyed_string_dict(
        doc = "Experimental",
    ),
    ## FIXME: rename to ppx_runtime_deps
    ppx_deps  = attr.label_list(
        doc = "PPX dependencies. E.g. a file used by %%import from ppx_optcomp.",
        allow_files = True,
    ),
    ppx_output_format = attr.string(
      doc = "Format of output of PPX transform, binary (default) or text",
      values = ["binary", "text"],
      default = "binary"
    ),
    ##FIXME: ppx => ppx_libs
    # ppx = attr.label_keyed_string_dict(
    #   doc = """Dictionary of one entry. Key is a ppx target, val string is arguments."""
    # ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    data = attr.label_list(
    ),
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlArchiveProvider],
                   [OcamlInterfaceProvider],
                   [OcamlImportProvider],
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
