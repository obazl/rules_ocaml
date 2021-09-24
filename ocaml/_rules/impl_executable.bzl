load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "CompilationModeSettingProvider",

     "PpxAdjunctsProvider",
     "OcamlArchiveProvider",
     "OcamlExecutableMarker",
     "OcamlModuleMarker",
     # "OcamlPathsMarker",
     "OcamlSDK",
     "OcamlTestMarker",
     "PpxExecutableMarker",
     "PpxModuleMarker"
)

load(":impl_ccdeps.bzl", "link_ccdeps", "dump_ccdep")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl",
     "get_sdkpath",
)
load("//ocaml/_functions:module_naming.bzl", "file_to_lib_name")


load(":options.bzl", "options")

load(":impl_common.bzl", "dsorder", "opam_lib_prefix")

#########################
def impl_executable(ctx):

    debug = False
    # if ctx.label.name == "test":
        # debug = True

    print("++ EXECUTABLE {}".format(ctx.label))

    if debug:
        print("EXECUTABLE TARGET: {kind}: {tgt}".format(
            kind = ctx.attr._rule,
            tgt  = ctx.label.name
        ))

    env = {
        "PATH": get_sdkpath(ctx),
    }

    ## FIXME: support ctx.attr.mode?
    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    if mode == "native":
        exe = tc.ocamlopt.basename
    else:
        exe = tc.ocamlc.basename

    ################
    direct_cc_deps    = {}
    direct_cc_deps.update(ctx.attr.cc_deps)
    indirect_cc_deps  = {}

    ################
    includes  = []
    cmxa_args  = []

    out_exe = ctx.actions.declare_file(ctx.label.name)

    #########################
    args = ctx.actions.args()

    if mode == "bytecode":
        ## FIXME: -custom only needed if linking with CC code?
        ## see section 20.1.3 at https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#s%3Ac-overview
        args.add("-custom")

    _options = get_options(rule, ctx)
    args.add_all(_options, uniquify=True)

    if "-g" in _options:
        args.add("-runtime-variant", "d") # FIXME: verify compile built for debugging

    args.add("-absname")

    ################################################################
    all_deps_list = []
    archive_deps_list = []
    archive_inputs_list = [] # not for command line!
    main_deps_list = []
    paths_direct   = []
    paths_indirect = []

    direct_ppx_adjunct_depsets = []
    direct_ppx_adjunct_depsets_paths = []
    indirect_ppx_adjunct_depsets      = []
    indirect_ppx_adjunct_depsets_paths = []

    direct_inputs_depsets = []
    direct_linkargs_depsets = []
    direct_paths_depsets = []

    ccInfo_list = []

    for dep in ctx.attr.deps:
        # print("XDEP: {d}".format(d = dep.label))

        if CcInfo in dep:
            # dump_ccdep(ctx, dep)
            ## we do not need to do anything with ccdeps here,
            ## just pass them on in a provider
            ccInfo_list.append(dep[CcInfo])
            # handle_ccinfo_dep(ctx, dep, ccdeps_list,)

        direct_inputs_depsets.append(dep[OcamlProvider].inputs)
        direct_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        direct_paths_depsets.append(dep[OcamlProvider].paths)

        # if OcamlArchiveProvider in dep:
        #     archive_deps_list.append(dep[OcamlArchiveProvider].files)

        ################ PpxAdjunctsProvider ################
        if PpxAdjunctsProvider in dep:
            ppxadep = dep[PpxAdjunctsProvider]
            # print("FOUND PPXAdjuncts %s" % ppxadep)
            if hasattr(ppxadep, "ppx_adjuncts"):
                if ppxadep.ppx_adjuncts:
                    # print("PPXADEP.ppx_adjuncts: %s" % ppxadep.ppx_adjuncts)
                    indirect_ppx_adjunct_depsets.append(ppxadep.ppx_adjuncts)
            if hasattr(ppxadep, "ppx_adjunct_paths"):
                if ppxadep.ppx_adjunct_paths:
                    indirect_ppx_adjunct_depsets_paths.append(ppxadep.ppx_adjunct_paths)


        ################ OCamlProvider ################
        if OcamlProvider in dep:
            opdep = dep[OcamlProvider]
            # print("OPDEP: %s" % opdep)
            all_deps_list.append(opdep.files)
            if opdep.archives:
                # print("AAAARCHIVES %s" % opdep.archives)
                archive_deps_list.append(opdep.archives)
            if opdep.archive_deps:
                archive_inputs_list.append(opdep.archive_deps)
            paths_indirect.append(opdep.paths)

    ################################################################
    ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)

    [
        action_inputs_ccdep_filelist,
        cc_runfiles
     ] = link_ccdeps(ctx,
                     tc.linkmode,
                     ccInfo,
                     args)
    # print("CCDEPS INPUTS: %s" % action_inputs_ccdep_filelist)

    #### MAIN attrib ####
    # print("MAINARCHS: %s" % ctx.attr.main[OcamlProvider].archives)
    dep = ctx.attr.main

    if CcInfo in dep:
        dump_ccdep(ctx, dep)
        ## we do not need to do anything with ccdeps here,
        ## just pass them on in a provider
        ccInfo_list.append(dep[CcInfo])
        # handle_ccinfo_dep(ctx, dep, ccdeps_list,)

    ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)

    [
        action_inputs_ccdep_filelist,
        cc_runfiles
     ] = link_ccdeps(ctx,
                     tc.linkmode,
                     ccInfo,
                     args)

    direct_inputs_depsets.append(dep[OcamlProvider].inputs)
    direct_linkargs_depsets.append(dep[OcamlProvider].linkargs)
    direct_paths_depsets.append(dep[OcamlProvider].paths)

    if ctx.attr.main[OcamlProvider].archives:
        archive_deps_list.append(ctx.attr.main[OcamlProvider].archives)
    if ctx.attr.main[OcamlProvider].archive_deps:
        archive_deps_list.append(ctx.attr.main[OcamlProvider].archive_deps)

    all_deps_list.append(ctx.attr.main[OcamlProvider].files)
    paths_indirect.append(ctx.attr.main[OcamlProvider].paths)

    ################
    paths_depset  = depset(
        order = dsorder,
        # direct = paths_direct,
        transitive = direct_paths_depsets
        # transitive = paths_indirect
    )

    args.add_all(paths_depset.to_list(), before_each="-I")

    # if archive_deps_list:
    #     archives_depset = depset(transitive = archive_deps_list)
    #     args.add("-ccopt", "-DARCHIVE_DEPS_START")
    #     for f in archives_depset.to_list():
    #         if f.extension not in ["a"]:
    #             args.add(f.path)
    #     args.add("-ccopt", "-DARCHIVE_DEPS_END")
    # else:
    #     archives_depset = depset()

    archive_inputs_depset = depset(transitive = archive_inputs_list)

    all_deps = depset(
        order = dsorder,
        direct = ctx.files.main,
        transitive = all_deps_list
    )

    args.add("-absname")

    linkargs_depset = depset(
        transitive = direct_linkargs_depsets
    )

    args.add("-ccopt", "-DLINKARGS_START")
    for dep in linkargs_depset.to_list():
        ## DefaultInfo contains some stuff we do not want in cmd:
        ## cmxa (direct ocaml_ns_archive dep)
        ## cmi (direct ocaml_signature dep)
        if dep.extension not in ["a", "o", "cmi", "mli"]:
            args.add(dep)
    args.add("-ccopt", "-DLINKARGS_END")

    ################################################################
    ################################################################
    args.add_all(includes, before_each="-I", uniquify=True)

    args.add("-o", out_exe)

    inputs_depset = depset(
        transitive = direct_inputs_depsets
        + [depset(action_inputs_ccdep_filelist)]
    )
    # print("EXECUTABLE {m} INPUTS_DEPSET: {ds}".format(
    #     m=ctx.label.name, ds=inputs_depset))

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
      executable = exe,
      arguments = [args],
      inputs = inputs_depset,
      outputs = [out_exe],
      tools = [tc.ocamlopt],
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
    ## NB: ctx.files.deps_adjunct will not deliver imported source files,
    ## so we need to iterate over providers

    ## executables do not support deps_adjunct attr - they must be attached
    ## to the module that injects the dep.

    ppx_adjuncts_paths_depset = depset(
        direct = direct_ppx_adjunct_depsets_paths,
        transitive = indirect_ppx_adjunct_depsets_paths
    )

    ppx_adjuncts_depset = depset(
        # direct     = ppx_adjunct_direct,
        transitive = indirect_ppx_adjunct_depsets
    )

    ppxAdjunctsProvider = PpxAdjunctsProvider(
        ppx_adjuncts = ppx_adjuncts_depset,
        paths = ppx_adjuncts_paths_depset
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
        ppx_adjuncts = ppx_adjuncts_depset,
        # cc = cclib_deps,
        inputs = inputs_depset,
        all = depset(transitive=[
            ppx_adjuncts_depset,
            # depset(cclib_deps),
        ])
    )

    # print("EXE delivering ppx_adjuncts: %s" % ppxAdjunctsProvider)
    results = [
        defaultInfo,
        outputGroupInfo,
        ppxAdjunctsProvider,
        exe_provider
    ]

    return results
