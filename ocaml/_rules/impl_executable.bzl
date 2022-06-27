load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlExecutableMarker",
     "OcamlImportMarker",
     "OcamlModuleMarker",
     "OcamlTestMarker",
)

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
     "PpxExecutableMarker",
)

load(":impl_ccdeps.bzl", "extract_cclibs", "dump_CcInfo")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

# load("//ocaml/_functions:utils.bzl", "get_sdkpath")

load("//ocaml/_functions:module_naming.bzl", "file_to_lib_name")

load(":options.bzl", "options")

load(":impl_common.bzl", "dsorder", "opam_lib_prefix",
     "tmpdir"
     )

load("//ocaml/_debug:utils.bzl", "CCRED", "CCMAG", "CCRESET")

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

workdir = tmpdir

###############################
def _get_cc_toolchain_deps(ctx):
    cctc = find_cpp_toolchain(ctx)
    print("cctc type: %s" % type(cctc))
    print("cctc: %s" % cctc)
    items = dir(cctc)
    for item in items:
        print(CCRED + "  %s" % item)

    return [cctc.all_files]

#########################
def _import_ppx_executable(ctx):

    binout = ctx.actions.declare_file(
        workdir + ctx.file.bin.basename
    )
    ctx.actions.symlink(output = binout,
                        target_file = ctx.file.bin)

    defaultInfo = DefaultInfo(
        executable=binout
    )

    exe_provider = PpxExecutableMarker(
        args = ctx.attr.args
    )
    providers = [
        defaultInfo,
        exe_provider
    ]
    return providers

