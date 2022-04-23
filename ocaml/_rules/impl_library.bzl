load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",

     "OcamlProvider",
     "OcamlNsResolverProvider",

     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
)

load(":impl_common.bzl", "dsorder", "module_sep", "resolver_suffix")

load(":impl_ccdeps.bzl", "dump_CcInfo")

# load("//ocaml/_functions:utils.bzl", "get_sdkpath")

## Plain Library targets do not produce anything, they just pass on
## their deps.

## NS Lib targets also do not directly produce anything, they just
## pass on their deps. The real work is done in the transition
## functions, which set the ConfigState that controls build actions of
## deps.

#################
def impl_library(ctx, mode, tool, tool_args):

    debug = False
    # print("**** NS_LIB {} ****************".format(ctx.label))

    # env = {"PATH": get_sdkpath(ctx)}

    # tc = ctx.toolchains["@rules_ocaml//ocaml:toolchain"]

    # mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ns_resolver_depset = None
    ns_resolver_module = None
    ns_resolver = []
    ns_resolver_files = []
    the_ns_resolvers = []

    # WARNING: due to transition processing, ns_resolver providers
    # must be indexed by [0]

    if ctx.attr._rule.startswith("ocaml_ns"):
        # print("tgt: %s" % ctx.label)
        # print("rule: %s" % ctx.attr._rule)

        if ctx.attr.resolver:
            # print("user-provided resolver")
            ns_resolver = ctx.attr.resolver
            ns_resolver_module = ctx.file.resolver
            ns_name = ctx.attr.ns
        else:
            # print("generated resolver")
            # print("NS RESOLVER FILECT: %s" % len(ctx.files._ns_resolver))
            ns_resolver = ctx.attr._ns_resolver[0] # index by int
            ns_resolver_module = ctx.files._ns_resolver[0]

        # print("ns_resolver: %s" % ns_resolver)
        # print("ns_resolver_module: %s" % ns_resolver_module)

        if OcamlNsResolverProvider in ns_resolver:
            # print("LBL: %s" % ctx.label)
            # print("ns_resolver: %s" % ns_resolver[OcamlNsResolverProvider])
            if hasattr(ns_resolver[OcamlNsResolverProvider], "ns_name"):
                ns_name = ns_resolver[OcamlNsResolverProvider].ns_name
            else:
                # FIXME: when does this happen?
                ns_name = ""

        ## if ns_resolver ends in __0Resolver, then we know that one
        ## of the submodules is a user-provided resolver; the
        ## __0Resolver was just used to compile the submodules. So we
        ## need to find the user-provided resolver (its name matches
        ## the ns name), and make all the other submodules depend on
        ## it.

        ## pathological case: ns contains a single user-provided
        ## resolver. in that case we have no aliases so no resolver.
        ## there would be no point in such an ns but its possible.
        if ns_resolver_module:
            # print("LBL: %s" % ctx.label)
            (ns_resolver_mname, ext) = paths.split_extension(ns_resolver_module.basename)
            # print("ns_resolver_mname: %s" % ns_resolver_mname)
            if ns_resolver_mname == ns_name + resolver_suffix:
                print("Resolver is user-provided")
                user_provided_resolver = True
            else:
                user_provided_resolver = False
        else:
            user_provided_resolver = False

        if user_provided_resolver:
            ##FIXME: efficiency
            for submodule in ctx.files.submodules:
                (bname, ext) = paths.split_extension(submodule.basename)
                if bname == ns_name:
                    print("Found user-provided resolver submodule")
                    the_ns_resolvers.append(submodule)
        # else:
        if OcamlProvider in ns_resolver: ##ctx.attr._ns_resolver[0]:
            # print("ns_resolver provider: %s" % ns_resolver[OcamlProvider])
            ns_resolver_files = ns_resolver[OcamlProvider].inputs
            ns_resolver_depset = ns_resolver[OcamlProvider].inputs

        # the_ns_resolvers.append(ns_resolver_module[0])

    # print("ns_resolver_depset: %s" % ns_resolver_depset)
    # print("ns_name: %s" % ns_name)

    ################
    ## FIXME: does lib need to handle adjunct deps? they're carried by
    ## modules
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []

    ################
    paths_direct   = []
    # resolver_depsets_list = []

    #######################
    direct_deps_attr = None
    if ctx.attr._rule == "ocaml_ns_archive":
        direct_dep_files = ctx.files.submodules
        direct_deps_attr = ctx.attr.submodules
    elif ctx.attr._rule == "ocaml_ns_library":
        direct_dep_files = ctx.files.submodules
        direct_deps_attr = ctx.attr.submodules
    elif ctx.attr._rule == "ocaml_archive":
        direct_dep_files = ctx.files.manifest
        direct_deps_attr = ctx.attr.manifest
    elif ctx.attr._rule == "ocaml_library":
        direct_dep_files = ctx.files.manifest
        direct_deps_attr = ctx.attr.manifest
    else:
        fail("impl_library called by non-aggregator: %s" % ctx.attr._rule)

    ## FIXME: direct_dep_files (and direct_deps_attr) are in the order
    ## set by the submodule/modules attribute; they must be put in
    ## dependency-order.

    for f in direct_dep_files:
        paths_direct.append(f.dirname)

    # if ctx.label.name == "tezos-shell":
    #     print("LBL: %s" % ctx.label)
    #     for dep in direct_deps_attr:
    #         print("DEP: %s" % dep[OcamlProvider].fileset)

    #### INDIRECT DEPS first ####
    # these are "indirect" from the perspective of the consumer
    indirect_fileset_depsets = []
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    ccInfo_list = []

    direct_module_deps_files = ctx.files.submodules if ctx.attr._rule.startswith("ocaml_ns") else ctx.files.manifest

    direct_module_deps = ctx.attr.submodules if ctx.attr._rule.startswith("ocaml_ns") else ctx.attr.manifest

    for dep in direct_module_deps:
        # if ctx.label.name == 'tezos-base':
        #     print("DEPPP: %s" % dep)
        # ignore DefaultInfo, its just for printing, not propagation

        if OcamlProvider in dep: # should always be True
            # if ctx.label.name == 'tezos-base':
            #     print("directdep: %s" % dep[OcamlProvider])

            indirect_fileset_depsets.append(dep[OcamlProvider].fileset)

            # linkargs: what goes on cmd line to build archive or
            # executable FIXME: __excluding__ sibling modules! Why?
            # because even if we put only indirect deps in linkargs,
            # the head (direct) dep could still appear anywhere in the
            # dep closure; in particular, we may have sibling deps, in
            # which case omitting the head dep for linkargs would do
            # us no good. So we need to filter to remove ALL
            # (sub)modules from linkargs.

            # if linkarg not in direct_module_deps_files:
            indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)

            # if ctx.label.name == "tezos-base":
            #     print("LIBDEP LINKARGS: %s" % dep[OcamlProvider].linkargs)
            # indirect_linkargs_depsets.append(dep[OcamlProvider].files)

            ## inputs == all deps
            indirect_inputs_depsets.append(dep[OcamlProvider].inputs)

            indirect_paths_depsets.append(dep[OcamlProvider].paths)

        indirect_linkargs_depsets.append(dep[DefaultInfo].files)

        if CcInfo in dep:
            ## we do not need to do anything with ccdeps here,
            ## just pass them on in a provider
            # if ctx.label.name == "tezos-legacy-store":
            #     dump_CcInfo(ctx, dep)
            ccInfo_list.append(dep[CcInfo])

        if PpxCodepsProvider in dep:
            indirect_adjunct_path_depsets.append(dep[PpxCodepsProvider].paths)
            indirect_adjunct_depsets.append(dep[PpxCodepsProvider].ppx_codeps)

    # print("indirect_inputs_depsets: %s" % indirect_inputs_depsets)

    # normalized_direct_dep_files = []
    # for dep in direct_dep_files:
    #     print("direct dep: %s" % dep)
    #     print("the_ns_resolvers: %s" % the_ns_resolvers)
    #     # (bname, ext) = paths.split_extension(dep.basename)
    #     if dep.basename not in the_ns_resolvers: ## [0].basename:
    #         normalized_direct_dep_files.append(dep)
    #     else:
    #         print("removing %s" % dep)

    inputs_depset = depset(
        order = dsorder,
        direct = direct_dep_files,
        transitive = ([ns_resolver_depset] if ns_resolver_depset else []) + indirect_inputs_depsets
        # + [depset(direct_dep_files)]
    )

    ## To put direct deps in dep-order, we need to merge the linkargs
    ## deps and iterate over them:
    new_linkargs = []
    ## start with ns_resolver:
    if ctx.attr._rule.startswith("ocaml_ns"):
        if ns_resolver:
            for f in ns_resolver[DefaultInfo].files.to_list():
            # for f in ns_resolver[0].files.to_list():
                paths_direct.append(f.dirname)
                new_linkargs.append(f)

    linkargs_depset = depset(
        order = dsorder,
        ## direct = ns_resolver_files,
        transitive = indirect_linkargs_depsets
        # transitive = ([ns_resolver_depset] if ns_resolver_depset else []) + indirect_linkargs_depsets
    )
    for dep in inputs_depset.to_list():
        if dep in direct_dep_files:
            new_linkargs.append(dep)

    #######################
    ## Do we need to do this? Why?
    ctx.actions.do_nothing(
        mnemonic = "NS_LIB",
        inputs = inputs_depset
    )
    #######################
    # print("INPUTS_DEPSET: %s" % inputs_depset)

    # print("the_ns_resolvers: %s" % the_ns_resolvers)

    #### PROVIDERS ####
    defaultDepset = depset(
        order = dsorder,
        # direct = normalized_direct_dep_files, # ns_resolver_module,
        # transitive = [depset(direct = the_ns_resolvers)]

        direct = the_ns_resolvers + [ns_resolver_module] if ns_resolver_module else [],
        transitive = [depset(direct_dep_files)]
        # transitive = [depset(normalized_direct_dep_files)]
    )

    defaultInfo = DefaultInfo(
        files = defaultDepset
    )

    ################ ppx codeps ################
    ppx_codeps_depset = depset(
        order = dsorder,
        transitive = indirect_adjunct_depsets
    )
    ppxAdjunctsProvider = PpxCodepsProvider(
        ppx_codeps = ppx_codeps_depset,
        paths        = depset(
            order = dsorder,
            transitive = indirect_adjunct_path_depsets
        )
    )

    new_inputs_depset = depset(
        order = dsorder,
        ## direct = ns_resolver_files,
        transitive = ([ns_resolver_depset] if ns_resolver_depset else []) + [inputs_depset]
        # + indirect_inputs_depsets
    )

    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = indirect_paths_depsets
    )

    # print("new_linkargs: %s" % new_linkargs)
    ocamlProvider = OcamlProvider(
        files   = depset(direct=new_linkargs),
        fileset = depset(
            transitive=([ns_resolver_depset] if ns_resolver_depset else []) + indirect_fileset_depsets
        ),
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,
        ns_resolver = ns_resolver,
    )
    # print("ocamlProvider: %s" % ocamlProvider)

    outputGroupInfo = OutputGroupInfo(
        resolver = ns_resolver_files,
        ppx_codeps = ppx_codeps_depset,
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
        ppxAdjunctsProvider,
        outputGroupInfo,
    ]

    providers.append(
        OcamlLibraryMarker(marker = "OcamlLibraryMarker")
    )

    if ctx.attr._rule.startswith("ocaml_ns"):
        providers.append(
            OcamlNsMarker(
                marker = "OcamlNsMarker",
                ns_name = ns_name if ns_resolver else ""
            ),
        )

    # if ctx.label.name == "tezos-legacy-store":
    #     print("ccInfo_list ct: %s" % len(ccInfo_list))
    ccInfo_merged = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
    # if ctx.label.name == "tezos-legacy-store":
    #     print("ccInfo_merged: %s" % ccInfo_merged)
    if ccInfo_list:
        providers.append(ccInfo_merged)

    return providers
