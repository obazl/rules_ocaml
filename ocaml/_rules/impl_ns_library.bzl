load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlProvider",

     "AdjunctDepsMarker",
     "CcDepsProvider",
     "CompilationModeSettingProvider",

     "OcamlArchiveMarker",
     "OcamlModuleMarker",
     "OcamlNsLibraryMarker",
     "OcamlNsResolverProvider",
     "PpxNsLibraryMarker")

load(":impl_ccdeps.bzl", "handle_ccdeps")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
)

load(":impl_common.bzl", "dsorder", "merge_deps")

#################
def impl_ns_library(ctx):

    # main_resolver = None

    debug = False
    print("**************** NS_LIB {} ****************".format(ctx.label))
    # if ctx.label.name in ["jemalloc"]: # ["mina_metrics", "memory_stats"]:
    #     debug = True

    if debug:
        print("")
        print("Start: IMPL_NS_LIBRARY: %s" % ctx.label)
        if ctx.attr._rule in ["ocaml_ns_archive", "ppx_ns_archive"]:
            print("  (for ns_archive)")
        print("ConfigState (%s):" % ctx.label)
        print("  MAIN RESOLVER: %s" % ctx.attr.resolver)
        print("  NS_RESOLVER: %s" % ctx.attr._ns_resolver[0].files)
        print("  NS_PREFIX: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
        print("  NS_SUBMODULES: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)

    # if ctx.attr._rule in ["ocaml_ns_library", "ppx_ns_library"]:
        # if not ctx.label.name.startswith("#"):
        #     fail("NS Library names must start with at least one '#' followed by a legal OCaml module name: %s" % ctx.label.name)

    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ################
    # merged_module_links_depsets = []
    # merged_archive_links_depsets = []

    # merged_paths_depsets = []
    # merged_depgraph_depsets = []
    # merged_archived_modules_depsets = []

    # # indirect_opam_depsets  = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    # indirect_adjunct_opam_depsets = []

    indirect_cc_deps  = {}

    ################
    paths_direct   = []
    paths_indirect = []
    all_deps_list = []
    resolver_depsets_list = []

    for f in ctx.files.submodules:
        paths_direct.append(f.dirname)

    for f in ctx.files._ns_resolver:
        # print("NSNSNS %s" % f)
        paths_direct.append(f.dirname)

    for dep in ctx.attr.submodules:
        # print("MDEPs: {host} => {d}".format(host=ctx.label, d = dep.label))
        # for f in dep[OcamlProvider].files.to_list():
        #     print("  MDEP: %s" % f)

        ################ OCamlProvider ################
        if OcamlProvider in dep:
            all_deps_list.append(dep[OcamlProvider].files)
            paths_indirect.append(dep[OcamlProvider].paths)

        ################ Ns Resolver Module ################
        if OcamlNsResolverProvider in dep:
            resolver_depsets_list.append(dep[OcamlNsResolverProvider].files)
            paths_indirect.append(dep[OcamlNsResolverProvider].paths)
            # print("IMPORTING OcamlNsResolverProvider:")
            # for f in dep[OcamlProvider].files.to_list():
            #     print("RX: %s" % f)

        ## NB: we need to propagate ccdeps from the submodules, since
        ## clients will depend on the ocaml_ns_library target.



    # print("IMPORTED NsResolver list:")
    # for f in resolver_depsets_list:
    #     print("RX1: %s" % f)

    resolver_depset = depset(transitive = resolver_depsets_list)
    # print("IMPORTED NsResolver Depset:")
    # for f in resolver_depset.to_list():
    #     print("RX2: %s" % f)

    all_deps = depset(
        order = dsorder,
        # direct = resolver_depsets_list,
        transitive = all_deps_list
    )
    # print("ALL_DEPS:")
    # for d in all_deps.to_list():
    #     print(" MDEP: %s" % d)

    inputs_depset = depset(
        order = dsorder,
        direct = ctx.files._ns_resolver,
        transitive = [all_deps]
    )
    # print("INPUTS_DEPSET:")
    # for dep in inputs_depset.to_list():
    #     print(" INDEP: %s" % dep)

    ## NS Lib targets do not directly produce anything, they just pass
    ## on their deps. The real work is done in the transition
    ## functions, which set the ConfigState that controls build
    ## actions of deps.

    # #######################
    # ctx.actions.do_nothing(
    #     mnemonic = "NS_LIB",
    #     inputs = inputs_depset
    # )
    # #######################

    # print("NS RESOLVER: %s" % ctx.files._ns_resolver)
    defaultDepset = depset(
        order = dsorder,
        direct = ctx.files._ns_resolver,
        transitive = [depset(ctx.files.submodules)]
    )

    # print("#### PROVIDERS of {} ####".format(ctx.label))

    defaultInfo = DefaultInfo(
        files = defaultDepset
    )
    # print("NSLIB_DefaultInfo: %s" % defaultInfo)

    # module_links = depset(
    #     order = dsorder,
    #     # direct = ctx.files.submodules + ctx.files._ns_resolver,
    #     direct = ctx.files._ns_resolver,
    #     transitive = merged_module_links_depsets
    # )
    # archive_links = depset(
    #     order = dsorder,
    #     transitive = merged_archive_links_depsets
    # )
    # paths_depset  = depset(
    #     transitive = merged_paths_depsets
    # )
    # depgraph = depset(
    #     order = dsorder,
    #     direct = ctx.files.submodules + ctx.files._ns_resolver,
    #     transitive = merged_depgraph_depsets
    # )
    # archived_modules = depset(
    #     order = dsorder,
    #     transitive = merged_archived_modules_depsets
    # )

    # if ctx.attr._rule == "ocaml_ns_library":
    #     nslibMarker = OcamlNsLibraryMarker(
    #         module_links = module_links,
    #         archive_links = archive_links,
    #         paths = paths_depset,
    #         depgraph = depgraph,
    #         archived_modules = archived_modules
    #     )
    # else:
    #     nslibMarker = PpxNsLibraryMarker(
    #         module_links = module_links,
    #         archive_links = archive_links,
    #         paths = paths_depset,
    #         depgraph = depgraph,
    #         archived_modules = archived_modules
    #     )

    ppx_adjuncts_depset = depset(
        transitive = indirect_adjunct_depsets
    )
    adjunctsMarker = AdjunctDepsMarker(
        # opam        = None, # depset(transitive = indirect_adjunct_opam_depsets),
        nopam       = ppx_adjuncts_depset,
        nopam_paths = depset(transitive = indirect_adjunct_path_depsets)
    )

    [
        action_inputs_ccdep_filelist, ccDepsProvider
    ] = handle_ccdeps(ctx,
                      # True if ctx.attr.pack else False,
                       tc.linkmode,
                      # cc_deps_dict,
                       ctx.actions.args()
                      # includes,
                      # cclib_deps,
                      # cc_runfiles)
                  )
    print("CCDEPS INPUTS: %s" % action_inputs_ccdep_filelist)

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

    ocamlProviderDepset = depset(
        order  = dsorder,
        # direct = ctx.files._ns_resolver,
        transitive = [all_deps]
        # + [depset(ctx.files.submodules)]
    )
    # inputs_depset = depset(
    #     order = dsorder,
    #     direct = ctx.files._ns_resolver,
    #     transitive = [all_deps]
    # )

    ocamlProvider = OcamlProvider(
        files = inputs_depset, # ocamlProviderDepset,
        paths  = depset(
            order = dsorder,
            direct = paths_direct,
            transitive = paths_indirect)
    )
    # print("EXPORTING OcamlProvider files: %s" % ocamlProvider)
    # for f in ocamlProvider.files.to_list():
    #     print("DX: %s" % f)

    # ocamlPathsMarker = OcamlPathsMarker(
    #     paths  = depset(
    #         order = dsorder,
    #         direct = paths_direct,
    #         transitive = paths_indirect)
    # )
    # print("NSLIB_PathsMarker: %s" % ocamlPathsMarker)

    outputGroupInfo = OutputGroupInfo(
        # module_links  = module_links,
        # archive_links = archive_links,
        # depgraph = depgraph,
        # archived_modules = archived_modules,
        ppx_adjuncts = ppx_adjuncts_depset,
        cc = depset(action_inputs_ccdep_filelist),
        all = depset(
            order = dsorder,
            transitive=[
                defaultDepset,
                ocamlProviderDepset,
                # module_links,
                # archive_links,
                # ppx_adjuncts_depset,
                # cclib_files_depset
                depset(action_inputs_ccdep_filelist)
            ]
        )
    )

    if (ctx.attr._rule == "ocaml_ns_library"):
        nsLibraryMarker = OcamlNsLibraryMarker()
    elif (ctx.attr._rule == "ppx_ns_library"):
        nsLibraryMarker = PpxNsLibraryMarker()

    return [
        defaultInfo,
        nsLibraryMarker,
        ocamlProvider,
        adjunctsMarker,
        ccDepsProvider,
        outputGroupInfo,
        # ocamlPathsMarker
    ]
