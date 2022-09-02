load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",

     "OcamlProvider",
     "OcamlNsResolverProvider",

     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker")

load("//ocaml/_functions:module_naming.bzl",
     "normalize_module_label",
     "normalize_module_name")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
)

load(":impl_common.bzl", "dsorder", "module_sep", "resolver_suffix")

load(":impl_ccdeps.bzl", "dump_CcInfo")

load("//ocaml/_debug:colors.bzl", "CCRED", "CCDER", "CCGRN", "CCMAG", "CCRESET")
# load("//ocaml/_functions:utils.bzl", "get_sdkpath")

## Plain Library targets do not produce anything, they just pass on
## their deps.

## NS Lib targets also do not directly produce anything, they just
## pass on their deps. The real work is done in the transition
## functions, which set the ConfigState that controls build actions of
## deps.


# if this is an ns_library then we need to pass on the deps from the
# ns resolver
#################
def _handle_ns_library(ctx):
    debug = False

    if debug: print("_handle_ns_library")

    # ns_resolver_depset = None
    # ns_resolver_module = None
    ns_resolver = []
    # ns_resolver_files = []
    the_ns_resolvers = []
    ns_paths = []

    if hasattr(ctx.attr, "resolver"):
        if debug: print("user-provided resolver")
        ns_resolver = ctx.attr.resolver
        ns_resolver_module = ctx.file.resolver
        # if ctx.attr.ns:
        #     ns_name = ctx.attr.ns
        # else:
        #     ns_name = normalize_module_name(ctx.attr.resolver.label.name)
    else:
        if debug:
            print("generated resolver")
            print("NS RESOLVER FILECT: %s" % len(ctx.files._ns_resolver))
        ns_resolver = ctx.attr._ns_resolver[0] # index by int
        ns_resolver_module = ctx.files._ns_resolver[0]

    # print("ns_resolver: %s" % ns_resolver)
    # print("ns_resolver_module: %s" % ns_resolver_module)

    # if OcamlNsResolverProvider in ns_resolver:
    #     # print("LBL: %s" % ctx.label)
    #     # print("ns_resolver: %s" % ns_resolver[OcamlNsResolverProvider])
    #     if hasattr(ns_resolver[OcamlNsResolverProvider], "ns_name"):
    #         ns_name = ns_resolver[OcamlNsResolverProvider].ns_name
    #     else:
    #         # FIXME: when does this happen?
    #         ns_name = ""

    # if ns_resolver_module:
    #     # print("LBL: %s" % ctx.label)
    #     (ns_resolver_mname, ext) = paths.split_extension(ns_resolver_module.basename)
    #     # print("ns_resolver_mname: %s" % ns_resolver_mname)
    #     if ns_resolver_mname == ns_name + resolver_suffix:
    #         print("Resolver is user-provided")
    #         user_provided_resolver = True
    #     else:
    #         user_provided_resolver = False
    # else:
    #     user_provided_resolver = False

    # if user_provided_resolver:
    #     ##FIXME: efficiency
    #     for submodule in ctx.files.submodules:
    #         (bname, ext) = paths.split_extension(submodule.basename)
    #         if bname == ns_name:
    #             print("Found user-provided resolver submodule")
    #             the_ns_resolvers.append(submodule)
    #             # else:
    # if OcamlProvider in ns_resolver: ##ctx.attr._ns_resolver[0]:
        # print("ns_resolver provider: %s" % ns_resolver[OcamlProvider])
        # ns_resolver_files = ns_resolver[OcamlProvider].inputs
        # ns_resolver_depset = ns_resolver[OcamlProvider].inputs

    ns_paths.append(ns_resolver_module.dirname)
    the_ns_resolvers.append(ns_resolver_module)

    # print("ns_resolver_depset: %s" % ns_resolver_depset)
    # print("ns_name: %s" % ns_name)
    return(## ns_name,
        ns_resolver, ns_resolver_module,
        # ns_resolver_depset, ns_resolver_files,
        ns_paths,
        the_ns_resolvers
    )

