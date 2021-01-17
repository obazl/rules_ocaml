load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider")

load("@obazl_rules_opam//opam/_providers:opam.bzl",
     "OpamPkgInfo")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name",
)

load("//ocaml/_providers:ocaml.bzl", "OcamlSDK")

load("//ppx/_transitions:transitions.bzl", "ppx_mode_transition")

load("//ppx:_providers.bzl",
     "PpxCompilationModeSettingProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load(":options_ppx.bzl", "options_ppx")

#############################################
####  PPX_EXECUTABLE IMPLEMENTATION
def impl_executable(ctx):

  debug = False
  # if (ctx.label.name == "gen.exe"):
  #     debug = True

  if debug:
      print("\n\n\tPPX_EXECUTABLE TARGET: %s\n\n" % ctx.label.name)

  mydeps = get_all_deps(ctx.attr._rule, ctx)
  if debug:
      print("MYDEPS: %s" % mydeps)

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  if ctx.attr._rule == "ocaml_executable":
      mode = ctx.attr._mode[CompilationModeSettingProvider].value
  else:
      mode = ctx.attr._mode[0][CompilationModeSettingProvider].value

  if ctx.attr.exe_name:
    outfilename = ctx.attr.exe_name
  else:
    outfilename = ctx.label.name

  outbinary = ctx.actions.declare_file(outfilename)

  dep_graph = []

  includes = []

  ################################################################
  args = ctx.actions.args()

  if mode == "bytecode":
      args.add(tc.ocamlc.basename)

      ## FIXME: static v. dynamic linking of cc libs in bytecode mode
      # see https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss%3Adynlink-c-code

      # default linkmode for toolchain is determined by platform
      # see @ocaml//toolchain:BUILD.bazel, ocaml/_toolchains/*.bzl
      # dynamic linking does not currently work on the mac - ocamlrun
      # wants a file named 'dllfoo.so', which rust cannot produce. to
      # support this we would need to rename the file using install_name_tool
      # for macos linkmode is dynamic, so we need to override this for bytecode mode
      args.add("-custom")
  else:
      args.add(tc.ocamlopt.basename)

  for opt in ctx.attr._opts[BuildSettingInfo].value:
      # print("EXTRA OPT: %s" % opt)
      args.add(opt)
  options = get_options(rule, ctx)
  args.add_all(options)

  if mode == "bytecode":
      dllpath = ctx.attr._sdkpath[OcamlSDK].path + "/lib/stublibs"
      args.add("-dllpath", dllpath)

      # args.add("-dllpath", "/private/var/tmp/_bazel_gar/d8a1bb469d0c2393045b412d4daaa038/execroot/ppx_version/external/ocaml/switch/lib/stublibs")

      args.add("-I", "external/ocaml/switch/lib/stublibs")

  build_deps = []
  dynamic_libs = []
  static_libs  = []
  link_search  = []
  # print("NOPAMS: %s" % mydeps.nopam)
  # we need to add the archive components to inputs, the archive is not enough
  # without these we get "implementation not found"
  for dep in mydeps.nopam.to_list():
    if debug:
        print("NOPAM DEP: %s" % dep)
        print("DEPGRAPH:  %s" % dep_graph)

    if dep.extension == "cmo":
      dep_graph.append(dep)
      includes.append(dep.dirname)
      build_deps.append(dep)
    elif dep.extension == "cmx":
      dep_graph.append(dep)
      includes.append(dep.dirname)
      build_deps.append(dep)
    elif dep.extension == "o":
      dep_graph.append(dep)
      includes.append(dep.dirname)

    elif dep.extension == "cmi":
      dep_graph.append(dep)
      includes.append(dep.dirname)
    elif dep.extension == "mli":
      dep_graph.append(dep)
      includes.append(dep.dirname)

    ## FIXME: handle archives
    elif dep.extension == "cma":
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "cmxa":
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "a":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
        ## FIXME: implement this?
        # if dep in mydeps.cc_alwayslink:
        #     if tc.cc_toolchain == "clang":
        #         args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))
        #     elif tc.cc_toolchain == "gcc":
        #         libname = file_to_lib_name(cc_dep)
        #         args.add("-ccopt", "-L{dir}".format(dir=cc_dep.dirname))
        #         args.add("-ccopt", "-Wl,--push-state,-whole-archive")
        #         args.add("-ccopt", "-l{lib}".format(lib=libname))
        #         args.add("-ccopt", "-Wl,--pop-state")
        # else:

    elif dep.extension == "so":
        dep_graph.append(dep)
        link_search.append("-L" + dep.dirname)
        libname = file_to_lib_name(dep)
        dynamic_libs.append("-l" + libname)
    elif dep.extension == "dylib":
        dep_graph.append(dep)
        link_search.append("-L" + dep.dirname)
        libname = file_to_lib_name(dep)
        dynamic_libs.append("-l" + libname)

        ## FIXME
        if mode == "bytecode":
            execroot = "/private/var/tmp/_bazel_gar/a96cd3ac87eaeba07bfd00b35d52a61a/execroot/mina"
            args.add("-dllpath", execroot + "/" + dep.dirname)

  # if mode == "bytecode":
  #     ## FIXME.  REALLY!!!
  #     dllpath = ctx.attr._sdkpath[OcamlSDK].path + "/lib/stublibs"
      # args.add("-dllpath", dllpath)

  opam_deps = mydeps.opam.to_list()
  ## indirect adjunct deps
  opam_deps.extend(mydeps.opam_adjunct.to_list())

  if len(opam_deps) > 0:
    # print("Linking OPAM deps for {target}".format(target=ctx.label.name))
    args.add("-linkpkg") # adds OPAM cmxa files to command
    args.add_all([dep.pkg.name for dep in mydeps.opam.to_list()], before_each="-package")

  ## cc deps
  ## FIXME: currently we have both cc_deps dict with static/dynamic/default vals,
  ## and cc_linkall list. Replace the latter with a "static-linkall" value for the former
  cclib_deps = []
  for dep in ctx.attr.cc_deps.items():
    if debug:
        print("CCLIB DEP: ")
        print(dep)
    if dep[1] == "static":
        if debug:
            print("STATIC lib: %s:" % dep[0])
        for depfile in dep[0].files.to_list():
            if (depfile.extension == "a"):
                args.add(depfile)
                cclib_deps.append(depfile)
                includes.append(depfile.dirname)
    elif dep[1] == "static-linkall":
        if debug:
            print("STATIC LINKALL lib: %s:" % dep[0])
        for depfile in dep[0].files.to_list():
            if (depfile.extension == "a"):
                args.add(depfile)
                cclib_deps.append(depfile)
                includes.append(depfile.dirname)
    elif dep[1] == "dynamic":
        if debug:
            print("DYNAMIC lib: %s" % dep[0])
        for depfile in dep[0].files.to_list():
            print("DEPFILE: %s" % depfile)
            print("DEPFILE extension: %s" % depfile.extension)
            if (depfile.extension == "so"):
                libname = depfile.basename[:-3]
                print("LIBNAME: %s" % libname)
                # libname = libname[3:]
                libname = file_to_lib_name(depfile)
                print("LIBNAME: %s" % libname)
                args.add("-ccopt", "-L" + depfile.dirname)
                args.add("-cclib", "-l" + libname)
                cclib_deps.append(depfile)
            elif (depfile.extension == "dylib"):
                libname = depfile.basename[:-6]
                libname = libname[3:]
                print("LIBNAME: %s:" % libname)
                args.add("-cclib", "-l" + libname)
                args.add("-ccopt", "-L" + depfile.dirname)
                cclib_deps.append(depfile)

  if hasattr(ctx.attr, "cc_linkall"):
      if debug:
          print("DEPSET CC_LINKALL: %s" % ctx.attr.cc_linkall)
      for cc_dep in ctx.files.cc_linkall:
          if cc_dep.extension == "a":
              dep_graph.append(cc_dep)
              path = cc_dep.path

              if tc.cc_toolchain == "clang":
                  args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))
              elif tc.cc_toolchain == "gcc":
                  libname = file_to_lib_name(cc_dep)
                  args.add("-ccopt", "-L{dir}".format(dir=cc_dep.dirname))
                  args.add("-ccopt", "-Wl,--push-state,-whole-archive")
                  args.add("-ccopt", "-l{lib}".format(lib=libname))
                  args.add("-ccopt", "-Wl,--pop-state")
              else:
                  fail("NO CC")

  if debug:
      print("DEP_GRAPH:")
      print(dep_graph)

  dep_graph.extend(build_deps)
  dep_graph = dep_graph + cclib_deps #  srcs_ml + outs_cmi

  ## main must come last!
  ## FIXME: put deps of main into dep_graph, but also make sure main file itself comes last

  # driver shim source must come after lib deps!
  # for src in ctx.files.main:
  #     if src.extension == "cmx":
  #         args.add(src)
  #     elif src.extension == "ml":
  #         args.add(src)

  dep_graph.extend(ctx.files.main)

  if ctx.attr.cc_linkopts:
      args.add_all(ctx.attr.cc_linkopts, before_each="-ccopt")

  args.add_all(link_search, before_each="-ccopt", uniquify = True)
  args.add_all(dynamic_libs, before_each="-cclib", uniquify = True)

  args.add_all(includes, before_each="-I", uniquify = True)
  args.add_all(build_deps)

        ## opam deps are just strings, we feed them to ocamlfind, which finds the file.
        ## this means we cannot add them to the dep_graph.
        ## this makes sense, the exe we build does not depend on these,
        ## it's the subsequent transform that depends on them.
    # else:
    #     dep_graph.append(dep)
    #FIXME: also support non-opam transform deps

  args.add("-o", outbinary)

  ## runtime deps go in ctx.runfiles
  if ctx.attr.strip_data_prefixes:
    myrunfiles = ctx.runfiles(
      files = ctx.files.data,
      symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
    )
  else:
    myrunfiles = ctx.runfiles(
      files = ctx.files.data,
    )

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = dep_graph,
    outputs = [outbinary],
    tools = [tc.ocamlfind, tc.ocamlopt], # tc.opam,
    mnemonic = "OcamlExecutable" if ctx.attr._rule == "ocaml_executable" else "PpxExecutable",
    progress_message = "{mode} compiling {rule}({target})".format(
        mode = mode,
        rule = ctx.attr._rule,
        target = ctx.label.name,
      )
  )

  defaultInfo = DefaultInfo(
      executable=outbinary,
      runfiles = myrunfiles
  )

  if ctx.attr._rule == "ppx_executable":
      provider = PpxExecutableProvider(
          payload = outbinary,
          args = depset(direct = ctx.attr.args),
          deps = struct(
              opam = mydeps.opam,
              opam_adjunct = mydeps.opam_adjunct,
              # opam_adjunct = depset(direct = opam_adjunct_deps),
                nopam = mydeps.nopam,
              nopam_adjunct = mydeps.nopam_adjunct
              # nopam_adjunct = depset(direct = nopam_adjunct_deps)
            )
      )
      results = [
          defaultInfo,
          provider
      ]

  elif ctx.attr._rule == "ocaml_executable":
      results = [
          defaultInfo,
      ]

  if debug:
      print("IMPL_EXECUTABLE RESULTS:")
      print(results)

  return results
