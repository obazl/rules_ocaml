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
     "get_projroot",
     "get_sdkpath",
)

load(":impl_library.bzl", "impl_library")

load("//ocaml/_functions:module_naming.bzl", "normalize_module_name")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "tmpdir", "dsorder")

#################
def impl_archive(ctx):

    print("**** NS_ARCH {} ****************".format(ctx.label))

    debug = False
    # if ctx.label.name == "Bare_structs":
    #     debug = True #False

    env = {"PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ns_resolver = ctx.files._ns_resolver if ctx.attr._rule.startswith("ocaml_ns") else []

    ################################
    ####  call impl_ns_library  ####
    # FIXME: smooth this out!
    nslib_providers = impl_library(ctx)

    defaultInfo = nslib_providers[0]
    ocamlProvider = nslib_providers[1]
    ppxAdjunctsProvider = nslib_providers[2]
    outputGroupInfo = nslib_providers[3]
    _ = nslib_providers[4] # OcamlLibraryMarker
    if ctx.attr._rule.startswith("ocaml_ns"):
        nslibMarker = nslib_providers[5]
        ccInfo  = nslib_providers[6] if len(nslib_providers) == 7 else False
    else:
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

    #### declare output files ####
    ## same for plain and ns archives
    archive_name = normalize_module_name(ctx.label.name)
    archive_filename = tmpdir + archive_name + ext
    archive_file = ctx.actions.declare_file(archive_filename)
    paths_direct.append(archive_file.dirname)
    action_outputs.append(archive_file)

    if mode == "native":
        archive_a_filename = tmpdir + archive_name + ".a"
        archive_a_file = ctx.actions.declare_file(archive_a_filename)
        paths_direct.append(archive_a_file.dirname)
        action_outputs.append(archive_a_file)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    args.add_all(_options)

    ## cmxa files will not work unless their submodules are in the
    ## same directory as the cmxa file. or so I inferred based on
    ## experiment. since transitions change the build output dirs, we
    ## address this by brute force for the moment: copy resolver and
    ## all submodules to cmxa directory.
    # new_resolvers = []
    # for resolver_file in ctx.files._ns_resolver:
    #     new_resolver_file = ctx.actions.declare_file(resolver_file.basename)
    #     print("RESOLVER FILE: {rf} => {newrf}".format(
    #         rf = resolver_file, newrf = new_resolver_file))
    #     ctx.actions.run_shell(
    #         inputs = [resolver_file],
    #         outputs = [new_resolver_file],
    #         command = "cp -v {src} {dst}".format(
    #             src = resolver_file.path, dst = new_resolver_file.path
    #         )
    #     )
    #     new_resolvers.append(new_resolver_file)
    #     # if resolver_file.extension not in ["cmi", "o"]:
    #     #     args.add(resolver_file)

    # new_deps = []
    # for dep_file in ctx.files.submodules:
    #         new_dep_file = ctx.actions.declare_file(dep_file.basename)
    #         print("CP DEP FILE: {df} => {newdf}".format(
    #             df = dep_file, newdf = new_dep_file))
    #         ctx.actions.run_shell(
    #             inputs = [dep_file],
    #             outputs = [new_dep_file],
    #             command = "cp -v {src} {dst}".format(
    #                 src = dep_file.path, dst = new_dep_file.path
    #             )
    #         )
    #         new_deps.append(new_dep_file)
    #         # if resolver_file.extension not in ["cmi", "o"]:
    #         #     args.add(resolver_file)
    #         new_depset = depset(new_deps)

    provider_output = []
    # for d in all_deps.to_list():
    # # for d in new_depset.to_list():
    #     # print("ALL_DEPS: %s" % d)
    #     # if d.extension == "o":
    #     #     provider_output.append(d)
    #     if d.extension not in ["cmxa", "cmi", "mli", "ml", "a", "o"]:
    #         # includes.append("-I", d.dirname)
    #         if d.basename != "Bare_functor_outputs.cmx":
    #             args.add(d.path) # d.basename)

    # inputs_depset = depset(
    #     order = dsorder,
    #     direct = ctx.files._ns_resolver,
    #     # direct = new_resolvers,
    #     transitive = [all_deps]
    #     # transitive = [new_depset]
    # )


    ## Option -a cannot be used with .cmxa input files.

    # submods = ctx.files.submodules
    # for dep in nslibMarker.depgraph.to_list():
    #     if dep in submods:
    #         if dep.extension in ["cmx", "cmxa"]:
    #             args.add(dep)
    #     ## direct submod deplist may not contain resolver
    #     elif dep.extension == "cmx":
    #         mod = normalize_module_name(dep.basename)
    #         if mod == archive_name:
    #             args.add(dep)
    #         elif mod == archive_name + "__0Resolver":
    #             args.add(dep)

    ## Submodules can be listed in ctx.files.submodules in any order,
    ## so we need to put them in correct order on the command line.
    ## Order is encoded in their depsets, which were merged by
    ## impl_ns_library; the result contains the files of
    ## ctx.files.submodules in the correct order.
    ## submod[DefaultInfo].files won't work, it contains only one
    ## module OcamlProvider. linkargs contains the deptree we need,
    ## but it may contain additional modules, so we need to filter. we
    ## also must take namespaces into account.
    submod_arglist = []
    subdeps_list = []
    for dep in ocamlProvider.linkargs.to_list():
        if debug:
            print("LINKARG %s" % dep)
        the_deps = ctx.attr.submodules if ctx.attr._rule.startswith("ocaml_ns") else ctx.attr.modules
        if dep in the_deps:
            if debug:
                print("LINKMATCH %s" % dep)
            submod_arglist.append(dep)
        else:
            print("LINKSKIP %s" % dep)
            subdeps_list.append(dep)
    if debug:
        print("LINKFILTERED %s" % submod_arglist)

    ordered_submodules_depset = depset(direct=submod_arglist)
    for dep in ordered_submodules_depset.to_list():
        if dep.extension == "cmx":
            args.add(dep)

    args.add("-a")

    args.add("-o", archive_file)

    # if ocamlProvider.ns_resolver != None:
    #     print("ARCH GOT NSRESOLVER FROM NSLIB: %s" % ocamlProvider.ns_resolver)
    #     args.add_all(ocamlProvider.ns_resolver)
    #     args.add("-DFOO")
    #     args.add_all(ctx.files._ns_resolver)


    if ctx.attr._rule == "ocaml_ns_archive":
        mnemonic = "CompileOcamlNsArchive"
    elif ctx.attr._rule == "ocaml_archive":
        mnemonic = "CompileOcamlArchive"
    else:
        fail("Unexpected rule type for impl_archive: %s" % ctx.attr._rule)

    ################
    # print("NSARCH {a} INPUTS_DEPSET: {ds}".format(
    #     a = ctx.label.name, ds = ocamlProvider.files))

    ################
    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = ocamlProvider.inputs,
        outputs = action_outputs,
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


