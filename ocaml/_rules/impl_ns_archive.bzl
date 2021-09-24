load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",

     "PpxAdjunctsProvider",
     "OcamlArchiveProvider",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_projroot",
     "get_sdkpath",
)

load(":impl_ns_library.bzl", "impl_ns_library")

load("//ocaml/_functions:utils.bzl", "normalize_module_name")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "tmpdir", "dsorder")

#################
def impl_ns_archive(ctx):

    print("**** NS_ARCH {} ****************".format(ctx.label))

    debug = True #False

    env = {"PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ################################
    ####  call impl_ns_library  ####
    # FIXME: smooth this out!
    nslib_providers = impl_ns_library(ctx)

    defaultInfo = nslib_providers[0]
    nslibMarker = nslib_providers[1]
    ocamlProvider = nslib_providers[2]
    ppxAdjunctsProvider = nslib_providers[3]
    outputGroupInfo = nslib_providers[4]
    ccInfo  = nslib_providers[5] if len(nslib_providers) == 6 else False

    ################################
    print("==== resume NS_ARCH {} ****************".format(ctx.label))

    if ocamlProvider.ns_resolver == None:
        print("NO NSRESOLVER FROM NSLIB")
        fail("NO NSRESOLVER FROM NSLIB")
    else:
        if debug:
            print("ARCH GOT NSRESOLVER FROM NSLIB: %s" % ocamlProvider.ns_resolver)

    all_deps = ocamlProvider.files
    paths_direct = []
    paths_indirect = ocamlProvider.paths

    action_outputs = []

    _options = get_options(ctx.attr._rule, ctx)

    shared = False
    if ctx.attr.shared:
        shared = ctx.attr.shared or "-shared" in _options
        if shared:
            if "-shared" in _options:
                _options.remove("-shared") ## avoid dup

    if mode == "native":
        if shared:
            ext = ".cmxs"
        else:
            ext = ".cmxa"
    else:
        ext = ".cma"

    # ns_ext = ".cmxa" if mode == "native" else ".cma"

    ns_archive_a_filename = tmpdir + ns_archive_name + ".a"
    ns_archive_a_file = ctx.actions.declare_file(ns_archive_a_filename)
    paths_direct.append(ns_archive_a_file.dirname)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    args.add_all(_options)
    # for d in all_deps.to_list():
    #     # print("ALL_DEPS: %s" % d)
    #     # if d.extension == "o":

    # submods = ctx.files.submodules
    # for dep in nslibMarker.depgraph.to_list():
    #     if dep in submods:
    #         if dep.extension in ["cmx", "cmxa"]:
    #             args.add(dep)
    #     ## direct submod deplist may not contain resolver
    #     elif dep.extension == "cmx":
    #         mod = normalize_module_name(dep.basename)
    #         if mod == ns_archive_name:
    #             args.add(dep)
    #         elif mod == ns_archive_name + "__0Resolver":
    #             args.add(dep)

    args.add("-a")

    args.add("-o", ns_archive_file)


    if ctx.attr._rule == "ocaml_ns_archive":
        mnemonic = "CompileOcamlNsArchive"
    elif ctx.attr._rule == "ocaml_archive":
    else:
        fail("Unexpected rule type for impl_ns_archive: %s" % ctx.attr_rule)

    ################
    ################
    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = all_deps, # nslibMarker.depgraph,
        outputs = [ns_archive_file, ns_archive_a_file],
        mnemonic = mnemonic,
        progress_message = "{mode} compiling {rule}: @{ws}//{pkg}:{tgt}".format(
            mode = mode,
            rule = ctx.attr._rule,
            ws  = ctx.label.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )
    ###################
    #### PROVIDERS ####
    ###################

    ## DefaultInfo.files: .cmxa only
    ## OcamlProvider
    ##   .files: .cmxa, .a, all_deps=resolver, submod deps, archive deps
    ##   .archives: depset of archive deps
    ##   .archive_deps: depset of deps of archive deps
    ##   .path: depset of all dep paths
    ## OcamlArchiveProvider
    ##   .files: archives_depset

    default_depset = depset(
        order  = dsorder,
        direct = [archive_a_file, archive_file],
        # transitive = [ocamlProvider.files]
    )

    newDefaultInfo = DefaultInfo(
        files = default_depset
    )

    ppx_adjuncts_depset = ppxAdjunctsProvider.ppx_adjuncts
    ###########################
    new_inputs_depset = depset(
        direct     = action_outputs + ns_resolver,
        transitive = [ocamlProvider.inputs]
    )

    subdeps_depset = depset(
        ## subdeps excluding direct deps
        direct = subdeps_list
    )

    linkargs_depset = depset(
        direct     = action_outputs, #[archive_file],
        ## FIXME: ocamlProvider.linkargs will contain all the stuff for an ns library
        transitive = [subdeps_depset]
        # transitive = [ordered_submodules_depset]
        # transitive = [ocamlProvider.linkargs]
    )
    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = [ocamlProvider.paths]
        # transitive = paths_indirect
    )

    # provider_depset = depset(provider_output)
    ocamlProvider_files = depset(
        order  = dsorder,
        direct = action_outputs, #  + ctx.files._ns_resolver,
        transitive = [ocamlProvider.files]

        # transitive = [new_depset]
        # transitive = [all_deps]
        # transitive = [provider_depset]
    )
    ocamlProviderPaths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = [ocamlProvider.paths]
    )

    archiveProvider_files = depset(
        direct = action_outputs, # + ctx.files._ns_resolver,
        transitive =
            [ocamlProvider.archives] if ocamlProvider.archives else []
    )

    _archive_deps = depset(
        direct = action_outputs,
        transitive = [ocamlProvider.archive_deps] if ocamlProvider.archive_deps else None
    )

    ocamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,
        # paths = ocamlProviderPaths_depset

        files = ocamlProvider_files,
        # archives = archiveProvider_files,
        archives = depset(action_outputs), # archiveProvider_files,
        archive_deps = _archive_deps,
    )

    archiveProvider = OcamlArchiveProvider(
        files = archiveProvider_files
    )

    outputGroupInfo = OutputGroupInfo(
        resolver = ns_resolver,
        ppx_adjuncts = ppx_adjuncts_depset,
        # cclibs = cclib_files_depset,
        inputs = ocamlProvider.files,
        linkargs = linkargs_depset,
        subdeps = subdeps_depset,
        archives = archiveProvider_files,
        all = depset(transitive=[
            # default_depset,
            ocamlProvider_files,
            archiveProvider_files,
            ppx_adjuncts_depset,
            # cclib_files_depset,
        ])
    )

    providers = [
        newDefaultInfo,
        ocamlProvider,
        archiveProvider,
        OcamlNsMarker(marker = "OcamlNsMarker"),
        outputGroupInfo,
        ppxAdjunctsProvider,
        # ccDepsProvider
    ]
    if ccInfo:
        providers.append(ccInfo)

    return providers


