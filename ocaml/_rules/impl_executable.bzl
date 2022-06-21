load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
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

load(":impl_ccdeps.bzl", "link_ccdeps", "dump_CcInfo")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

# load("//ocaml/_functions:utils.bzl", "get_sdkpath")

load("//ocaml/_functions:module_naming.bzl", "file_to_lib_name")

load(":options.bzl", "options")

load(":impl_common.bzl", "dsorder", "opam_lib_prefix",
     "tmpdir"
     )

workdir = tmpdir

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

    debug = False
    debug_ppx = False
    # if ctx.label.name == "test":
        # debug = True

    if debug:
        print("EXECUTABLE TARGET: {kind}: {tgt}".format(
            kind = ctx.attr._rule,
            tgt  = ctx.label.name
        ))

    if hasattr(ctx.attr, "bin"):
        if ctx.attr.bin:
            return _import_ppx_executable(ctx)

    # env = {
    #     "PATH": get_sdkpath(ctx),
    # }

    # mode = ctx.attr._mode[CompilationModeSettingProvider].value

    # tc = ctx.toolchains["@rules_ocaml//ocaml:toolchain"]

    # if mode == "native":
    #     exe = tc.ocamlopt.basename
    # else:
    #     exe = tc.ocamlc.basename

    ################
    direct_cc_deps    = {}
    direct_cc_deps.update(ctx.attr.cc_deps)
    indirect_cc_deps  = {}

    ################
    includes   = []
    dllpaths   = []
    cmxa_args  = []

    out_exe = ctx.actions.declare_file(ctx.label.name)

    #########################
    args = ctx.actions.args()

    args.add_all(tool_args)

    if "ppx" in ctx.attr.tags:
        print("PPX XXXXXXXXXXXXXXXX");

    if mode == "bytecode":
        if "ppx" in ctx.attr.tags or ctx.attr._rule == "ppx_executable":
            ## FIXME: get stublibs from toolchain?
            # if hasattr(ctx.attr, "_stublibs"):
            #     for x in ctx.files._stublibs:
            #         includes.append(x.dirname)
            #         ## FIXME: get correct path, or set CAML_LD_LIBRARY_PATH
            #         dllpaths.append(x.dirname)
            #         # dllpaths.append("/private/var/tmp/_bazel_gar/2452f4a294f2c90cde5ca0e06629a4e9/" + x.dirname)

            # for stublib in tc.stublibs:
            #     print("STUBLIB: %s" % stublib)

            # if ctx.attr._rule == "ppx_executable":
            ## FIXME: OR: ctx.attr.cc_linkstatic ???
            ## see section 20.1.3 at https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#s%3Ac-overview
            ## and https://ocaml.org/manual/runtime.html
                args.add("-custom")

    _options = get_options(rule, ctx)
    # print("OPTIONS: %s" % _options)
    # do not uniquify options, it collapses all -I
    args.add_all(_options)

    if "-g" in _options:
        args.add("-runtime-variant", "d") # FIXME: verify compile built for debugging

    ################################################################
    main_deps_list = []
    paths_direct   = []
    paths_indirect = []

    direct_ppx_codep_depsets = []
    direct_ppx_codep_depsets_paths = []
    indirect_ppx_codep_depsets      = []
    indirect_ppx_codep_depsets_paths = []
    ppx_codep_linksets = []
    ppx_codep_cdeps = []
    ppx_codep_ldeps = []

    direct_inputs_depsets = []
    direct_linkargs_depsets = []
    direct_paths_depsets = []

    ccInfo_list = []

    for dep in ctx.attr.deps:
        if debug:
            print("DEP: %s" % dep)
            if OcamlProvider in dep:
                print("dep[OcamlProvider] %s" % dep[OcamlProvider])
            if OcamlImportMarker in dep:
                print("dep[OcamlImportMarker] %s" % dep[OcamlImportMarker])

        if CcInfo in dep:
            # print("CcInfo dep: %s" % dep)
            ccInfo_list.append(dep[CcInfo])

        direct_inputs_depsets.append(dep[OcamlProvider].ldeps) # inputs)
        direct_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        direct_paths_depsets.append(dep[OcamlProvider].paths)

        direct_linkargs_depsets.append(dep[DefaultInfo].files)

        ################ PpxCodepsProvider ################
        ## only for ocaml_imports listed in deps, not ppx_codeps
        if PpxCodepsProvider in dep:
            if debug_ppx:
                print("dep[PpxCodepsProvider]: %s" % dep[PpxCodepsProvider])
            ppxcdp = dep[PpxCodepsProvider]
            if hasattr(ppxcdp, "ppx_codeps"):
                if ppxcdp.ppx_codeps:
                    indirect_ppx_codep_depsets.append(ppxcdp.ppx_codeps)
            if hasattr(ppxcdp, "paths"):
                if ppxcdp.paths:
                    indirect_ppx_codep_depsets_paths.append(ppxcdp.paths)
            if hasattr(ppxcdp, "cdeps"):
                if ppxcdp.cdeps:
                    ppx_codep_cdeps.append(ppxcdp.cdeps)
            if hasattr(ppxcdp, "ldeps"):
                if ppxcdp.ldeps:
                    ppx_codep_ldeps.append(ppxcdp.ldeps)

    action_inputs_ccdep_filelist = []
    manifest_list = []

    if ctx.attr._rule == "ppx_executable":
        if ctx.attr.ppx_codeps:
            for codep in ctx.attr.ppx_codeps:
                if debug_ppx:
                    print("attr.ppx_codep: %s" % codep)
                    print("codep[OcamlImportMarker: %s" %
                          codep[OcamlImportMarker])
                    print("codep[OcamlProvider]: %s" % codep[OcamlProvider])
                # NB: codep[OcamlProvider]linkargs insufficient, it only
                # contains archive files, for linking executables.
                # We will need to list all modules as inputs
                ppx_codep_linksets.append(codep[OcamlProvider].linkargs)
                # indirect_ppx_codep_depsets.append(codep[OcamlProvider].inputs)
                indirect_ppx_codep_depsets_paths.append(codep[OcamlProvider].paths)

                ppx_codep_cdeps.append(codep[OcamlProvider].cdeps)
                ppx_codep_ldeps.append(codep[OcamlProvider].ldeps)

    # print("LDEPS: %s" % ppx_codep_ldeps)

    ################################################################
    #### MAIN ####
    if ctx.attr.main:
        main = ctx.attr.main
        if CcInfo in main: # [0]:
            # print("CcInfo main: %s" % main[0][CcInfo])
            ccInfo_list.append(main[CcInfo]) # [0][CcInfo])

        ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        [
            action_inputs_ccdep_filelist,
            cc_runfiles
        ] = link_ccdeps(ctx,
                        tc.linkmode,
                        args,
                        ccInfo)

        if OcamlProvider in main:
            if hasattr(main[OcamlProvider], "archive_manifests"):
                manifest_list.append(main[OcamlProvider].archive_manifests)

        direct_inputs_depsets.append(main[OcamlProvider].ldeps) # inputs)
        direct_linkargs_depsets.append(main[OcamlProvider].linkargs)
        direct_paths_depsets.append(main[OcamlProvider].paths)

        # direct_linkargs_depsets.append(main[DefaultInfo].files)

        paths_indirect.append(main[OcamlProvider].paths)

    ## end ctx.attr.main handling

    merged_manifests = depset(transitive = manifest_list)
    archive_filter_list = merged_manifests.to_list()
    # print("Merged manifests: %s" % archive_filter_list)

    ################
    paths_depset  = depset(
        order = dsorder,
        transitive = direct_paths_depsets
    )

    # args.add_all(paths_depset.to_list(), before_each="-I")
    includes.extend(paths_depset.to_list())

    linkargs_depset = depset(
        transitive = direct_linkargs_depsets
    )
    direct_inputs_depset = depset(
        transitive = direct_inputs_depsets
    )

    # args.add("external/ounit2/oUnit2.cmx")

    ## Archives containing deps needed by direct deps or main must be
    ## on cmd line.  FIXME: how to include only those actually needed?

    for dep in linkargs_depset.to_list():
        # print("LINKARG: %s" % dep)
        if dep not in archive_filter_list:
            includes.append(dep.dirname)
        if mode == "native":
            if dep.extension in ["cmx", "cmxa"]:
                args.add(dep)
        elif mode == "bytecode":
            if dep.extension in ["cmo", "cma"]:
                args.add(dep)

    ### ctx.files.deps added above;
    ### FIXME: verify logic
    ## all direct deps must be on cmd line:
    # for dep in ctx.files.deps:
    #     ## print("DIRECT DEP: %s" % dep)
    #     includes.append(dep.dirname)
    #     args.add(dep)

    ## 'main' dep must come last on cmd line
    if ctx.file.main:
        args.add(ctx.file.main)

    if mode == "bytecode":
        stublibs = tc.stublibs
    elif mode == "native":
        stublibs = []

    for stublib in stublibs:
        includes.append(stublib.dirname)
        dllpaths.append(stublib.dirname)

    args.add_all(dllpaths, before_each="-dllpath", uniquify=True)

    args.add_all(includes, before_each="-I", uniquify=True)

    if "ppx" in ctx.attr.tags:
        if hasattr(ctx.attr, "_stublibs"):
            args.add_all(dllpaths, before_each="-dllpath", uniquify=True)

    args.add("-o", out_exe)

    data_inputs = []
    if ctx.attr.data:
        data_inputs = [depset(direct = ctx.files.data)]
        for f in ctx.files.data:
            # print("DATAFILE: %s" % f.path)
            args.add("-I", f.dirname)

    # if tc.bootstrap_std_exit:
    #     std_exit = tc.bootstrap_std_exit.files
    # else:
    #     std_exit = []

    # if hasattr(ctx.attr, "_stublibs"):
    #     stublibs = [depset(ctx.files._stublibs)]
    # else:
    #     stublibs = []

    inputs_depset = depset(
        direct = stublibs, # [],
        transitive = [direct_inputs_depset] + data_inputs
        + [depset(action_inputs_ccdep_filelist)]
        + [depset(transitive=ppx_codep_ldeps)]
        # + stublibs
    )
    if debug_ppx:
        for dep in inputs_depset.to_list():
            print("IDEP: %s" % dep.path)

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
      inputs = inputs_depset,
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
    if ctx.attr.strip_data_prefixes:
      myrunfiles = ctx.runfiles(
        files = ctx.files.data + tc.stublibs,
        symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
      )
    else:
        myrunfiles = ctx.runfiles(
            files = ctx.files.data + tc.stublibs,
        )

    # print("ARGS: %s" % ctx.attr.args)
    # print("RUNFILES: %s" % ctx.attr.data)

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
        ppx_codeps_paths_depset = depset(
            direct = direct_ppx_codep_depsets_paths,
            transitive = indirect_ppx_codep_depsets_paths
        )

        ppx_codeps_depset = depset(
            transitive = indirect_ppx_codep_depsets
        )

        ppx_codeps_linkset = depset(
            transitive = ppx_codep_linksets
        )

        ppxCodepsProvider = PpxCodepsProvider(
            ppx_codeps = ppx_codeps_depset,
            paths = ppx_codeps_paths_depset,
            linkset = ppx_codeps_linkset,
            cdeps   = ppx_codep_cdeps,
            ldeps   = ppx_codep_ldeps,
        )
        providers.append(ppxCodepsProvider)

        outputGroupInfo = OutputGroupInfo(
            ppx_codeps = ppx_codeps_depset,
            linkset = ppx_codeps_linkset,
            inputs = inputs_depset,
            all = depset(transitive=[
                ppx_codeps_depset,
            ])
        )
        providers.append(outputGroupInfo)

    return providers
