load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "OcamlProvider",
     "PpxAdjunctsProvider",

     "OcamlExecutableMarker",
     "PpxExecutableMarker",

     "OcamlModuleMarker",
     "OcamlTestMarker",
)

load(":impl_ccdeps.bzl", "link_ccdeps", "dump_ccdep")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl", "get_sdkpath")

load("//ocaml/_functions:module_naming.bzl", "file_to_lib_name")

load(":options.bzl", "options")

load(":impl_common.bzl", "dsorder", "opam_lib_prefix")

#########################
def impl_executable(ctx):

    debug = False
    # if ctx.label.name == "test":
        # debug = True

    # print("++ EXECUTABLE {}".format(ctx.label))

    if debug:
        print("EXECUTABLE TARGET: {kind}: {tgt}".format(
            kind = ctx.attr._rule,
            tgt  = ctx.label.name
        ))

    env = {
        "PATH": get_sdkpath(ctx),
    }

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

    ################################################################
    main_deps_list = []
    paths_direct   = []
    paths_indirect = []

    direct_ppx_codep_depsets = []
    direct_ppx_codep_depsets_paths = []
    indirect_ppx_codep_depsets      = []
    indirect_ppx_codep_depsets_paths = []

    direct_inputs_depsets = []
    direct_linkargs_depsets = []
    direct_paths_depsets = []

    ccInfo_list = []

    for dep in ctx.attr.deps:

        if CcInfo in dep:
            ccInfo_list.append(dep[CcInfo])

        direct_inputs_depsets.append(dep[OcamlProvider].inputs)
        direct_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        direct_paths_depsets.append(dep[OcamlProvider].paths)

        ################ PpxAdjunctsProvider ################
        if PpxAdjunctsProvider in dep:
            ppxadep = dep[PpxAdjunctsProvider]
            if hasattr(ppxadep, "ppx_codeps"):
                if ppxadep.ppx_codeps:
                    indirect_ppx_codep_depsets.append(ppxadep.ppx_codeps)
            if hasattr(ppxadep, "ppx_codep_paths"):
                if ppxadep.ppx_codep_paths:
                    indirect_ppx_codep_depsets_paths.append(ppxadep.ppx_codep_paths)

    ################################################################
    #### MAIN ####
    main = ctx.attr.main
    if CcInfo in main:
        ccInfo_list.append(main[CcInfo])

    ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
    [
        action_inputs_ccdep_filelist,
        cc_runfiles
     ] = link_ccdeps(ctx,
                     tc.linkmode,
                     args,
                     ccInfo)

    direct_inputs_depsets.append(main[OcamlProvider].inputs)
    direct_linkargs_depsets.append(main[OcamlProvider].linkargs)
    direct_paths_depsets.append(main[OcamlProvider].paths)

    paths_indirect.append(main[OcamlProvider].paths)

    ################
    paths_depset  = depset(
        order = dsorder,
        transitive = direct_paths_depsets
    )

    args.add_all(paths_depset.to_list(), before_each="-I")

    linkargs_depset = depset(
        transitive = direct_linkargs_depsets
    )

    for dep in linkargs_depset.to_list():
        if dep.extension not in ["a", "o", "cmi", "mli"]:
            args.add(dep)

    args.add_all(includes, before_each="-I", uniquify=True)

    args.add("-o", out_exe)

    inputs_depset = depset(
        transitive = direct_inputs_depsets
        + [depset(action_inputs_ccdep_filelist)]
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

    #### RUNFILE DEPS ####
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

        ppxAdjunctsProvider = PpxAdjunctsProvider(
            ppx_codeps = ppx_codeps_depset,
            paths = ppx_codeps_paths_depset
        )
        providers.append(ppxAdjunctsProvider)

        outputGroupInfo = OutputGroupInfo(
            ppx_codeps = ppx_codeps_depset,
            inputs = inputs_depset,
            all = depset(transitive=[
                ppx_codeps_depset,
            ])
        )
        providers.append(outputGroupInfo)

    return providers