#################
def impl_library(ctx):

    debug      = False
    debug_deps = False
    debug_ns   = False

    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]

    ppx = False

    if debug: print("\n**** NS_LIB {} ****************".format(ctx.label))

    # env = {"PATH": get_sdkpath(ctx)}

    # WARNING: due to transition processing, ns_resolver providers
    # must be indexed by [0]

    # this implementation is used by both ocaml_library and
    # ocaml_ns_library
    if ctx.attr._rule.startswith("ocaml_ns"):
        (# ns_name,
        ns_resolver,
        ns_resolver_module,
        # ns_resolver_files,
        # ns_resolver_depset,
        ns_paths,
        the_ns_resolvers) = _handle_ns_library(ctx) #, mode, tool, tool_args)
    else:
        #ns_name            = None
        ns_resolver        = None
        ns_resolver_module = None
        # ns_resolver_files  = []
        # ns_resolver_depset = None
        ns_paths = []
        the_ns_resolvers   = None

    ns_enabled = False
    ## only for ocaml_ns_library, ocaml_ns_archive:
    if hasattr(ctx.attr, "_ns_resolver"):
        ns_enabled = True

    ################################################################
                   ####    DEPENDENCIES    ####

    ################
    ## FIXME: does lib need to handle ppx_codeps? they're carried by
    ## modules
    indirect_codeps_depsets      = []
    indirect_codeps_path_depsets = []

    sigs_primary   = []
    sigs_secondary = []
    structs_primary   = []
    structs_secondary = []
    ofiles_primary   = [] # never? ofiles only come from deps
    ofiles_secondary = []
    astructs_primary = []
    astructs_secondary = []
    afiles_primary   = []
    afiles_secondary = []
    archives_primary = []
    archives_secondary = []

    resolvers_secondary = []
    # cclibs_primary = []
    # cclibs_secondary = []

    ################
    paths_primary   = []
    # resolver_depsets_list = []

    #### First the ns resolver IF we're an ns rule
    debug_ns = True
    if ns_enabled:
        if debug_ns: print("{c}ns processing{r}".format(c=CCRED, r=CCRESET))
        ## we always have _ns_resolver, since it defaults to
        ## "@rules_ocaml//cfg/ns:resolver", but it will be null unless
        ## we're in an ns. attr.resolver overrides.

        if hasattr(ctx.attr, "resolver"):
            if debug_ns: print("user-provided resolver")
            ns_resolver = ctx.attr.resolver
        else:
            ns_resolver = ctx.attr._ns_resolver
            if debug_ns: print("implicit resolver: %s" % ns_resolver)

            # WARNING: index by int not provider (due to transition fn)
            nsr = ns_resolver[0][OcamlNsResolverProvider]
            nsr_dep = ns_resolver[0][OcamlProvider]
            if debug_ns:
                print("nsr[0]: %s" % ns_resolver[0])
                print("nsr: %s" % nsr)
                print("{c}ns_resolver{r}: {s}".format(c=CCGRN,r=CCRESET,s=nsr))
                print("ns name: %s" % nsr.ns_name)
                print("nsr_dep: %s" % nsr_dep)

            # WARNING: beware of empty nss, with empty providers
            if hasattr(nsr, "cmi"):
                sigs_primary.append(nsr.cmi) ## (nsr_dep.sigs)
            if hasattr(nsr, "struct"):
                structs_primary.append(nsr.struct) # nsr_dep.structs)
            if hasattr(nsr, "ofile"):
                if  tc.target != "vm":
                    ofiles_primary.append(nsr.ofile) # nsr_dep.ofiles)
            archives_secondary.append(nsr_dep.archives)
            afiles_secondary.append(nsr_dep.afiles)
            astructs_secondary.append(nsr_dep.astructs)
            # cclibs_secondary.append(nsr_dep.cclibs)

    # #######################
    # if hasattr(ctx.attr, "submodules"):
        ## only ocaml_ns_archive or ocaml_ns_library have submodules
        # print("Processing ns aggregator %s" % ctx.label)
        direct_dep_files = ctx.files.submodules
        direct_deps_attr = ctx.attr.submodules

        print("{c} end of ns processing{r}".format(c=CCRED,r=CCRESET))

    elif hasattr(ctx.attr, "manifest"):
        ## ocaml_archive or ocaml_library
        # print("Processing non-ns aggregator %s" % ctx.label)
        direct_dep_files = ctx.files.manifest
        direct_deps_attr = ctx.attr.manifest
    else:
        fail("missing both manifest and submodules attribs.")

    ## FIXME: direct_dep_files (and direct_deps_attr) are in the order
    ## set by the submodule/modules attribute; they must be put in
    ## dependency-order.

    # for f in direct_dep_files:
    #     paths_primary.append(f.dirname)

    # if ctx.label.name == "tezos-shell":
    #     print("LBL: %s" % ctx.label)
    #     for dep in direct_deps_attr:
    #         print("DEP: %s" % dep[OcamlProvider].fileset)

    #### INDIRECT DEPS first ####
    # these are "indirect" from the perspective of the consumer
    # cdeps_depsets = []
    # ldeps_depsets = []
    # indirect_fileset_depsets = []
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    ccInfo_list = []

    ##FIXME: this dups what's above with direct_dep_files ,direct_deps_attr
    direct_module_deps_files = ctx.files.submodules if ctx.attr._rule.startswith("ocaml_ns") else ctx.files.manifest

    direct_module_deps = []
    if ctx.attr._rule.startswith("ocaml_ns"):
        direct_module_deps.extend(ctx.attr.submodules)
    else:
        direct_module_deps.extend(ctx.attr.manifest)

    # if ctx.attr.resolver:
    #     direct_module_deps.append(ctx.file.resolver)

    # print("direct_module_deps: %s" % direct_module_deps)

    if debug_deps: print("iterating deps ****************")
    for dep in direct_module_deps:
        # if debug:
        #     print("LIB DEP: %s" % dep)
        # ignore DefaultInfo, its just for printing, not propagation

        if OcamlNsResolverProvider in dep:
            if debug_ns: print("OcamlNsResolverProvider: %s" % dep)

        if OcamlProvider in dep: # should always be True
            # if ctx.label.name == 'tezos-base':
            #     print("directdep: %s" % dep[OcamlProvider])

            # indirect_fileset_depsets.append(dep[OcamlProvider].fileset)

            # linkargs: what goes on cmd line to build archive or
            # executable FIXME: __excluding__ sibling modules! Why?
            # because even if we put only indirect deps in linkargs,
            # the head (direct) dep could still appear anywhere in the
            # dep closure; in particular, we may have sibling deps, in
            # which case omitting the head dep for linkargs would do
            # us no good. So we need to filter to remove ALL
            # (sub)modules from linkargs.

            # if linkarg not in direct_module_deps_files:
            # indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)

            # if ctx.label.name == "tezos-base":
            #     print("LIBDEP LINKARGS: %s" % dep[OcamlProvider].linkargs)
            # indirect_linkargs_depsets.append(dep[OcamlProvider].files)

            ## inputs == all deps
            # indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
            indirect_paths_depsets.append(dep[OcamlProvider].paths)

            # cdeps_depsets.append(dep[OcamlProvider].sigs)
            # ldeps_depsets.append(dep[OcamlProvider].structs)

            sigs_secondary.append(dep[OcamlProvider].sigs)
            if debug_ns:
                print("structs_secondary.append: %s" % dep[OcamlProvider].structs)
            structs_secondary.append(dep[OcamlProvider].structs)
            if  tc.target != "vm":
                ofiles_secondary.append(dep[OcamlProvider].ofiles)
            archives_secondary.append(dep[OcamlProvider].archives)
            afiles_secondary.append(dep[OcamlProvider].afiles)
            astructs_secondary.append(dep[OcamlProvider].astructs)
            # cclibs_secondary.append(dep[OcamlProvider].cclibs)

            # resolvers_secondary.append(dep[OcamlProvider].resolvers)

        indirect_linkargs_depsets.append(dep[DefaultInfo].files)

        if CcInfo in dep:
            ## we do not need to do anything with ccdeps here,
            ## just pass them on in a provider
            # if ctx.label.name == "tezos-legacy-store":
            #     dump_CcInfo(ctx, dep)
            ccInfo_list.append(dep[CcInfo])

        if PpxCodepsProvider in dep:
            ppx = True
            if debug_deps: print("PpxCodepsProvider: %s" % dep)
            # indirect_codeps_path_depsets.append(dep[PpxCodepsProvider].paths)
            # indirect_codeps_depsets.append(dep[PpxCodepsProvider].ppx_codeps)

    # print("indirect_inputs_depsets: %s" % indirect_inputs_depsets)

    # normalized_primary_dep_files = []
    # for dep in direct_dep_files:
    #     print("direct dep: %s" % dep)
    #     print("the_ns_resolvers: %s" % the_ns_resolvers)
    #     # (bname, ext) = paths.split_extension(dep.basename)
    #     if dep.basename not in the_ns_resolvers: ## [0].basename:
    #         normalized_primary_dep_files.append(dep)
    #     else:
    #         print("removing %s" % dep)

    # inputs_depset = depset(
    #     order = dsorder,
    #     direct = direct_dep_files,
    #     transitive = ([ns_resolver_depset] if ns_resolver_depset else []) + indirect_inputs_depsets
    #     + [depset(direct_dep_files)]
    # )

    if debug_deps:
        print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
        ## direct
        print("sigs_primary: %s" % sigs_primary)
        print("archives_primary: %s" % archives_primary)
        print("afiles_primary: %s" % afiles_primary)
        print("structs_primary: %s" % structs_primary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("astructs_primary: %s" % astructs_primary)
        # transitive
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_secondary: %s" % structs_secondary)
        ## archives cannot be direct deps?
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        print("astructs_secondary: %s" % astructs_secondary)
        # print("cclibs_secondary: %s" % cclibs_secondary)

    action_inputs_depset = depset(
        order = dsorder,
        direct =
        # [ctx.file.resolver]
        sigs_primary
        + structs_primary
        + archives_primary
        + afiles_primary
        + ofiles_primary
        + astructs_primary,
        transitive =
        sigs_secondary
        + structs_secondary
        + archives_secondary
        + afiles_secondary
        + ofiles_secondary
        + astructs_secondary
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
    defaultDepset = depset(
        order = dsorder,
        # direct = normalized_primary_dep_files, # ns_resolver_module,
        # transitive = [depset(direct = the_ns_resolvers)]

        direct = the_ns_resolvers + [ns_resolver_module] if ns_resolver_module else [],
        # direct = ctx.attr.resolver,
        transitive = [depset(direct_dep_files)]
        # transitive = [depset(normalized_primary_dep_files)]
    )

    defaultInfo = DefaultInfo(
        files = defaultDepset
    )

    new_inputs_depset = depset(
        # order = dsorder,
        # ## direct = ns_resolver_files,
        # transitive = ([ns_resolver_depset] if ns_resolver_depset else []) + [inputs_depset]
        # # + indirect_inputs_depsets
    )

    paths_depset  = depset(
        order = dsorder,
        direct = paths_primary + ns_paths,
        transitive = indirect_paths_depsets
    )

    # fileset_depset = depset(
    #         transitive=([ns_resolver_depset] if ns_resolver_depset else []) + indirect_fileset_depsets
    # )

    # cdeps_depset = depset(
    #     order = dsorder,
    #     transitive = cdeps_depsets
    # )

    # ldeps_depset = depset(
    #     order = dsorder,
    #     transitive = ldeps_depsets
    # )

    sigs_depset = depset(order=dsorder,
                         direct=sigs_primary,
                         transitive=sigs_secondary)
    structs_depset = depset(order=dsorder,
                            direct=structs_primary,
                            transitive=structs_secondary)
    ofiles_depset  = depset(order=dsorder,
                            direct=ofiles_primary,
                            transitive=ofiles_secondary)
    ## FIXME: add unarchived module deps of archives
    archives_depset = depset(order="postorder",
                             direct = archives_primary,
                             transitive = archives_secondary)
    afiles_depset  = depset(order=dsorder,
                             direct=afiles_primary,
                             transitive=afiles_secondary)
    astructs_depset = depset(order="postorder",
                         direct = astructs_primary,
                         transitive = astructs_secondary)
    resolvers_depset = depset(order=dsorder,
                              # direct=resolvers_primary,
                              transitive=resolvers_secondary)

    # cclibs_depset = depset(order="postorder",
    #                          direct = cclibs_primary,
    #                          transitive = cclibs_secondary)

    # print("new_linkargs: %s" % new_linkargs)
    ocamlProvider = OcamlProvider(
        # files   = depset(direct=new_linkargs),
        # fileset = fileset_depset,
        # inputs   = new_inputs_depset,
        # linkargs = linkargs_depset,
        # cdeps    = cdeps_depset,
        # ldeps    = ldeps_depset,

        sigs     = sigs_depset,
        structs  = structs_depset,
        ofiles   = ofiles_depset,
        archives = archives_depset,
        afiles   = afiles_depset,
        astructs = astructs_depset,
        # cclibs = cclibs_depset,

        resolvers = resolvers_depset,

        paths    = paths_depset,
        # ns_resolver = ns_resolver,
    )
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

    providers = [
        defaultInfo,
        ocamlProvider,
        outputGroupInfo,
    ]

    ## Provider 3: Library Marker
    providers.append(
        OcamlLibraryMarker(marker = "OcamlLibraryMarker")
    )

    ## Provider 4: possibly empty PpxCodepsProvider
    ################ ppx codeps ################
    # NOTE: PpxCodepsProvider goes on modules, not aggregates
    if ppx:
        ppx_codeps_depset = depset(
            order = dsorder,
            transitive = indirect_codeps_depsets
        )
        ppxCodepsProvider = PpxCodepsProvider(
            # ppx_codeps = ppx_codeps_depset,
            # paths        = depset(
            #     order = dsorder,
            #     transitive = indirect_codeps_path_depsets
            # )
        )
        providers.append(ppxCodepsProvider)
    else:
        providers.append(PpxCodepsProvider(
            sigs = depset(), structs = depset(),  ofiles = depset(),
            archives = depset(), afiles = depset(), astructs = depset(),
            paths = depset()
        ))

    ## Provider 4: possibly empty CcInfo
    ccInfo_merged = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
    # if ctx.label.name == "tezos-legacy-store":
    #     print("ccInfo_merged: %s" % ccInfo_merged)
    if ccInfo_list:
        providers.append(ccInfo_merged)
    else:
        providers.append(CcInfo())

    ## Provider 5: optional NS marker
    # if ctx.attr._rule.startswith("ocaml_ns"):
    if ns_enabled:
        providers.append(
            OcamlNsMarker(
                marker = "OcamlNsMarker",
                # ns_name = ns_name if ns_resolver else ""
            ),
        )

    ## if namespaced, then return OcamlNsResolverProvider, so that
    ## tools can find the resolver, e.g. @obazl//inspect:src


    return providers
