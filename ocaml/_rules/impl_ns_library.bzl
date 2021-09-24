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
    print("**** NS_LIB {} ****************".format(ctx.label))

    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ################
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
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

    if ctx.attr._rule.startswith("ocaml_ns"):

    resolver_depset = depset(transitive = resolver_depsets_list)
    # print("IMPORTED NsResolver Depset:")
    # for f in resolver_depset.to_list():
    #     print("RX2: %s" % f)

    all_deps = depset(
        order = dsorder,
        # direct = resolver_depsets_list,
        transitive = all_deps_list
    )
    # print("NSLIBALLDEPS: %s" % all_deps)

    inputs_depset = depset(
        order = dsorder,
        direct = ctx.files._ns_resolver,
        transitive = [all_deps]
    )
    # print("NSLIB {l} INPUTS_DEPSET: {ds}".format(

    ## NS Lib targets do not directly produce anything, they just pass
    ## on their deps. The real work is done in the transition
    ## functions, which set the ConfigState that controls build
    ## actions of deps.

    #######################

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

    ################ ppx adjunct deps ################
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


    ocamlProvider = OcamlProvider(
        files = inputs_depset, # ocamlProviderDepset,
        paths  = depset(
            order = dsorder,
            direct = paths_direct,
            transitive = paths_indirect)
    )

    # print("ARCHIVE_DEPS_LIST: %s" % archive_deps_list)
    # )
    # print("NSLIB_PathsMarker: %s" % ocamlPathsMarker)

    outputGroupInfo = OutputGroupInfo(
        resolver = ns_resolver,
        ppx_adjuncts = ppx_adjuncts_depset,
        cc = depset(action_inputs_ccdep_filelist),
        all = depset(
            order = dsorder,
            transitive=[
                new_inputs_depset,
                depset(action_inputs_ccdep_filelist)
            ]
        )
    )

    return [
        defaultInfo,
        nsLibraryMarker,
        ocamlProvider,
        adjunctsMarker,
        ccDepsProvider,
        outputGroupInfo,
        # ocamlPathsMarker
    ]
