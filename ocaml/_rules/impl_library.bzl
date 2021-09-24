load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "OcamlProvider",
     "OcamlNsResolverProvider",

     "PpxAdjunctsProvider",

     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker")

load(":impl_ccdeps.bzl",
     "dump_ccdep")
     # "handle_ccdeps",
     # "link_ccdeps",

load("//ocaml/_functions:utils.bzl",
     "get_sdkpath",
)

load(":impl_common.bzl", "dsorder")

#################
def impl_library(ctx):

    # main_resolver = None

    debug = False
    # print("**** NS_LIB {} ****************".format(ctx.label))

    env = {"PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ns_resolver = ctx.files._ns_resolver if ctx.attr._rule.startswith("ocaml_ns") else []

    ## Library targets do not produce anything, they just pass on their deps.

    ################
    ## FIXME: does lib need to handle adjunct deps? they're carried by modules
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []

    ################
    ## NB: we need to propagate ccdeps from the submodules, since
    ## clients will depend on the CcDepsProvider of ocaml_ns_library target?
    indirect_cc_deps  = {}

    ################
    paths_direct   = []
    paths_indirect = []
    all_deps_list = []
    archive_deps_list = []
    archive_inputs_list = []
    resolver_depsets_list = []

    input_deps_list = []
    #######################
    if ctx.attr._rule == "ocaml_ns_archive":
        component_files = ctx.files.submodules
    elif ctx.attr._rule == "ocaml_ns_library":
        component_files = ctx.files.submodules
    elif ctx.attr._rule == "ocaml_archive":
        component_files = ctx.files.modules
    elif ctx.attr._rule == "ocaml_library":
        component_files = ctx.files.modules
    else:
        fail("impl_library called by non-aggregator: %s" % ctx.attr._rule)

    for f in component_files:
        paths_direct.append(f.dirname)

    #### INDIRECT DEPS first ####
    # these are "indirect" from the perspective of the consumer
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    ccInfo_list = []

    # print("NSLIB SUBMODS: %s" % ctx.attr.submodules)
    the_deps = ctx.attr.submodules if ctx.attr._rule.startswith("ocaml_ns") else ctx.attr.modules
    for dep in the_deps:
        # print("MDEPs: {host} => {d}".format(host=ctx.label, d = dep.label))
        # for f in dep[OcamlProvider].files.to_list():
        #     print("  MDEP: %s" % f)

        if CcInfo in dep:
            # dump_ccdep(ctx, dep)
            ## we do not need to do anything with ccdeps here,
            ## just pass them on in a provider
            ccInfo_list.append(dep[CcInfo])

        # ignore DefaultInfo, its just for printing, not propagation
        indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
        indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        indirect_paths_depsets.append(dep[OcamlProvider].paths)

        input_deps_list.append(dep[OcamlProvider].files)

        # print("NSLIB SUBMOD: %s" % dep)
        # if OcamlArchiveProvider in dep:
        #     # print("NEXT {m} OcamlArchiveProvider: {ap}".format(
        #     #     m = ctx.label, ap = dep[OcamlArchiveProvider].files))
        #     archive_deps_list.append(dep[OcamlArchiveProvider].files)

        all_deps_list.append(dep[DefaultInfo].files)
        ################ OCamlProvider ################
        if OcamlProvider in dep:
            # print("NSLIB SM OcamlProvider files: %s" % dep[OcamlProvider].files)
            # input_deps_list.append(dep[OcamlProvider].files)
            if dep[OcamlProvider].archives:
                archive_deps_list.append(dep[OcamlProvider].archives)
            if dep[OcamlProvider].archive_deps:
                archive_inputs_list.append(dep[OcamlProvider].archive_deps)
            paths_indirect.append(dep[OcamlProvider].paths)

        ################ Ns Resolver Module ################
        if OcamlNsResolverProvider in dep:
            ## FIXME: do not put .ml file in inputs_depset
            ## it's just a convenience, so dev can inspect it
            resolver_depsets_list.append(dep[OcamlNsResolverProvider].files)
            paths_indirect.append(dep[OcamlNsResolverProvider].paths)

    if ctx.attr._rule.startswith("ocaml_ns"):
        for f in ns_resolver:
            # direct_linkargs_list.append = [ctx.files._ns_resolver]
            paths_direct.append(f.dirname)

    resolver_depset = depset(transitive = resolver_depsets_list)
    # print("IMPORTED NsResolver Depset:")
    # for f in resolver_depset.to_list():
    #     print("RX2: %s" % f)

    # if archive_deps_list:
    #     archives_depset = depset(transitive = archive_deps_list)
    # else:
    #     archives_depset = None

    if archive_inputs_list:
        archive_inputs_depset = depset(transitive = archive_inputs_list)
    else:
        archive_inputs_depset = None

    all_deps = depset(
        order = dsorder,
        # direct = resolver_depsets_list,
        transitive = all_deps_list
    )
    # print("NSLIBALLDEPS: %s" % all_deps)

    inputs_depset = depset(
        order = dsorder,
        direct = ns_resolver,
        transitive = indirect_inputs_depsets
        # transitive = input_deps_list
        # transitive = [all_deps] + input_deps_list
        # + ([archives_depset] if archives_depset else [])
    )
    # print("NSLIB {l} INPUTS_DEPSET: {ds}".format(
    #     l = ctx.label.name, ds = inputs_depset))

    ## NS Lib targets do not directly produce anything, they just pass
    ## on their deps. The real work is done in the transition
    ## functions, which set the ConfigState that controls build
    ## actions of deps.

    #######################
    ctx.actions.do_nothing(
        mnemonic = "NS_LIB",
        inputs = inputs_depset
    )
    #######################

    ## Library generates nothing, so provides nothing directly:
    defaultDepset = depset(
        # order = dsorder,
        direct = ns_resolver,
        # direct = ctx.files._ns_resolver,
        # transitive = None
        transitive = [depset(component_files)] # (ctx.files.submodules)]
    )

    # print("#### PROVIDERS of {} ####".format(ctx.label))

    defaultInfo = DefaultInfo(
        files = defaultDepset
    )
    # print("NSLIB_DefaultInfo: %s" % defaultInfo)

    ################ ppx adjunct deps ################
    ppx_adjuncts_depset = depset(
        transitive = indirect_adjunct_depsets
    )
    ppxAdjunctsProvider = PpxAdjunctsProvider(
        ppx_adjuncts = ppx_adjuncts_depset,
        paths        = depset(transitive = indirect_adjunct_path_depsets)
    )

    ################ cc deps ################
    # [
    #     action_inputs_ccdep_filelist, ccDepsProvider
    # ] = handle_ccdeps(ctx,
    #                   # True if ctx.attr.pack else False,
    #                    tc.linkmode,
    #                   # cc_deps_dict,
    #                    ctx.actions.args()
    #                   # includes,
    #                   # cclib_deps,
    #                   # cc_runfiles)
    #               )
    # print("CCDEPS INPUTS: %s" % action_inputs_ccdep_filelist)

    # cclibs = {}
    # if len(indirect_cc_deps) > 0:
    #     cclibs.update(indirect_cc_deps)
    # ccMarker = CcDepsProvider(
    #     ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
    #     ccdeps_map = cclibs
    # )
    # cclib_files = []
    # for tgt in cclibs.keys():
    #     cclib_files.extend(tgt.files.to_list())
    # cclib_files_depset = depset(cclib_files)

    ocamlProviderFilesDepset = depset(
        order  = dsorder,
        # direct = ctx.files._ns_resolver,
        transitive = input_deps_list

        # transitive = [all_deps]
        # + [depset(ctx.files.submodules)]
    )

    new_inputs_depset = depset(
        direct = ns_resolver,
        # direct = ctx.files._ns_resolver,
        transitive = indirect_inputs_depsets
    )
    linkargs_depset = depset(
        direct = ns_resolver,
        # direct = ctx.files._ns_resolver,
        transitive = indirect_linkargs_depsets
    )
    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = indirect_paths_depsets
        # transitive = paths_indirect
    )

    ocamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,

        files = inputs_depset, # ocamlProviderDepset,
        ns_resolver = ns_resolver,
        # ns_resolver = ctx.files._ns_resolver if ctx.files._ns_resolver else None,
        archives = None, # archives_depset if archives_depset else None,
        archive_deps = archive_inputs_depset if archive_inputs_depset else None,
        # paths  = depset(
        #     order = dsorder,
        #     direct = paths_direct,
        #     transitive = paths_indirect)
    )

    # print("ARCHIVE_DEPS_LIST: %s" % archive_deps_list)
    # if archive_deps_list:
    #     archives_depset = depset(transitive = archive_deps_list)
    # else:
    #     archives_depset = depset() # for inputs

    # archiveProvider = OcamlArchiveProvider(
    #     files = archives_depset
    # )
    # print("NSLIB EXPORTING OcamlProvider files: %s" % ocamlProvider)
    # for f in ocamlProvider.files.to_list():
    #     print("DX: %s" % f)

    outputGroupInfo = OutputGroupInfo(
        resolver = ns_resolver,
        # resolver = ctx.files._ns_resolver, # depset([rf]),
        ppx_adjuncts = ppx_adjuncts_depset,
        # cc = depset(action_inputs_ccdep_filelist),
        all = depset(
            order = dsorder,
            transitive=[
                new_inputs_depset,
                # ocamlProviderFilesDepset,
                # depset(action_inputs_ccdep_filelist)
            ]
        )
    )

    providers = [
        defaultInfo,
        ocamlProvider,
        # archiveProvider,
        ppxAdjunctsProvider,
        # ccDepsProvider,
        outputGroupInfo,
        # ocamlPathsMarker
    ]

    providers.append(
        OcamlLibraryMarker(marker = "OcamlLibraryMarker")
    )

    if ctx.attr._rule.startswith("ocaml_ns"):
        providers.append(
            OcamlNsMarker(marker = "OcamlNsMarker"),
        )

    if ccInfo_list:
        providers.append(
            cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        )

    return providers
