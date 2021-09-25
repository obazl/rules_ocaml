load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",

     "OcamlProvider",
     "OcamlNsResolverProvider",

     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",

     "PpxAdjunctsProvider")


load(":impl_ccdeps.bzl", "dump_ccdep")

load("//ocaml/_functions:utils.bzl", "get_sdkpath")

load(":impl_common.bzl", "dsorder")

## Library targets do not produce anything, they just pass on their deps.

## NS Lib targets also do not directly produce anything, they just
## pass on their deps. The real work is done in the transition
## functions, which set the ConfigState that controls build actions of
## deps.

#################
def impl_library(ctx):

    debug = False
    # print("**** NS_LIB {} ****************".format(ctx.label))

    env = {"PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ns_resolver = ctx.attr._ns_resolver if ctx.attr._rule.startswith("ocaml_ns") else []
    ns_resolver_files = ctx.files._ns_resolver if ctx.attr._rule.startswith("ocaml_ns") else []

    ################
    ## FIXME: does lib need to handle adjunct deps? they're carried by
    ## modules
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []

    ################
    paths_direct   = []
    # resolver_depsets_list = []

    #######################
    if ctx.attr._rule == "ocaml_ns_archive":
        direct_dep_files = ctx.files.submodules
    elif ctx.attr._rule == "ocaml_ns_library":
        direct_dep_files = ctx.files.submodules
    elif ctx.attr._rule == "ocaml_archive":
        direct_dep_files = ctx.files.modules
    elif ctx.attr._rule == "ocaml_library":
        direct_dep_files = ctx.files.modules
    else:
        fail("impl_library called by non-aggregator: %s" % ctx.attr._rule)

    for f in direct_dep_files:
        paths_direct.append(f.dirname)

    #### INDIRECT DEPS first ####
    # these are "indirect" from the perspective of the consumer
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    ccInfo_list = []

    the_deps = ctx.attr.submodules if ctx.attr._rule.startswith("ocaml_ns") else ctx.attr.modules
    for dep in the_deps:
        # ignore DefaultInfo, its just for printing, not propagation

        if OcamlProvider in dep: # should always be True
            indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
            indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
            indirect_paths_depsets.append(dep[OcamlProvider].paths)

        if CcInfo in dep:
            ## we do not need to do anything with ccdeps here,
            ## just pass them on in a provider
            ccInfo_list.append(dep[CcInfo])

        if PpxAdjunctsProvider in dep:
            indirect_adjunct_path_depsets.append(dep[PpxAdjunctsProvider].paths)
            indirect_adjunct_depsets.append(dep[PpxAdjunctsProvider].ppx_codeps)

    if ctx.attr._rule.startswith("ocaml_ns"):
        for f in ns_resolver_files:
            paths_direct.append(f.dirname)

    inputs_depset = depset(
        order = dsorder,
        direct = ns_resolver_files,
        transitive = indirect_inputs_depsets
        + [depset(direct_dep_files)]
    )

    #######################
    ## Do we need to do this? Why?
    ctx.actions.do_nothing(
        mnemonic = "NS_LIB",
        inputs = inputs_depset
    )
    #######################

    #### PROVIDERS ####
    defaultDepset = depset(
        order = dsorder,
        direct = ns_resolver_files,
        transitive = [depset(direct_dep_files)]
    )

    defaultInfo = DefaultInfo(
        files = defaultDepset
    )

    ################ ppx codeps ################
    ppx_codeps_depset = depset(
        order = dsorder,
        transitive = indirect_adjunct_depsets
    )
    ppxAdjunctsProvider = PpxAdjunctsProvider(
        ppx_codeps = ppx_codeps_depset,
        paths        = depset(
            order = dsorder,
            transitive = indirect_adjunct_path_depsets
        )
    )

    new_inputs_depset = depset(
        order = dsorder,
        direct = ns_resolver_files,
        transitive = indirect_inputs_depsets
    )
    linkargs_depset = depset(
        order = dsorder,
        direct = ns_resolver_files,
        transitive = indirect_linkargs_depsets
    )
    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = indirect_paths_depsets
    )

    ocamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,
        ns_resolver = ns_resolver,
    )

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
            OcamlNsMarker(marker = "OcamlNsMarker"),
        )

    if ccInfo_list:
        providers.append(
            cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        )

    return providers
