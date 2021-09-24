load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "CompilationModeSettingProvider",

     "PpxAdjunctsProvider",
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

load(":impl_common.bzl", "dsorder", "opam_lib_prefix")

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

    env = {
        "OPAMROOT": get_opamroot(),
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
    main_deps_list = []
    paths_direct   = []
    paths_indirect = []

    direct_ppx_adjunct_depsets = []
    direct_ppx_adjunct_depsets_paths = []
        if OcamlProvider in dep:
            opdep = dep[OcamlProvider]

    ################################################################
    ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
    paths_indirect.append(ctx.attr.main[OcamlProvider].paths)

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
    )


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

    # args.add("-absname")
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

    # TRANSITIVES = [
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
    ## NB: ctx.files.deps_adjunct will not deliver imported source files,

    ppx_adjuncts_depset = depset(
        # direct     = ppx_adjunct_direct,
    )

    ppxAdjunctsProvider = PpxAdjunctsProvider(
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
