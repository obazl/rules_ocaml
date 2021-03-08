load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     "OcamlExecutableProvider",
     "OcamlModuleProvider",
     "OcamlNsLibraryProvider",
     "OcamlSignatureProvider",
     "OcamlSDK",
     "OpamDepsProvider",
     "PpxCompilationModeSettingProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

# load("//ppx/_transitions:transitions.bzl", "ppx_mode_transition")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name",
)

load(":options.bzl", "options")

load(":impl_common.bzl", "merge_deps")

################################################################
def _handle_cc_deps(ctx,
                    default_linkmode,
                    cc_deps_dict, ## list of dicts
                    args,
                    includes,
                    cclib_deps,
                    cc_runfiles):

    debug = False
    # if ctx.attr._rule == "ocaml_executable":
    #     debug = True
    if debug:
        print("EXEC _handle_cc_deps %s" % ctx.label)
        print("CC_DEPS_DICT: %s" % cc_deps_dict)

    # first dedup
    ccdeps = {}
    for ccdict in cclib_deps:
        for [dep, linkmode] in ccdict.items():
            if dep in ccdeps.keys():
                print("CCDEP DUP? %s" % dep)
            else:
                ccdeps.update({dep: linkmode})

    # for ccdict in cc_deps_dicts:
    for [dep, linkmode] in cc_deps_dict.items(): ## ccdict.items():
        if debug:
            print("CCLIB DEP: ")
            print(dep)
        if linkmode == "default":
            if debug: print("DEFAULT LINKMODE: %s" % default_linkmode)
            for depfile in dep.files.to_list():
                if default_linkmode == "static":
                    if (depfile.extension == "a"):
                        args.add(depfile)
                        cclib_deps.append(depfile)
                        includes.append(depfile.dirname)
                else:
                    for depfile in dep.files.to_list():
                        if (depfile.extension == "so"):
                            libname = file_to_lib_name(depfile)
                            if debug:
                                print("so LIBNAME: %s" % libname)
                            args.add("-ccopt", "-L" + depfile.dirname)
                            args.add("-cclib", "-l" + libname)
                            cclib_deps.append(depfile)
                        elif (depfile.extension == "dylib"):
                            libname = file_to_lib_name(depfile)
                            # libname = depfile.basename[:-6]
                            # libname = libname[3:]
                            if debug:
                                print("dylib LIBNAME: %s:" % libname)
                            args.add("-cclib", "-l" + libname)
                            args.add("-ccopt", "-L" + depfile.dirname)
                            cclib_deps.append(depfile)
                            cc_runfiles.append(dep.files)
        elif linkmode == "static":
            if debug:
                print("STATIC lib: %s:" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "a"):
                    args.add(depfile)
                    cclib_deps.append(depfile)
                    includes.append(depfile.dirname)
        elif linkmode == "static-linkall":
            if debug:
                print("STATIC LINKALL lib: %s:" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "a"):
                    cclib_deps.append(depfile)
                    includes.append(depfile.dirname)
                    # args.add(depfile)
                    if ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"].cc_toolchain == "clang":
                    # if tc.cc_toolchain == "clang":
                        args.add("-ccopt", "-Wl,-force_load,{path}".format(path = depfile.path))
                    elif ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"].cc_toolchain == "gcc":
                    # elif tc.cc_toolchain == "gcc":
                        libname = file_to_lib_name(depfile)
                        args.add("-ccopt", "-L{dir}".format(dir=depfile.dirname))
                        args.add("-ccopt", "-Wl,--push-state,-whole-archive")
                        args.add("-ccopt", "-l{lib}".format(lib=libname))
                        args.add("-ccopt", "-Wl,--pop-state")
                    else:
                        fail("NO CC")

            # if ctx.attr.cc_linkall:
            #     if debug:
            #         print("DEPSET CC_LINKALL: %s" % ctx.attr.cc_linkall)
            # for cc_dep in ctx.files.cc_linkall:
            #     if cc_dep.extension == "a":
            #         dep_graph.append(cc_dep)
            #         path = cc_dep.path

            #         if tc.cc_toolchain == "clang":
            #             args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))
            #         elif tc.cc_toolchain == "gcc":
            #             libname = file_to_lib_name(cc_dep)
            #             args.add("-ccopt", "-L{dir}".format(dir=cc_dep.dirname))
            #             args.add("-ccopt", "-Wl,--push-state,-whole-archive")
            #             args.add("-ccopt", "-l{lib}".format(lib=libname))
            #             args.add("-ccopt", "-Wl,--pop-state")
            #         else:
            #             fail("NO CC")

        elif linkmode == "dynamic":
            if debug:
                print("DYNAMIC lib: %s" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "so"):
                    libname = file_to_lib_name(depfile)
                    print("so LIBNAME: %s" % libname)
                    args.add("-ccopt", "-L" + depfile.dirname)
                    args.add("-cclib", "-l" + libname)
                    cclib_deps.append(depfile)
                elif (depfile.extension == "dylib"):
                    libname = file_to_lib_name(depfile)
                    print("LIBNAME: %s:" % libname)
                    args.add("-cclib", "-l" + libname)
                    args.add("-ccopt", "-L" + depfile.dirname)
                    cclib_deps.append(depfile)
                    cc_runfiles.append(dep.files)

