load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "CompilationModeSettingProvider",

     "AdjunctDepsMarker",
     "OcamlArchiveMarker",
     "OcamlExecutableMarker",
     "OcamlModuleMarker",
     # "OcamlPathsMarker",
     "OcamlSDK",
     "OcamlTestMarker",
     "PpxExecutableMarker",
     "PpxModuleMarker"
)

load(":impl_ccdeps.bzl", "handle_ccdeps")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name",
)

load(":options.bzl", "options")

load(":impl_common.bzl", "dsorder", "merge_deps", "opam_lib_prefix")

################################################################
def _handle_cc_deps(ctx,
                    default_linkmode,
                    cc_deps_dict, ## list of dicts
                    args,
                    includes,
                    cclib_deps,
                    cc_runfiles):

    ## FIXME: static v. dynamic linking of cc libs in bytecode mode
    # see https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss%3Adynlink-c-code

    # default linkmode for toolchain is determined by platform
    # see @ocaml//toolchain:BUILD.bazel, ocaml/_toolchains/*.bzl
    # dynamic linking does not currently work on the mac - ocamlrun
    # wants a file named 'dllfoo.so', which rust cannot produce. to
    # support this we would need to rename the file using install_name_tool
    # for macos linkmode is dynamic, so we need to override this for bytecode mode

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
                if debug:
                    print("CCDEP DUP? %s" % dep)
            else:
                ccdeps.update({dep: linkmode})

    for [dep, linkmode] in cc_deps_dict.items():
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
                            args.add("-ccopt", "-L" + depfile.dirname)
                            args.add("-cclib", "-l" + libname)
                            cclib_deps.append(depfile)
                        elif (depfile.extension == "dylib"):
                            libname = file_to_lib_name(depfile)
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
                    if ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"].cc_toolchain == "clang":
                        args.add("-ccopt", "-Wl,-force_load,{path}".format(path = depfile.path))
                    elif ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"].cc_toolchain == "gcc":
                        libname = file_to_lib_name(depfile)
                        args.add("-ccopt", "-L{dir}".format(dir=depfile.dirname))
                        args.add("-ccopt", "-Wl,--push-state,-whole-archive")
                        args.add("-ccopt", "-l{lib}".format(lib=libname))
                        args.add("-ccopt", "-Wl,--pop-state")
                    else:
                        fail("NO CC")

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
    # if ctx.label.name == "test":
        # debug = True

    print("%%%% EXECUTABLE {} %%%%".format(ctx.label))

    if debug:
        print("EXECUTABLE TARGET: {kind}: {tgt}".format(
            kind = ctx.attr._rule,
            tgt  = ctx.label.name
        ))

    # OCAMLFIND_IGNORE = ""
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif/c"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"

    env = {
        "OPAMROOT": get_opamroot(),
        "PATH": get_sdkpath(ctx),
        # "OCAMLFIND_IGNORE_DUPS_IN": OCAMLFIND_IGNORE
    }

    ## FIXME: support ctx.attr.mode?
    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    # if len(ctx.attr.deps_opam) > 0:
    #     using_ocamlfind = True
    #     ocamlfind_opts = ["-predicates", "ppx_driver"]
    #     exe = tc.ocamlfind
    # else:
    # using_ocamlfind = False
    # ocamlfind_opts = []
    if mode == "native":
        exe = tc.ocamlopt.basename
    else:
        exe = tc.ocamlc.basename

    ## FIXME: default extension to .out?

    ################
    # merged_module_links_depsets = []
    # merged_archive_links_depsets = []

    # merged_paths_depsets = []
    # merged_depgraph_depsets = []
    # merged_archived_modules_depsets = []

    # indirect_opam_depsets = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    # indirect_adjunct_opam_depsets = []

    direct_cc_deps    = {}
    direct_cc_deps.update(ctx.attr.cc_deps)
    indirect_cc_deps  = {}

    ################
    includes  = []
    cmxa_args  = []

    out_exe = ctx.actions.declare_file(ctx.label.name)

    #########################
    args = ctx.actions.args()

    # if using_ocamlfind:
    #     if mode == "native":
    #         args.add(tc.ocamlopt.basename)
    #     else:
    #         args.add(tc.ocamlc.basename)

    if mode == "bytecode":
        ## FIXME: -custom only needed if linking with CC code?
        ## see section 20.1.3 at https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#s%3Ac-overview
        args.add("-custom")

    # if ctx.attr._threads:
    #     print("THREADS - ADDING ARGS")
    #     args.add("-I", "+threads")

    _options = get_options(rule, ctx)
    args.add_all(_options, uniquify=True)

    # args.add_all(ocamlfind_opts, uniquify=True)

    mdeps = []
    if ctx.attr.deps != None:
        mdeps.extend(ctx.attr.deps)
    # print("MDEPS 1: %s" % mdeps)

    # if OcamlModuleMarker in ctx.attr.main:
    #     for dep in ctx.attr.main[DefaultInfo].files.to_list():
    #         print("123DefaultInfo dep: %s" % dep)
    #     for dep in ctx.attr.main[OcamlModuleMarker].module_links.to_list():
    #         print("123 moduleMarker.module_link: %s" % dep)
    #     for dep in ctx.attr.main[OcamlModuleMarker].archive_links.to_list():
    #         print("123 moduleMarker.archive_link: %s" % dep)

    # if ctx.attr.main != None:
    #     mdeps.append(ctx.attr.main)
    # print("MDEPS 2: {tgt} MAIN: {mdeps}".format(
    #     tgt=ctx.label.name, mdeps=mdeps))

    # merge_deps(mdeps,
    #            merged_module_links_depsets,
    #            merged_archive_links_depsets,
    #            merged_paths_depsets,
    #            merged_depgraph_depsets,
    #            merged_archived_modules_depsets,
    #            # indirect_opam_depsets,
    #            indirect_adjunct_depsets,
    #            indirect_adjunct_path_depsets,
    #            # indirect_adjunct_opam_depsets,
    #            indirect_cc_deps)

    # print("EXEC {m} MODULE_LINKS_DEPSETS: {ds}".format(
    #     m = ctx.label, ds = merged_module_links_depsets))

    # print("merged_module_links_depsets:\n")
    # for dep in depset(transitive=merged_module_links_depsets).to_list():
    #     # print("\tBBBBBBBBBBBBBBBB%s" % dep)
    #     includes.append(dep.dirname)

    # print("merged_archive_links_depsets:\n")
    # for dep in depset(transitive=merged_archive_links_depsets).to_list():
    #     print("arch\t%s" % dep)

    ##print("merged_paths_depsets,
    # print("merged_depgraph_depsets: \n%s" % merged_depgraph_depsets)
    # print("merged_archived_modules_depsets: \n%s" % merged_archived_modules_depsets)

    # indirect_adjunct_depsets,
    # indirect_adjunct_path_depsets,
    # indirect_cc_deps

    # opam_depset = depset(direct = ctx.attr.deps_opam,
    #                      transitive = indirect_opam_depsets)
    # opams = opam_depset.to_list()
    # if using_ocamlfind:
    #     if len(opams) > 0:
    #         args.add("-linkpkg")  ## tell ocamlfind to add cmxa files to cmd line
    #         [args.add("-package", opam) for opam in opams if opams] ## add dirs to search path

    # if not using_ocamlfind:

    # if ctx.attr._threads:
    #     if mode == "native":
    #         # args.add("unix.cmxa")
    #         args.add("threads.cmxa")
    #     else:
    #         args.add("unix.cma")
    #         args.add("threads.cma")

    # imports_test = depset(transitive = merged_depgraph_depsets)
    # modules_depslist = depset(transitive = merged_module_links_depsets)
    # archives_depslist = depset(transitive = merged_archive_links_depsets)

    # for f in archives_depslist.to_list(): # + modules_depslist.to_list():
    #     # FIXME: only relativize ocaml_imports
    #     # print("relativizing %s" % f.path)
    #     if f.extension in ["cmxa", "cmx"]: # , "a"]:

    #         cmxa_args.append(f.basename)
    #         ## problem is ocaml compilers will not follow symlinks
    #         ## so we need abs paths
    #         if f.path.startswith(opam_lib_prefix):
    #             dir = paths.relativize(f.dirname, opam_lib_prefix)
    #             includes.append( "+../" + dir )
    #         else:
    #             includes.append( f.dirname )
    #             ## don't do this for ocaml_test?
    #             # args.add(f.path)
    # # else:
    # #     paths_depset = depset(transitive = merged_paths_depsets)
    # #     for path in paths_depset.to_list():
    # #         includes.append(path)
    # #         if f.extension in ["cmxa"]:
    # #             args.add(f.path)

    # # module deps added below...

    ## now we need to add cc deps to the cmd line
    cclib_deps  = []
    cc_runfiles = []
    cc_deps_dict = {}
    cc_deps_dict.update(direct_cc_deps)
    cc_deps_dict.update(indirect_cc_deps)
    _handle_cc_deps(ctx, tc.linkmode,
                    cc_deps_dict,
                    args,
                    includes,
                    cclib_deps,
                    cc_runfiles)

    if "-g" in _options:
        args.add("-runtime-variant", "d") # FIXME: verify compile built for debugging

    args.add("-absname")
    ################################################################
    [
        action_inputs_ccdep_filelist, ccDepsProvider
     ] = handle_ccdeps(ctx,
                     # True if ctx.attr.pack else False,
                    tc.linkmode,
                     # cc_deps_dict,
                    args,
                     # includes,
                     # cclib_deps,
                     # cc_runfiles)
                  )
    print("CCDEPS INPUTS: %s" % action_inputs_ccdep_filelist)

    ################################################################
    all_deps_list = []
    main_deps_list = []
    paths_direct   = []
    paths_indirect = []

    for dep in ctx.attr.deps:
        # print("MDEP: {host} => {d}".format(host=ctx.label, d = dep.label))

        ################ OCamlMarker ################
        if OcamlProvider in dep:
            all_deps_list.append(dep[OcamlProvider].files)
            paths_indirect.append(dep[OcamlProvider].paths)

        # ################ Paths ################
        # if OcamlPathsMarker in dep:
        #     ps = dep[OcamlPathsMarker].paths
        #     # print("MPATHS: %s" % ps)
        #     paths_indirect.append(ps)

        # ################ Archive Deps ################
        # if OcamlArchiveMarker in dep:
        #     all_deps_list.append(dep[OcamlArchiveMarker].files)
        #     # all_deps_list.append(dep[OcamlArchiveMarker].subdeps)

        #     # archive_list = dep[OcamlArchiveMarker].archive
        #     # print("  OAP.archive %s" % archive_list)
        #     # this_archivedeps_archive_file_list.extend(archive_list)
        #     all_deps_list.append(depset(order = dsorder,
        #                                 direct=dep[OcamlArchiveMarker].archive,
        #                                 transitive=[dep[OcamlArchiveMarker].subdeps]))

        #     # components = dep[OcamlArchiveMarker].components
        #     # print("  OAP.components %s" % components)
        #     # this_archivedeps_components_depset_list.append(components)
        #     # archive already contains components
        #     # all_deps_list.append(dep[OcamlArchiveMarker].components)

        #     # subdeps = dep[OcamlArchiveMarker].subdeps
        #     # print("  OAP.subdeps %s" % subdeps)
        #     # this_archivedeps_subdeps_depset_list.append(subdeps)
        #     all_deps_list.append(dep[OcamlArchiveMarker].subdeps)

        # ################ module deps ################
        # if OcamlModuleMarker in dep:
        #     all_deps_list.append(dep[OcamlModuleMarker].files)
        #     # sigs = dep[OcamlModuleMarker].sigs
        #     # print("  OMP.sigs %s" % sigs)
        #     # this_sigdeps_depset_list.append(sigs)

        #     # deps = dep[OcamlModuleMarker].deps
        #     # print("  OMP.deps %s" % deps)
        #     # this_module_deps_depset_list.append(deps)
        #     # all_deps_list.append(dep[OcamlModuleMarker].deps)

        #     # subdeps = dep[OcamlModuleMarker].subdeps
        #     # print("  OMP.subdeps %s" % subdeps)
        #     # this_module_subdeps_depset_list.append(subdeps)
        #     # deps already contains subdeps
        #     # all_deps_list.append(dep[OcamlModuleMarker].subdeps)

    # for f in ctx.attr.main[OcamlProvider].files: # .to_list():
    #     print(" MAINDEP: %s" % f)
    all_deps_list.append(ctx.attr.main[OcamlProvider].files)

    paths_indirect.append(ctx.attr.main[OcamlProvider].paths)
        ################ OCamlMarker ################
        # if OcamlProvider in dep:
        #     main_deps_list.append(dep[OcamlProvider].files)
        #     paths_indirect.append(dep[OcamlProvider].paths)

    paths_depset  = depset(
        order = dsorder,
        # direct = paths_direct,
        transitive = paths_indirect
    )

    args.add_all(paths_depset.to_list(), before_each="-I")

    all_deps = depset(
        order = dsorder,
        direct = ctx.files.main,
        transitive = all_deps_list
        # transitive =[
        #     this_module_deps_depset,
        #     this_module_subdeps_depset,
        #     this_archivedeps_archives_depset,
        #     this_archivedeps_subdeps_depset
        # ]
    )
    # print("ALL_DEPS for MODULE %s" % ctx.label)
    # for d in reversed(all_deps.to_list()):
    for d in all_deps.to_list():
        # print("ALL_DEPS: %s" % d)
        # if d.extension != "cmi":
        # if d.path.startswith(opam_lib_prefix):
        #     dir = paths.relativize(d.dirname, opam_lib_prefix)
        #     # includes.append( "+../" + dir )
        #     args.add("-I", "+../" + dir )
        # else:
        #     # includes.append(d.dirname)
        #     args.add("-I", d.dirname)
        if d.extension not in ["a", "o", "cmi", "mli", "ml"]:
            # if d.basename != "Embedded_cmis.cmx":
            args.add(d.path) #basename)

    args.add("-absname")

    ################################################################
    ################################################################

    # for dset in indirect_adjunct_depsets:
    #     for f in dset.to_list():
    #         if f.extension in ["cmxa", "cmx"]:
    #             args.add(f)
    #         if f.path.startswith(opam_lib_prefix):
    #             dir = paths.relativize(f.dirname, opam_lib_prefix)
    #             includes.append( "+../" + dir )
    #         else:
    #             includes.append( f.dirname )

    args.add_all(includes, before_each="-I", uniquify=True)

    # args.add_all(cmxa_args, uniquify=True)

    ## FIXME: includes contains dups, why?
    # args.add("-absname")
    ## use depsets to get the right ordering. archive and module links are mutually exclusive.
    # links = depset(order = dsorder, transitive = merged_module_links_depsets).to_list()
    # ### cmxa deps added below w/p dirpath
    # if len(links) > 0:
    #     for m in links:
    #         # FIXME: merged_module_links_depset should not contain any
    #         # archives, but it does, so:
    #         if m.extension not in ["cmi", "mli", "o"]:
    #             args.add(m.basename)
    #         includes.append(m.dirname)

    ## FIXME: detect dup between main and deps
    # if ctx.attr.main != None:
    #     for f in ctx.attr.main.files.to_list():
    #         if f.extension in ["cmx", "o"]:
    #             cclib_deps.append(f)
    #         if f.extension in ["cmx"]:
    #             args.add("-I", f.dirname)
                # args.add("-I", f.dirname + "/__obazl")
                # args.add(f.path)

    args.add("-o", out_exe)

    # print("EXE TRANS {} XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX".format(ctx.label))

    # print("merged_depgraph_depsets %s" % merged_depgraph_depsets)
    # print("merged_module_links_depsets: %s" % merged_module_links_depsets)
    # print("merged_archive_links_depsets: %s" % merged_archive_links_depsets)
    # print("merged_archived_modules_depsets: %s" % merged_archived_modules_depsets)

    # inputs_depset = depset(
    #     order = dsorder,
    #     direct = cclib_deps,
    #     transitive = merged_depgraph_depsets
    #     + merged_module_links_depsets
    #     + merged_archive_links_depsets
    #     + merged_archived_modules_depsets
    #     + indirect_adjunct_depsets
    #     + [all_deps]
    # )
    inputs_depset = depset(
        transitive = [all_deps, depset(action_inputs_ccdep_filelist)]
    )

    if ctx.attr._rule == "ocaml_executable":
        mnemonic = "CompileOcamlExecutable"
    elif ctx.attr._rule == "ppx_executable":
        mnemonic = "CompilePpxExecutable"
    elif ctx.attr._rule == "ocaml_test":
        mnemonic = "CompileOcamlTest"
    else:
        fail("Unknown rule for executable: %s" % ctx.attr._rule)

    ################
    ctx.actions.run(
      env = env,
      executable = exe, ## tc.ocamlfind,
      arguments = [args],
      inputs = inputs_depset,
      outputs = [out_exe],
      tools = [tc.ocamlopt],  # tc.ocamlfind, 
      mnemonic = mnemonic,
      progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
          mode = mode,
          rule = ctx.attr._rule,
          ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
          pkg = ctx.label.package,
          tgt = ctx.label.name,
        )
    )
    ################
    ################

    ## FIXME: verify correctness
    if ctx.attr.strip_data_prefixes:
      myrunfiles = ctx.runfiles(
        files = ctx.files.data,
        symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
      )
    else:
        myrunfiles = ctx.runfiles(
            files = ctx.files.data,
        )

    ##########################
    defaultInfo = DefaultInfo(
        executable=out_exe,
        runfiles = myrunfiles
    )

    ## src files depend on the ppx executable we're compiling
    ## so we need to pass adjunct deps
    ppx_adjuncts_direct_paths = []
    for dep in ctx.files.deps_adjunct:
        ppx_adjuncts_direct_paths.append(dep.dirname)
    ppx_adjuncts_paths = depset(direct = ppx_adjuncts_direct_paths,
                         #transitive = indirect_adjunct_path_depsets
                         )

    ppx_adjuncts_depset = depset(
        # direct     = ctx.attr.deps_adjunct,
            direct     = ctx.files.deps_adjunct,
        transitive = indirect_adjunct_depsets
    )

    # print("INDIRECT_ADJUNCTS: %s" % indirect_adjunct_depsets)
    # print("DEPS_ADJUNCTS: %s" % ctx.files.deps_adjunct)
    adjuncts_provider = AdjunctDepsMarker(
        # opam = depset(
        #     direct     = ctx.attr.deps_adjunct_opam,
        #     transitive = indirect_adjunct_opam_depsets
        # ),
        nopam = ppx_adjuncts_depset,
        nopam_paths = ppx_adjuncts_paths
    )
    # print("EXE {m} adjuncts provider: {p}".format(m=ctx.label, p = adjuncts_provider))

    ## Marker provider
    exe_provider = None
    if ctx.attr._rule == "ppx_executable":
        exe_provider = PpxExecutableMarker(
            args = ctx.attr.args
        )
    elif ctx.attr._rule == "ocaml_executable":
        exe_provider = OcamlExecutableMarker()
    elif ctx.attr._rule == "ocaml_test":
        exe_provider = OcamlTestMarker()
    else:
        fail("Wrong rule called impl_executable: %s" % ctx.attr._rule)

    outputGroupInfo = OutputGroupInfo(
        # modules  = depset(transitive=merged_module_links_depsets),
        # archives = depset(transitive=merged_archived_modules_depsets),
        # depgraph = depset(transitive=merged_depgraph_depsets),
        # archived_modules = depset(transitive=merged_archived_modules_depsets),
        ppx_adjuncts = ppx_adjuncts_depset,
        cclibs = cclib_deps,
        all_files = depset(transitive=[
            # depset(transitive=merged_module_links_depsets),
            # depset(transitive=merged_archived_modules_depsets),
            # depset(transitive=merged_depgraph_depsets),
            # depset(transitive=merged_archived_modules_depsets),
            ppx_adjuncts_depset,
            depset(cclib_deps),
        ])
    )

    results = [
        defaultInfo,
        outputGroupInfo,
        adjuncts_provider,
        exe_provider
    ]
    # print("XXXXXXXXXXXXXXXX adjuncts_provider: %s" % adjuncts_provider)

    return results