#########################
def impl_executable(ctx, mode, tc, tool, tool_args):

    debug     = False
    debug_cc  = True
    debug_ppx = True

    if debug or debug_ppx:
        print("EXECUTABLE TARGET: {kind}: {tgt}".format(
            kind = ctx.attr._rule,
            tgt  = ctx.label.name
        ))

    if hasattr(ctx.attr, "bin"):
        if ctx.attr.bin:
            if debug_ppx: print("importing precompiled ppx executable: %s" % ctx,attr.bin)
            ## precompiled executable
            return _import_ppx_executable(ctx)

    if mode == "native":
        struct_extensions = ["cmxa", "cmx"]
    else:
        struct_extensions = ["cma", "cmo"]

    # env = {
    #     "PATH": get_sdkpath(ctx),
    # }

    # direct file deps of this target
    # we don't use the directs but we need the data type instead of None
    sigs_primary             = []
    structs_primary          = []
    ofiles_primary           = []  # .o files
    archives_primary         = []
    afiles_primary           = []  # .a files
    astructs_primary         = []
    # cclibs_primary         = []
    cmts_primary             = []
    paths_primary   = []

    # depsets from 'deps' attribute:
    sigs_secondary           = []
    structs_secondary        = []
    ofiles_secondary         = []  # .o files
    archives_secondary       = []
    afiles_secondary         = []  # .a files
    astructs_secondary       = []
    # cclibs_secondary       = []
    paths_secondary = []

    codep_sigs_primary       = []
    codep_structs_primary    = []
    codep_ofiles_primary     = []
    codep_archives_primary   = []
    codep_afiles_primary     = []
    codep_astructs_primary   = []
    # codep_cclibs_primary   = []
    codep_paths_primary      = []

    codep_sigs_secondary     = []
    codep_structs_secondary  = []
    codep_ofiles_secondary   = []
    codep_archives_secondary = []
    codep_afiles_secondary   = []
    codep_astructs_secondary = []
    # codep_cclibs_secondary = []
    codep_paths_secondary    = []

    ################
    direct_cc_deps    = {}
    direct_cc_deps.update(ctx.attr.cc_deps)
    indirect_cc_deps  = {}

    ################
    includes   = []

    out_exe = ctx.actions.declare_file(ctx.label.name)

    #########################
    args = ctx.actions.args()

    args.add_all(tool_args)

    if "ppx" in ctx.attr.tags:
        print("PPX in tags XXXXXXXXXXXXXXXX");

    _options = get_options(rule, ctx)
    # print("OPTIONS: %s" % _options)
    # do not uniquify options, it collapses all -I
    args.add_all(_options)

    if "-g" in _options:
        args.add("-runtime-variant", "d") # FIXME: verify compile built for debugging

    ################################################################
                   ####    DEPENDENCIES    ####
    ################################################################
    # main_deps_list = []

    # direct_ppx_codep_depsets = []
    # direct_ppx_codep_depsets_paths = []
    # indirect_ppx_codep_depsets      = []
    # indirect_ppx_codep_depsets_paths = []
    # ppx_codep_linksets = []
    # ppx_codep_cdeps = []
    # ppx_codep_ldeps = []

    # direct_inputs_depsets = []
    # direct_linkargs_depsets = []
    # direct_paths_depsets = []

    stublibs_list = []

    # sigs_depsets = []
    # structs_depsets = []
    # direct file deps of this target
    # sigs_primary             = []
    # structs_primary          = []
    # ofiles_primary           = []
    # archives_primary         = []
    # afiles_primary           = []
    # astructs_primary        = []

    # # depsets from 'deps' attribute:
    # sigs_secondary           = []
    # structs_secondary        = []
    # ofiles_secondary         = []
    # archives_secondary       = []
    # afiles_secondary         = []
    # astructs_secondary       = []

    ################ SECONDARY DEPENDENCIES ################
    if debug: print("iterating deps")
    for dep in ctx.attr.deps:
        if debug:
            print("DEP: %s" % dep)
            if OcamlProvider in dep:
                print("dep[OcamlProvider] %s" % dep[OcamlProvider])
            if OcamlImportMarker in dep:
                print("dep[OcamlImportMarker] %s" % dep[OcamlImportMarker])

        if CcInfo in dep:
            # print("CcInfo dep: %s" % dep)
            stublibs_list.append(dep[CcInfo])

        if OcamlProvider in dep:
            provider = dep[OcamlProvider]
            sigs_secondary.append(provider.sigs)
            structs_secondary.append(provider.structs)
            ofiles_secondary.append(provider.ofiles)
            archives_secondary.append(provider.archives)
            afiles_secondary.append(provider.afiles)
            astructs_secondary.append(provider.astructs)
            # cclibs_secondary.append(provider.cclibs)


            # direct_inputs_depsets.append(provider.ldeps) # inputs)
            # direct_linkargs_depsets.append(provider.linkargs)
            # direct_paths_depsets.append(provider.paths)
            paths_secondary.append(provider.paths)

            # direct_linkargs_depsets.append(dep[DefaultInfo].files)

        ################ PpxCodepsProvider ################
        ## only for ocaml_imports listed in deps, not ppx_codeps
        if PpxCodepsProvider in dep:
            provider = dep[PpxCodepsProvider]
            if debug_ppx:
                print("PpxCodepsProvider carrier: %s" % dep)
            # if hasattr(ppxcdp, "ppx_codeps"):
            #     if ppxcdp.ppx_codeps:
            #         indirect_ppx_codep_depsets.append(ppxcdp.ppx_codeps)

            sigs_secondary.append(provider.sigs)
            structs_secondary.append(provider.structs)
            ofiles_secondary.append(provider.ofiles)
            archives_secondary.append(provider.archives)
            # afiles_secondary.append(provider.afiles)
            astructs_secondary.append(provider.astructs)
            # cclibs_secondary.append(provider.cclibs)
            paths_secondary.append(provider.paths)

            # if hasattr(provider, "paths"):
            #     if provider.paths:
            #         path_depsets.append(provider.paths)
            #         indirect_ppx_codep_depsets_paths.append(provider.paths)
            # if hasattr(ppxcdp, "cdeps"):
            #     if ppxcdp.cdeps:
            #         ppx_codep_cdeps.append(ppxcdp.cdeps)
            # if hasattr(ppxcdp, "ldeps"):
            #     if ppxcdp.ldeps:
            #         ppx_codep_ldeps.append(ppxcdp.ldeps)

    if debug:
        print("finished deps iteration")
        print("sigs_primary: %s" % sigs_primary)
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_primary: %s" % structs_primary)
        print("structs_secondary: %s" % structs_secondary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        ## archives cannot be direct deps
        print("archives_primary: %s" % archives_primary)
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_primary: %s" % afiles_primary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("astructs_primary: %s" % astructs_primary)
        print("astructs_secondary: %s" % astructs_secondary)
        # print("cclibs_primary: %s" % astructs_primary)
        # print("cclibs_secondary: %s" % astructs_secondary)

    action_inputs_ccdep_filelist = []
    manifest_list = []

    if ctx.attr._rule == "ppx_executable":
        if ctx.attr.ppx_codeps:
            for dep in ctx.attr.ppx_codeps:
                if debug_ppx:
                    print("attr.ppx_codep: %s" % dep)
                    print("dep[OcamlImportMarker: %s" %
                          dep[OcamlImportMarker])
                    print("dep[OcamlProvider]: %s" % dep)

                codep = dep[OcamlProvider];
                codep_sigs_secondary.append(codep.sigs)
                codep_structs_secondary.append(codep.structs)
                codep_archives_secondary.append(codep.archives)
                codep_astructs_secondary.append(codep.astructs)
                codep_ofiles_secondary.append(codep.ofiles)
                codep_afiles_secondary.append(codep.afiles)
                codep_paths_secondary.append(codep.paths)

                # NB: codep[OcamlProvider]linkargs insufficient, it only
                # contains archive files, for linking executables.
                # We will need to list all modules as inputs
                # ppx_codep_linksets.append(codep[OcamlProvider].linkargs)
                # indirect_ppx_codep_depsets.append(codep[OcamlProvider].inputs)

                # codep_paths.append(codep

                # indirect_ppx_codep_depsets_paths.append(codep[OcamlProvider].paths)

                # ppx_codep_cdeps.append(codep[OcamlProvider].cdeps)
                # ppx_codep_ldeps.append(codep[OcamlProvider].ldeps)

    # print("LDEPS: %s" % ppx_codep_ldeps)

    ################################################################
    #### MAIN ####
    if debug: print("processinng 'main' attribute")
    if ctx.attr.main:
        main = ctx.attr.main

        if CcInfo in main: # [0]:
            # print("CcInfo main: %s" % main[0][CcInfo])
            stublibs_list.append(main[CcInfo]) # [0][CcInfo])

        # if OcamlProvider in main:
        #     if hasattr(main[0][OcamlProvider], "archive_manifests"):
        #         manifest_list.append(main[0][OcamlProvider].archive_manifests)

        # mainop = main[0][OcamlProvider] # int index if transition fn
        mainop = main[OcamlProvider]
        sigs_secondary.append(mainop.sigs)
        structs_secondary.append(mainop.structs)
        ofiles_secondary.append(mainop.ofiles)
        archives_secondary.append(mainop.archives)
        afiles_secondary.append(mainop.afiles)
        astructs_secondary.append(mainop.astructs)
        # structs_depsets.append(main[DefaultInfo].files)

        # direct_inputs_depsets.append(mainop.ldeps) # inputs)
        # direct_linkargs_depsets.append(mainop.linkargs)
        # direct_paths_depsets.append(mainop.paths)

        # direct_linkargs_depsets.append(main[DefaultInfo].files)

        paths_secondary.append(mainop.paths)

    ## end ctx.attr.main handling
    if debug:
        print("finished 'main' handling")
        print("sigs_primary: %s" % sigs_primary)
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_primary: %s" % structs_primary)
        print("structs_secondary: %s" % structs_secondary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        ## archives cannot be direct deps
        print("archives_primary: %s" % archives_primary)
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_primary: %s" % afiles_primary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("astructs_primary: %s" % astructs_primary)
        print("astructs_secondary: %s" % astructs_secondary)


    if debug:
        print("finished 'main' handling")
        print("sigs_primary: %s" % sigs_primary)
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_primary: %s" % structs_primary)
        print("structs_secondary: %s" % structs_secondary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        ## archives cannot be direct deps
        print("archives_primary: %s" % archives_primary)
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_primary: %s" % afiles_primary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("astructs_primary: %s" % astructs_primary)
        print("astructs_secondary: %s" % astructs_secondary)


    if debug:
        print("finished 'main' handling")
        print("sigs_primary: %s" % sigs_primary)
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_primary: %s" % structs_primary)
        print("structs_secondary: %s" % structs_secondary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        ## archives cannot be direct deps
        print("archives_primary: %s" % archives_primary)
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_primary: %s" % afiles_primary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("astructs_primary: %s" % astructs_primary)
        print("astructs_secondary: %s" % astructs_secondary)

    merged_manifests = depset(transitive = manifest_list)
    archive_filter_list = merged_manifests.to_list()
    # print("Merged manifests: %s" % archive_filter_list)

    ################
    paths_depset  = depset(
        order = dsorder,
        direct = paths_primary,
        transitive = paths_secondary
    )

    # args.add_all(paths_depset.to_list(), before_each="-I")
    includes.extend(paths_depset.to_list())

    # linkargs_depset = depset(
    #     transitive = direct_linkargs_depsets
    # )
    # direct_inputs_depset = depset(
    #     transitive = direct_inputs_depsets
    # )

    # args.add("external/ounit2/oUnit2.cmx")

    ## Archives containing deps needed by direct deps or main must be
    ## on cmd line.  FIXME: how to include only those actually needed?

    # for dep in linkargs_depset.to_list():
    #     print("LINKARG: %s" % dep)
    #     if dep not in archive_filter_list:
    #         includes.append(dep.dirname)
    #     # if mode == "native":
    #     #     if dep.extension in ["cmx", "cmxa"]:
    #     #         args.add(dep)
    #     # elif mode == "bytecode":
    #     #     if dep.extension in ["cmo", "cma"]:
    #     #         args.add(dep)
    #     print("STRUCTEXT: %s" % struct_extensions);
    #     print("DEP.EXT: %s" % dep.extension)
    #     if dep.extension in struct_extensions:
    #         print("ADDING: %s" % dep)
    #         args.add(dep)

    # if debug_ppx:
    #     print("ARCHIVES_PRIMARY: %s" % archives_primary)
    #     print("ARCHIVES_SECONDARY: %s" % archives_secondary)
    #     print("ASTRUCTS_PRIMARY: %s" % astructs_primary)
    #     print("ASTRUCTS_SECONDARY: %s" % len(astructs_secondary))
        # for x in astructs_secondary:
        #     print ("x type: %s" % type(x))
        #     for item in x.to_list():
        #         print("t: %s" % type(item))
        #         # if type(item) != "File":
        #         print("item: %s" % item)

    astructs_depset = depset(order=dsorder,
                            # direct=astructs_primary,
                            transitive=astructs_secondary)

    # for struct in astructs_depset.to_list():
    #     print("ADDING ARSTRUCT %s" % struct)
    #     args.add(struct)

    archives_depset = depset(order=dsorder,
                             direct=archives_primary,
                             transitive=archives_secondary)

    for archive in archives_depset.to_list():
        if debug:
            print("ADDING ARCHIVE %s" % archive)
        args.add(archive)

    structs_depset = depset(order=dsorder,
                            direct=structs_primary,
                            transitive=structs_secondary)

    for struct in structs_depset.to_list():
        if debug:
            print("ADDING STRUCT %s" % struct)
        args.add(struct)

    # structs_depset = depset(order="postorder", transitive = structs_depsets)
    # print("structs_depset: %s" % structs_depset)
    # for larg in structs_depset.to_list():
    #     if larg.extension in struct_extensions:
    #         # archives.append(larg)
    #         print("ADDING LDEP: %s" % larg)
    #         args.add(larg.path)
    #         includes.append(larg.dirname)

    ### ctx.files.deps added above;
    ### FIXME: verify logic
    ## all direct deps must be on cmd line:
    # for dep in ctx.files.deps:
    #     ## print("DIRECT DEP: %s" % dep)
    #     includes.append(dep.dirname)
    #     args.add(dep)

    ## 'main' dep must come last on cmd line
    # if ctx.file.main:
    #     args.add(ctx.file.main)

    ## FIXME: use CcInfo
    # cclibs_depset = depset(order=dsorder,
    #                          direct = cclibs_primary,
    #                          transitive = cclibs_secondary)

    ################ STUBLIBS ################
    ## NB: we do not need to put anything on the cmd line; evidently
    ## OCaml can figure out on its own when it needs to put a stublib
    ## on the cmd line. But we DO need to add the stublibs to the
    ## action_inputs depset.

    ccInfo = cc_common.merge_cc_infos(cc_infos = stublibs_list)

    ## extract cclibs from merged CcInfo provider:
    [
        # action_inputs_ccdep_filelist, ## add this to action_inputs_depset
        # cc_runfiles
        static_cclibs, dynamic_cclibs
    ] = extract_cclibs(ctx, tc.linkmode, args, ccInfo)
    if debug_cc:
        print("static_cclibs:  %s" % static_cclibs)
        print("dynamic_cclibs: %s" % dynamic_cclibs)

    cclib_linkpaths = []
    for cclib in dynamic_cclibs:
        cclib_linkpaths.append("-L" + cclib.dynamic_library.dirname)
        args.add("-cclib", cclib.dynamic_library.path)

    args.add_all(cclib_linkpaths, before_each="-ccopt", uniquify=True)

    if mode == "bytecode":
        # vmlibs =  lib/stublibs/dll*.so, set by toolchain
        # only needed for bytecode mode, else we get errors like:
        # Error: I/O error: dllbase_internalhash_types_stubs.so: No such
        # file or directory

        ## WARNING: both -dllpath and -I are required!
        args.add("-dllpath", tc.vmlibs[0].dirname)
        args.add("-I", tc.vmlibs[0].dirname)

        # if "ppx" in ctx.attr.tags or ctx.attr._rule == "ppx_executable":
            ## Currently we default to a custom runtime.
            ## See section 20.1.3 "Statically linking C code with OCaml code"
            ## https://v2.ocaml.org/manual/intfc.html#ss:staticlink-c-code
            ## and https://ocaml.org/manual/runtime.html

        # args.add("-custom")

    elif mode == "native":
        vmlibs = []

        ## no, we never need vmlibs for native code
        # for lib in tc.vmlibs:
        #     print("VMLIB: %s" % lib)
        #     includes.append(lib.dirname)
        # args.add_all(tc.vmlibs, before_each="-cclib", uniquify=True)

    # for cclib in tc.vmlibs:
    #     print("STUBLIB: %s" % cclib.dirname)
    #     includes.append(cclib.dirname)
    #     dllpaths.append(cclib.dirname)

    args.add_all(includes, before_each="-I", uniquify=True)

    args.add("-o", out_exe)

    data_inputs = []
    if ctx.attr.data:
        data_inputs = [depset(direct = ctx.files.data)]
        for f in ctx.files.data:
            # print("DATAFILE: %s" % f.path)
            args.add("-I", f.dirname)

    cctc_inputs = _get_cc_toolchain_deps(ctx)

    if debug:
        print("MAINMAIN: %s" % ctx.attr.main)
        print("astructs_primary: %s" % astructs_primary)
    action_inputs_depset = depset(
        order=dsorder,
        direct = tc.vmlibs
        + action_inputs_ccdep_filelist
        + afiles_primary
        + astructs_primary
        + archives_primary
        + structs_primary
        + ofiles_primary
        + sigs_primary
        # + vmlibs
        ,
        transitive =
        [depset(direct = [ctx.file.main])]
        # data_inputs
        + sigs_secondary
        + structs_secondary
        + archives_secondary
        + afiles_secondary ## .a files for .cmxa files on cmd line
        + ofiles_secondary  ## .o files for .cmx files on cmd line
        + astructs_secondary

        + cctc_inputs

        # + cclibs_secondary
        # + [depset(action_inputs_ccdep_filelist)]
        # + [depset(transitive=ppx_codep_ldeps)]
        # + [structs_depset]
        # + vmlibs
    )
    if debug:
        for dep in action_inputs_depset.to_list():
            if dep.dirname.endswith("stublibs"):
                print("IDEP: {t} {d}".format(
                    t=ctx.label, d=dep.path))

    if ctx.attr._rule == "ocaml_executable":
        mnemonic = "CompileOcamlExecutable"
    elif "ppx" in ctx.attr.tags or ctx.attr._rule == "ppx_executable":
    # elif ctx.attr._rule == "ppx_executable":
        mnemonic = "CompilePpxExecutable"
    elif ctx.attr._rule == "ocaml_test":
        mnemonic = "CompileOcamlTest"
    else:
        fail("Unknown rule for executable: %s" % ctx.attr._rule)

    ################
    ctx.actions.run(
      # env = env,
      executable = tool,
      arguments = [args],
      inputs = action_inputs_depset,
      outputs = [out_exe],
      tools = [tool] + tool_args,  # [tc.ocamlopt],
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

    #### RUNFILE DEPS ####
    rfiles = ctx.files.data + tc.vmlibs
    if ctx.attr.strip_data_prefixes:
        myrunfiles = ctx.runfiles(
            files = rfiles,
            symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
        )
    else:
        myrunfiles = ctx.runfiles(
            files = rfiles
        )

    ##########################
    defaultInfo = DefaultInfo(
        executable=out_exe,
        runfiles = myrunfiles
    )

    exe_provider = None
    if "ppx" in ctx.attr.tags or ctx.attr._rule == "ppx_executable":
        exe_provider = PpxExecutableMarker(
            args = ctx.attr.args
        )
    elif ctx.attr._rule == "ocaml_executable":
        exe_provider = OcamlExecutableMarker()
    elif ctx.attr._rule == "ocaml_test":
        exe_provider = OcamlTestMarker()
    else:
        fail("Wrong rule called impl_executable: %s" % ctx.attr._rule)

    providers = [
        defaultInfo,
        exe_provider
    ]

    ## for ppx_executable: in addition to the compiled exe and
    ## runfiles, we need to propagate ppx codeps, so that they can be
    ## passed on as deps of src files the ppx transforms. that is,
    ## an ocaml_module rule with a 'ppx' attribute will extract the
    ## ppx_codeps from its ppx_executable dependency, and use them
    ## in the ppx transform action that runs the ppx_executable.

    ## NB: ctx.files.ppx_codeps (== DefaultInfo.files) will not
    ## deliver imported source files, so we need to iterate over
    ## providers

    ## executables do not directly support ppx_codeps attr - they must
    ## be attached to the module that injects the dep.

    if ctx.attr._rule == "ppx_executable":
        # ppx_codeps_paths_depset = depset(
        #     direct = direct_ppx_codep_depsets_paths,
        #     transitive = depset(direct=indirect_ppx_codep_depsets_paths)
        # )

        # ppx_codeps_depset = depset(
        # odep
        #     transitive = indirect_ppx_codep_depsets
        # )

        # ppx_codeps_linkset = depset(
        #     transitive = ppx_codep_linksets
        # )

        # ppxCodepsProvider = PpxCodepsProvider(
        #     ppx_codeps = ppx_codeps_depset,
        #     # paths = ppx_codeps_paths_depset,
        #     # linkset = ppx_codeps_linkset,
        #     # sigs   = ppx_codep_cdeps,
        #     # structs   = ppx_codep_ldeps,
        # )

        ppx_sigs_depset = depset(order=dsorder,
                                 direct = codep_sigs_primary,
                                 transitive = codep_sigs_secondary)

        ppxCodepsProvider = PpxCodepsProvider(
            sigs       = ppx_sigs_depset,
            structs    = depset(order=dsorder,
                                direct = codep_structs_primary,
                                transitive = codep_structs_secondary),
            ofiles     = depset(order=dsorder,
                                direct = codep_ofiles_primary,
                                transitive = codep_ofiles_secondary),
            archives   = depset(order=dsorder,
                                direct = codep_archives_primary,
                                transitive = codep_archives_secondary),
            afiles     = depset(order=dsorder,
                                direct = codep_afiles_primary,
                                transitive = codep_afiles_secondary),
            astructs       = depset(order=dsorder,
                                   direct = codep_astructs_primary,
                                   transitive = codep_astructs_secondary),
            # cclibs = depset(order=dsorder,
            #                 direct = codep_cclibs_primary,
            #                 transitive = codep_cclibs_secondary),
            paths    = depset(order=dsorder,
                              direct = codep_paths_primary,
                              transitive = codep_paths_secondary),
        )
        providers.append(ppxCodepsProvider)

        # outputGroupInfo = OutputGroupInfo(
        #     ppx_codeps = ppx_sigs_depset,
        #     # linkset = ppx_codeps_linkset,
        #     inputs = action_inputs_depset,
        #     all = depset(transitive=[
        #         ppx_codeps_depset,
        #     ])
        # )
        # providers.append(outputGroupInfo)

    return providers
