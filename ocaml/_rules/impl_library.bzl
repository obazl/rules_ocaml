load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("@rules_ocaml//providers:moduleinfo.bzl", "OCamlModuleInfo")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlNsResolverProvider",

     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker")

load("//ocaml/_functions:module_naming.bzl",
     "normalize_module_label",
     "normalize_module_name")

load(":impl_ccdeps.bzl",
     "cc_shared_lib_to_ccinfo",
     "filter_ccinfo",
     "extract_cclibs", "dump_CcInfo",
     "ccinfo_to_string"
     )

load("@rules_ocaml//ocaml:ocamlinfo.bzl",
     "aggregate_deps",
     "aggregate_codeps",
     "new_deps_aggregator",
     "DepsAggregator",
     "OCamlProvider",
     "COMPILE", "LINK", "COMPILE_LINK")

# load("//ocaml/_functions:deps.bzl",
#      "aggregate_deps",
#      "aggregate_codeps",
#      "OCamlProvider",
#      "DepsAggregator")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
)

load(":impl_common.bzl", "dsorder", "module_sep", "resolver_suffix")

load("//ocaml/_debug:colors.bzl",
     "CCRED", "CCBLU", "CCBLUCYN", "CCDER", "CCGRN", "CCMAG", "CCRESET")

## Plain Library targets do not produce anything, they just pass on
## their deps.

## NS Lib targets also do not directly produce anything, they just
## pass on their deps. The real work is done in the transition
## functions, which set the ConfigState that controls build actions of
## deps.