#########################
def impl_executable(ctx):

    debug = False
    # if ctx.attr._rule == "ocaml_executable":
    #     debug = True
    # if ctx.label in ["//src/lib/crypto_params/gen:gen.exe"]:
    #     debug = True

    if debug:
        print("EXECUTABLE TARGET: {kind}: {tgt}".format(
            kind = ctx.attr._rule,
            tgt  = ctx.label.name
        ))

    OCAMLFIND_IGNORE = ""
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif/c"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"

    env = {
        "OPAMROOT": get_opamroot(),
        "PATH": get_sdkpath(ctx),
        "OCAMLFIND_IGNORE_DUPS_IN": OCAMLFIND_IGNORE
    }

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    # if ctx.attr._rule == "ocaml_executable":
    if ctx.attr.mode:
        mode = ctx.attr.mode
    else:
        mode = ctx.attr._mode[CompilationModeSettingProvider].value
    # else:
    #     mode = ctx.attr._mode[0][CompilationModeSettingProvider].value

    # if ctx.attr.exe_name:
    #   outfilename = ctx.attr.exe_name
    # else:
    outfilename = ctx.label.name

    outbinary = ctx.actions.declare_file(outfilename)

    ################
    direct_file_deps = []
    indirect_file_depsets = []

    indirect_opam_depsets = []
    # indirect_nopam_depsets = []

    indirect_adjunct_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets  = []  # list of depsets gathered from direct deps

    indirect_path_depsets = []

    direct_resolver = None
    indirect_resolver_depsets = []

    direct_cc_deps    = {}
    direct_cc_deps.update(ctx.attr.cc_deps) # if ctx.attr.cc_deps else []
    indirect_cc_deps  = {}
    if debug:
        print("CCDEPSx: %s" % ctx.attr.cc_deps)
        print("INDIRECT_CC_DEPS x: %s" % indirect_cc_deps)
    ################

    # dep_graph = []
    includes  = []

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

    # if mode == "bytecode":
    #     dllpath = ctx.attr._sdkpath[OcamlSDK].path + "/lib/stublibs"
    #     args.add("-dllpath", dllpath)

        # args.add("-dllpath", "/private/var/tmp/_bazel_gar/d8a1bb469d0c2393045b412d4daaa038/execroot/ppx_version/external/ocaml/switch/lib/stublibs")

        # args.add("-I", "external/ocaml/switch/lib/stublibs")

    # build_deps = []
    dynamic_libs = []
    static_libs  = []
    link_search  = []

    # for dep in mydeps.nopam.to_list():
    #   if debug:
    #       print("NOPAM DEP: %s" % dep)
    #       print("DEPGRAPH:  %s" % dep_graph)

    #   if dep.extension == "cmo":
    #     dep_graph.append(dep)
    #     includes.append(dep.dirname)
    #     build_deps.append(dep)
    #   elif dep.extension == "cmx":
    #     dep_graph.append(dep)
    #     includes.append(dep.dirname)
    #     build_deps.append(dep)
    #   elif dep.extension == "o":
    #     dep_graph.append(dep)
    #     includes.append(dep.dirname)

    #   elif dep.extension == "cmi":
    #     dep_graph.append(dep)
    #     includes.append(dep.dirname)
    #   elif dep.extension == "mli":
    #     dep_graph.append(dep)
    #     includes.append(dep.dirname)

    #   ## FIXME: handle archives
    #   elif dep.extension == "cma":
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #   elif dep.extension == "cmxa":
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #   elif dep.extension == "a":
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #       build_deps.append(dep)
    #       ## FIXME: implement this?
    #       # if dep in mydeps.cc_alwayslink:
    #       #     if tc.cc_toolchain == "clang":
    #       #         args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))
    #       #     elif tc.cc_toolchain == "gcc":
    #       #         libname = file_to_lib_name(cc_dep)
    #       #         args.add("-ccopt", "-L{dir}".format(dir=cc_dep.dirname))
    #       #         args.add("-ccopt", "-Wl,--push-state,-whole-archive")
    #       #         args.add("-ccopt", "-l{lib}".format(lib=libname))
    #       #         args.add("-ccopt", "-Wl,--pop-state")
    #       # else:

    #   elif dep.extension == "so":
    #       dep_graph.append(dep)
    #       cc_runfiles.append(dep)
    #       link_search.append("-L" + dep.dirname)
    #       libname = file_to_lib_name(dep)
    #       dynamic_libs.append("-l" + libname)
    #   elif dep.extension == "dylib":
    #       dep_graph.append(dep)
    #       cc_runfiles.append(dep)
    #       link_search.append("-L" + dep.dirname)
    #       libname = file_to_lib_name(dep)
    #       dynamic_libs.append("-l" + libname)

    #       ## FIXME
    #       if mode == "bytecode":
    #           execroot = "/private/var/tmp/_bazel_gar/a96cd3ac87eaeba07bfd00b35d52a61a/execroot/mina"
    #           args.add("-dllpath", execroot + "/" + dep.dirname)

    # if mode == "bytecode":
    #     ## FIXME.  REALLY!!!
    #     dllpath = ctx.attr._sdkpath[OcamlSDK].path + "/lib/stublibs"
        # args.add("-dllpath", dllpath)

    if debug:
        print("LABEL: %s" % ctx.label)
    merge_deps(ctx.attr.deps,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    # if debug:
    #     for dep in indirect_file_depsets:
    #         for f in dep.to_list():
    #             print("DEP: %s" % f)

    # for dep in ctx.attr.deps:
    #     if OpamPkgInfo in dep:
    #           fail("OPAM DEP: %s" % dep)

    #     # first direct deps
    #     indirect_file_depsets.append(dep[DefaultInfo].files)

    #     # then paths and resolvers providers
    #     if OcamlModuleProvider in dep:
    #         # print("MODULE OcamlModuleProvider: %s" % dep[OcamlModuleProvider])
    #         provider = dep[OcamlModuleProvider]
    #     elif OcamlSignatureProvider in dep:
    #         # print("SIG: OcamlSignatureProvider: %s" % dep[OcamlSignatureProvider])
    #         provider = dep[OcamlSignatureProvider]
    #     elif OcamlNsLibraryProvider in dep:
    #         # print("NSLIB: OcamlNsLibraryProvider: %s" % dep[OcamlNsLibraryProvider])
    #         provider = dep[OcamlNsLibraryProvider]

    # for path in provider.paths.to_list():
    #     includes.append(path)

    # if provider.resolvers:
    #     indirect_resolver_depsets.append(provider.resolvers)
        # for resolver in provider.resolvers.to_list():
        #     args.add("-open", resolver)

    # then adjunct deps
        # if AdjunctDepsProvider in dep:
        #     indirect_adjunct_opam_depsets.append(dep[AdjunctDepsProvider].opam)
        #     indirect_adjunct_opam_depsets.append(dep[AdjunctDepsProvider].nopam)

    if ctx.attr.deps_opam:
        args.add("-linkpkg")
        for dep in ctx.attr.deps_opam:
            args.add("-package", dep)

    # print("EXEC OPAMS: %s" % indirect_opam_depsets)
    opams = depset(transitive = indirect_opam_depsets).to_list()
    if len(opams) > 0:
        args.add("-linkpkg")
        [args.add("-package", opam) for opam in opams if opams]

    # for dep in ctx.attr.deps:
    #     if OcamlArchiveProvider in dep:
    #         print("ARC %s" % dep[DefaultInfo])
    #         args.add_all(dep[DefaultInfo].files.to_list())
    #     if OcamlModuleProvider in dep:
    #         print("MOD %s" % dep[OcamlModuleProvider])
    #         args.add(dep[OcamlModuleProvider].module)

    # opam_deps = mydeps.opam.to_list()
    # # print("OPAM DEPS: %s" % opam_deps)
    # ## indirect adjunct deps
    # opam_deps.extend(mydeps.opam_adjunct.to_list())

    # if len(opam_deps) > 0:
    #   # print("Linking OPAM deps for {target}".format(target=ctx.label.name))
    #   args.add("-linkpkg") # adds OPAM cmxa files to command
    #   args.add_all([dep.pkg.name for dep in mydeps.opam.to_list()], before_each="-package")


    ## main is a dep, just like the deps in 'deps'
    ## passing it to merge_deps here ensures that it will come last
    # if debug:
    # print("LABEL: %s" % ctx.label)
    if ctx.attr.main != None:
        merge_deps([ctx.attr.main],
                   indirect_file_depsets,
                   indirect_path_depsets,
                   indirect_resolver_depsets,
                   indirect_opam_depsets,
                   indirect_adjunct_depsets,
                   indirect_adjunct_path_depsets,
                   indirect_adjunct_opam_depsets,
                   indirect_cc_deps)

    indirect_paths_depset = depset(transitive = indirect_path_depsets)
    for path in indirect_paths_depset.to_list():
        # print("PATH: %s" % path)
        includes.append(path)

    ## cc deps
    ## FIXME: currently we have both cc_deps dict with static/dynamic/default vals,
    ## and cc_linkall list. Replace the latter with a "static-linkall" value for the former

    ## now we need to add cc deps to the cmd line
    cclib_deps  = []
    cc_runfiles = []
    if debug:
        print("xDIRECT_CC_DEPS: %s" % direct_cc_deps)
        print("xINDIRECT_CC_DEPS: %s" % indirect_cc_deps)
    cc_deps_dict = {}
    cc_deps_dict.update(direct_cc_deps)
    cc_deps_dict.update(indirect_cc_deps)
    _handle_cc_deps(ctx, tc.linkmode,
                    cc_deps_dict,
                    args,
                    includes,
                    cclib_deps,
                    cc_runfiles)

    if debug:
        print("LBL: %s" % ctx.label)
        print("CCLIB_DEPS: %s" % cclib_deps)
        print("CC_RUNFILES: %s" % cc_runfiles)

    # for dep in ctx.attr.cc_deps.items():
    # debug = True
    # if indirect_cc_deps != None:
    #     for d in indirect_cc_deps:  ## .items():
    #         if False:
    #             print("XXXXXXXXXXXXXXXX %s" % (len(d) > 0))
    #             for dep in d.items():
    #                 if debug:
    #                     print("CCLIB DEP: ")
    #                     print(dep)
    #                 if dep[1] == "default":
    #                     ## linkmode is set by the toolchain rule
    #                     if debug:
    #                         print("LINKMODE: %s" % tc.linkmode)
    #                     for depfile in dep[0].files.to_list():
    #                         if tc.linkmode == "static":
    #                             if (depfile.extension == "a"):
    #                                 args.add(depfile)
    #                                 cclib_deps.append(depfile)
    #                                 includes.append(depfile.dirname)
    #                         else:
    #                             for depfile in dep[0].files.to_list():
    #                                 if (depfile.extension == "so"):
    #                                     libname = file_to_lib_name(depfile)
    #                                     print("so LIBNAME: %s" % libname)
    #                                     args.add("-ccopt", "-L" + depfile.dirname)
    #                                     args.add("-cclib", "-l" + libname)
    #                                     cclib_deps.append(depfile)
    #                                 elif (depfile.extension == "dylib"):
    #                                     libname = file_to_lib_name(depfile)
    #                                     # libname = depfile.basename[:-6]
    #                                     # libname = libname[3:]
    #                                     print("dylib LIBNAME: %s:" % libname)
    #                                     args.add("-cclib", "-l" + libname)
    #                                     args.add("-ccopt", "-L" + depfile.dirname)
    #                                     cclib_deps.append(depfile)
    #                                     cc_runfiles.append(dep)
    #                 elif dep[1] == "static":
    #                     if debug:
    #                         print("STATIC lib: %s:" % dep[0])
    #                     for depfile in dep[0].files.to_list():
    #                         if (depfile.extension == "a"):
    #                             args.add(depfile)
    #                             cclib_deps.append(depfile)
    #                             includes.append(depfile.dirname)
    #                 elif dep[1] == "static-linkall":
    #                     if debug:
    #                         print("STATIC LINKALL lib: %s:" % dep[0])
    #                     for depfile in dep[0].files.to_list():
    #                         if (depfile.extension == "a"):
    #                             args.add(depfile)
    #                             cclib_deps.append(depfile)
    #                             includes.append(depfile.dirname)
    #                 elif dep[1] == "dynamic":
    #                     if debug:
    #                         print("DYNAMIC lib: %s" % dep[0])
    #                     for depfile in dep[0].files.to_list():
    #                         if (depfile.extension == "so"):
    #                             libname = file_to_lib_name(depfile)
    #                             print("so LIBNAME: %s" % libname)
    #                             args.add("-ccopt", "-L" + depfile.dirname)
    #                             args.add("-cclib", "-l" + libname)
    #                             cclib_deps.append(depfile)
    #                         elif (depfile.extension == "dylib"):
    #                             libname = file_to_lib_name(depfile)
    #                             print("LIBNAME: %s:" % libname)
    #                             args.add("-cclib", "-l" + libname)
    #                             args.add("-ccopt", "-L" + depfile.dirname)
    #                             cclib_deps.append(depfile)
    #                             cc_runfiles.append(dep)

    # if hasattr(ctx.attr, "cc_linkall"):
    # dep_graph.extend(build_deps)
    # dep_graph = dep_graph + cclib_deps #  srcs_ml + outs_cmi

    args.add_all(includes, before_each="-I")

    # if ctx.attr.main == None:
    modules = depset(transitive = indirect_file_depsets).to_list()
    if len(modules) > 0:
        for m in modules:
            if m.extension in ["cmo", "cmx", "cma", "cmxa"]:
                args.add(m)

    # else:
    # # if ctx.attr.main != None:
    #     # for dep in ctx.attr.main:
    #     #     if OcamlModuleProvider in dep:
    #     #         args.add(dep[OcamlModuleProvider].module)
    #     args.add_all(ctx.attr.main[DefaultMemo].paths, before_each="-I")

    #     ## 'main' must come last! also its entire deptree must be added to cmd line
    #     for dep in ctx.files.main:
    #         ## cmi/mli already added to dep graph, but must not be added to cmd line
    #         ## FIXME: what about cmxs?
    #         if dep.extension in ["cmo", "cmx", "cma", "cmxa"]:
    #             args.add(dep)

    # if ctx.attr.cc_linkopts:
    #     args.add_all(ctx.attr.cc_linkopts, before_each="-ccopt")

    # args.add_all(link_search, before_each="-ccopt", uniquify = True)
    # args.add_all(dynamic_libs, before_each="-cclib", uniquify = True)

          ## opam deps are just strings, we feed them to ocamlfind, which finds the file.
          ## this means we cannot add them to the dep_graph.
          ## this makes sense, the exe we build does not depend on these,
          ## it's the subsequent transform that depends on them.
      # else:
      #     dep_graph.append(dep)
      #FIXME: also support non-opam transform deps

    args.add("-o", outbinary)

    ## runtime deps go in ctx.runfiles
    ## FIXME: use runfiles to support dylib on macos?
    # if ctx.attr.strip_data_prefixes:
    #   myrunfiles = ctx.runfiles(
    #     files = ctx.files.data + cc_runfiles,
    #     symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
    #   )
    # else:
    #     print("FILES.DATA: %s" % ctx.files.data)
    #     print("CC_RUNFILES: %s" % cc_runfiles)
    #     myrunfiles = ctx.runfiles(
    #         transitive_files = depset(direct=ctx.files.data, transitive = cc_runfiles)
    #     )

    # for dep in cc_runfiles:
    #     print("RUNFILE: %s" % dep.path)
        # myrunfiles.merge(dep)

    input_depset = depset(
        direct = direct_file_deps + cclib_deps,
        transitive = indirect_file_depsets
    )

    ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args],
      inputs = input_depset,
      outputs = [outbinary],
      tools = [tc.ocamlfind, tc.ocamlopt], # tc.opam,
      mnemonic = "OcamlExecutable" if ctx.attr._rule == "ocaml_executable" else "PpxExecutable",
      progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
          mode = mode,
          rule = ctx.attr._rule,
          ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
          pkg = ctx.label.package,
          tgt = ctx.label.name,
        )
    )

    defaultInfo = DefaultInfo(
        executable=outbinary,
        # runfiles = myrunfiles
    )

    nopam_direct_paths = []
    for dep in ctx.files.deps_adjunct:
        nopam_direct_paths.append(dep.dirname)
    nopam_paths = depset(direct = nopam_direct_paths,
                         transitive = indirect_adjunct_path_depsets)

    adjuncts_provider = AdjunctDepsProvider(
        opam = depset(
            direct     = ctx.attr.deps_adjunct_opam,
            transitive = indirect_adjunct_opam_depsets
        ),
        nopam = depset(
            direct     = ctx.attr.deps_adjunct,
            transitive = indirect_adjunct_depsets
        ),
        nopam_paths = nopam_paths
    )
    # print("TGT: %s" % ctx.label.name)
    # print("ADJUNCT P: %s" % adjuncts_provider)

    exe_provider = None
    if ctx.attr._rule == "ppx_executable":
        exe_provider = PpxExecutableProvider(
            args = ctx.attr.args
        )
    elif ctx.attr._rule == "ocaml_executable":
        exe_provider = OcamlExecutableProvider()
    else:
        fail("Wrong rule called impl_executable: %s" % ctx.attr._rule)

    results = [
        defaultInfo,
        adjuncts_provider,
        exe_provider
    ]

    # if ctx.attr._rule == "ppx_executable":
    #     provider = PpxExecutableProvider(
    #         payload = outbinary,
    #         args = depset(direct = ctx.attr.args),
    #         deps = struct(
    #             # opam = mydeps.opam,
    #             # opam_adjunct = mydeps.opam_adjunct,
    #             # opam_adjunct = depset(direct = opam_adjunct_deps),
    #             # nopam = mydeps.nopam,
    #             # nopam_adjunct = mydeps.nopam_adjunct
    #             # nopam_adjunct = depset(direct = nopam_adjunct_deps)
    #           )
    #     )
    #     results = [
    #         defaultInfo,
    #         provider
    #     ]

    # elif ctx.attr._rule == "ocaml_executable":
    #     results = [
    #         defaultInfo,
    #         adjuncts_provider
    #     ]

    if debug:
        print("IMPL_EXECUTABLE RESULTS:")
        print(results)

    return results