######################
def impl_library(ctx, for_archive = True):
    # for_archive true: we were called by an archive rule

    # tasks:
    # * deal with namespacing & renaming
    #   * ns resolver must go into output
    # * merge deps
    #   * manifest (ocaml) deps
    #   * cc_deps

    debug      = False
    debug_deps = False
    debug_ppx  = False
    debug_ns   = False
    debug_cc   = False

    if debug:
        print("{c}impl_library: {a}{r}".format(
            c=CCBLUCYN,a=ctx.label,r=CCRESET))


    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]

    # WARNING: due to transition processing, ns_resolver providers
    # must be indexed by [0]

    # this implementation is used by both ocaml_library and
    # ocaml_ns_library. ns libs must deal with the resolver -
    # put it into output provider(s) and propagate its deps.
    ################################################################
    ##  namespacing
    ##################

    ## ocaml_archive, ocaml_library: no ns attributes
    ## ocaml_ns_archive, ocaml_ns_library: no ns attributes

    if ctx.attr._rule.startswith("ocaml_ns_"):
        if hasattr(ctx.attr, "resolver"):
            if debug_ns: print("lib: user-provided resolver")
            ns_resolver = ctx.attr.resolver
            ns_resolver_files = ctx.files.resolver
        elif hasattr(ctx.attr, "_ns_resolver"):
            if debug_ns: print("lib: implicit resolver for %s" % ctx.label)
            ns_resolver = ctx.attr._ns_resolver ## [0] # index by int?
            ns_resolver_files = ctx.files._ns_resolver ## [0] # index by int?
        else:
            if debug_ns: print("lib: no resolver for %s" % ctx.label)
            ns_resolver = None
            ns_resolver_files = []
    else:
        ns_resolver = None
        ns_resolver_files = []

    ################
    ## manifest & cli link deps
    ##
    ## manifest ==
    ##   ocaml_library:  None
    ##   ocaml_archive:  ctx.attr.manifest
    ##   ocaml_ns_library:  submodules + resolver module
    ##   ocaml_ns_archive:  ctx.attr.manifest + resolver
    ##     * ns archive has both ns submodules list and archive manifest
    ##     * they should match.
    ##
    ## direct cli link deps:
    ##   ocaml_library: none
    ##   ocaml_archive: archive file
    ##   ocaml_ns_library: manifest + resolver
    ##   ocaml_ns_archive: archive file

    if debug_ns and ns_resolver:
        print("ns resolver: %s" % ns_resolver[0][DefaultInfo])
        print("rule: %s" % ctx.attr._rule)
    if ((hasattr(ctx.attr, "archived") and ctx.attr.archived)
        or ctx.attr._rule.endswith("archive")):
        if debug:
            print("xnsr: %s" % ctx.label)
        archive_manifest = []
        # for dep in ctx.attr.manifest:
        #     archive_manifest.append(dep)
        archive_manifest.extend(ctx.attr.manifest)
        if debug:
            print("manifest: %s" % archive_manifest)
            for f in ctx.attr.manifest:
                print("manifest lbl ws: %s" % f.label.workspace_name)
            # archive_manifest.append(f.label)
        # fail()
        ## FIXME: do we need the resolver in the manifest? Yes, deps
        ## aggregation needs it so it knows where to put ns resolver.
        # if ns_resolver:
        #     archive_manifest.append(ns_resolver)
    else:
        archive_manifest = []

    # for f in ns_resolver_files: # [0][DefaultInfo].files:
    #     archive_manifest.append(f)

    if debug:
        print("LIB MANIFEST: %s" % archive_manifest)

    depsets = new_deps_aggregator()
    for dep in ctx.attr.manifest:
        # if dep.label.name == "Red":
        #     print("red dep: %s" % dep[OcamlProvider])
        #     fail()
        depsets = aggregate_deps(ctx, dep, depsets, archive_manifest)

    # print("DEPSETS %s" % depsets.deps)
    # print("cli link deps: %s" % depsets.deps.cli_link_deps)
    ################
    paths_primary   = []
    # resolver_depsets_list = []

    if ns_resolver:
        if debug_ns:
            print("RESOLVER module: %s" % ns_resolver[0][OcamlNsResolverProvider])
        depsets = aggregate_deps(ctx, ns_resolver, depsets, archive_manifest)

    ## The tricky bit: cc_binary producing .so does not deliver a
    ## CcInfo containing the .so file!
    for dep in ctx.attr.cc_deps:
        depsets = aggregate_deps(ctx, dep, depsets, archive_manifest)

    ##FIXME: irrelevant? no action to depend on these:
    action_inputs_depset = depset(
        order = dsorder,
        # direct =
        # [ctx.file.resolver]
        # sigs_primary
        # + structs_primary
        # + archives_primary
        # + afiles_primary
        # + ofiles_primary
        # + astructs_primary,

        transitive =
        depsets.deps.sigs
        + depsets.deps.structs
        + depsets.deps.ofiles
        + depsets.deps.archives
        + depsets.deps.afiles
        + depsets.deps.astructs

        # aggregate build actions never depend on cc stuff
        # + depsets.ccinfos

        # sigs_secondary
        # + structs_secondary
        # + archives_secondary
        # + afiles_secondary
        # + ofiles_secondary
        # + astructs_secondary
        # + cclibs_secondary
    )

    #######################
    # this makes aquery show the inputs
    ctx.actions.do_nothing(
        mnemonic = "NS_LIB",
        inputs = action_inputs_depset
    )
    #######################
    # print("INPUTS_DEPSET: %s" % inputs_depset)

    # print("the_ns_resolvers: %s" % the_ns_resolvers)

    #### PROVIDERS ####
    providers = []

    # print("ns_resolver_files: %s" % ns_resolver_files)
    # print("ctx.files.manifest: %s" % ctx.files.manifest)
    # fail("x")

    ## if manifest contains namespaced modules, we need to explicitly
    ## include the implicit ns module in output.
    ## NO: the submodule depends on the ns resolver, no special treatment
    ## User can use --output_groups=all to see resolver(?)

    defaultDepset = depset(
        order = dsorder,
        transitive = [depset(direct = ctx.files.manifest)]
    )

    defaultInfo = DefaultInfo(
        files = defaultDepset
    )
    providers.append(defaultInfo)

    new_inputs_depset = depset(
        # order = dsorder,
        # ## direct = ns_resolver_files,
        # transitive = ([ns_resolver_depset] if ns_resolver_depset else []) + [inputs_depset]
        # # + indirect_inputs_depsets
    )

    # fileset_depset = depset(
    #         transitive=([ns_resolver_depset] if ns_resolver_depset else []) + indirect_fileset_depsets
    # )

    ## build depsets here, use for OcamlProvider and OutputGroupInfo
    sigs_depset = depset(order=dsorder, transitive = depsets.deps.sigs)
    structs_depset = depset(order=dsorder,
                            # direct=structs_primary,
                            transitive = depsets.deps.structs)
                            # transitive=structs_secondary)
    ofiles_depset  = depset(order=dsorder,
                            # direct=ofiles_primary,
                            transitive = depsets.deps.ofiles)
                            # transitive=ofiles_secondary)
    ## FIXME: add unarchived module deps of archives
    archives_depset = depset(order="postorder",
                             # direct = archives_primary,
                             transitive = depsets.deps.archives)
                             # transitive = archives_secondary)
    afiles_depset  = depset(order=dsorder,
                             # direct=afiles_primary,
                            transitive = depsets.deps.afiles)
                             # transitive=afiles_secondary)
    astructs_depset = depset(order=dsorder,
                             # direct = astructs_primary,
                             transitive = depsets.deps.astructs)
                         # transitive = astructs_secondary)
    paths_depset  = depset(order = dsorder,
                           transitive = depsets.deps.paths)

    # if ctx.attr._rule.endswith("archive"):
    #     cli_link_deps_depset = depset()
    # else:

    cli_link_deps_depset = depset(order = dsorder,
                                  # direct = ns resolver,
                                  transitive = depsets.deps.cli_link_deps
                                  )

        # direct = paths_primary + ns_paths,
        # transitive = indirect_paths_depsets
    # )

    ##FIXME: do we need this?
    # resolvers_depset = depset(order=dsorder,
    #                           # direct=resolvers_primary,
    #                           transitive=resolvers_secondary)

    # cclibs_depset = depset(order="postorder",
    #                          direct = cclibs_primary,
    #                          transitive = cclibs_secondary)

    # print("new_linkargs: %s" % new_linkargs)
    ocamlProvider = OcamlProvider(
        sigs     = sigs_depset,
        structs  = structs_depset,
        ofiles   = ofiles_depset,
        archives = archives_depset,
        afiles   = afiles_depset,
        astructs = astructs_depset,

        # resolvers = resolvers_depset,
        paths    = paths_depset,
        cli_link_deps = cli_link_deps_depset
    )
    providers.append(ocamlProvider)
    # print("ocamlProvider: %s" % ocamlProvider)

    outputGroupInfo = OutputGroupInfo(
        # resolver   = ns_resolver_files,
        # fileset    = fileset_depset,
        # cdeps      = cdeps_depset,
        # ldeps      = ldeps_depset,

        sigs     = sigs_depset,
        structs  = structs_depset,
        ofiles   = ofiles_depset,
        archives = archives_depset,
        afiles  = afiles_depset,
        astructs= astructs_depset,

        # ppx_codeps = ppx_codeps_depset,
        # cc = ... extract from CcInfo?
        all = depset(
            order = dsorder,
            transitive=[
                new_inputs_depset,
            ]
        )
    )
    providers.append(outputGroupInfo)

    # providers = [
    #     defaultInfo,
    #     ocamlProvider,
    #     outputGroupInfo,
    # ]

    ## Provider 3: Library Marker
    providers.append(
        OcamlLibraryMarker(marker = "OcamlLibraryMarker")
    )

    ## Provider 4: possibly empty PpxCodepsProvider
    ################ ppx codeps ################
    # if ppx:
    codep_archives_depset = depset(
        order=dsorder,
        transitive = depsets.codeps.archives)
        # transitive=codep_archives_secondary)
    codep_afiles_depset = depset(
        order=dsorder,
        transitive = depsets.codeps.afiles)
        # direct=codep_astructs_primary,
            # transitive=codep_afiles_secondary)
    codep_astructs_depset = depset(
        order=dsorder,
        transitive = depsets.codeps.astructs)
            # direct=codep_astructs_primary,
            # transitive=codep_astructs_secondary)

    ppxCodepsProvider = PpxCodepsProvider(
        # ppx_codeps = ppx_codeps_depset,
        sigs    = depset(order=dsorder,
                         transitive = depsets.codeps.sigs),
        cli_link_deps = depset(order=dsorder,
                               transitive = depsets.codeps.cli_link_deps),
        structs    = depset(order=dsorder,
                            transitive = depsets.codeps.structs),
        ofiles    = depset(order=dsorder,
                           transitive = depsets.codeps.ofiles),
        archives  = codep_archives_depset,
        afiles    = codep_afiles_depset,
        astructs  = codep_astructs_depset,
        paths     = depset(order = dsorder,
                           transitive = depsets.codeps.paths),
        jsoo_runtimes = depset(order="postorder",
                               transitive = depsets.codeps.jsoo_runtimes),
    )
    providers.append(ppxCodepsProvider)
    # else:
    #     providers.append(PpxCodepsProvider(
    #         sigs = depset(), structs = depset(),  ofiles = depset(),
    #         archives = depset(), afiles = depset(), astructs = depset(),
    #         paths = depset()
    #     ))

    ## Provider 5: possibly empty CcInfo
    # ccInfo_merged = cc_common.merge_cc_infos(cc_infos = ccinfos)
    # # if ctx.label.name == "tezos-legacy-store":
    # print("ccInfo_merged: %s" % ccInfo_merged)
    # # dump_CcInfo(ctx, ccInfo_merged)
    # if ccinfos:
    #     providers.append(ccInfo_merged)
    # else:
    #     providers.append(CcInfo())
    ccInfo = cc_common.merge_cc_infos(
        # direct_cc_infos =
        cc_infos = depsets.ccinfos
    )

    if ctx.label.name == "js_of_ocaml":
        dump_CcInfo(ctx, ccInfo)

    providers.append(ccInfo)

    ## Provider 6: optional NS marker
    # if ctx.attr._rule.startswith("ocaml_ns"):
    if hasattr(ctx.attr, "_ns_resolver"):
    # if ns_enabled:
        providers.append(
            OcamlNsMarker(
                marker = "OcamlNsMarker",
                # ns_name = ns_name if ns_resolver else ""
            ),
        )

    ## if namespaced, then return OcamlNsResolverProvider, so that
    ## tools can find the resolver, e.g. @obazl//inspect:src

    # print("LIB providers: %s" % providers)

    return providers
