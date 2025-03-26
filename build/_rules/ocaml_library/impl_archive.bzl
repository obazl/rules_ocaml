load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@rules_ocaml//build:providers.bzl",
     "OCamlCodepsProvider",
     "OCamlNsResolverProvider",
     "OCamlDepsProvider",
     "OCamlArchiveProvider",
     "OCamlLibraryProvider",
     "OCamlModuleProvider",
     "OcamlNsMarker",
     "OpamInstallProvider"
)
load("@rules_ocaml//build/_lib:ccdeps.bzl", "extract_cclibs", "dump_CcInfo")

load(":impl_library.bzl", "impl_library")

load("//build/_lib:module_naming.bzl", "normalize_module_name")

load("//build/_lib:options.bzl", "get_options")
load("//build/_lib:utils.bzl", "dsorder", "tmpdir")

load("@rules_ocaml//lib:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCBLUBG",
     "CCMAG", "CCMAGBG",
     "CCCYN", "CCCYNBG",
     "CCYEL", "CCUYEL", "CCYELBG", "CCYELBGH",
     "CCRESET",
     )

CCBLUCYN="\033[44m\033[36m"

######################
def impl_archive(ctx, _linkage):

    debug     = False
    debug_lib = False
    debug_cc  = False

    if debug:
        print("{c}impl_archive: {a}{r}".format(
            c=CCBLUCYN,a=ctx.label,r=CCRESET))


    # if ctx.label.name == "Bare_structs":
    #     debug = True #False

    # env = {"PATH": get_sdkpath(ctx)}

    ##FIXME: explicit ctx.attr.resolver?
    ns_resolver = ctx.files._ns_resolver if ctx.attr._rule.startswith("ocaml_ns") else []

    if debug:
        print("ns resolver: %s" % ns_resolver)
        for f in ns_resolver:
            print("_ns_resolver f: %s" % f.path)
        # if ns_resolver:
        #     print("XXXXXXXXXXXXXXXX")
            # if ctx.label.name == "libColor":
            #     fail()
    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]

    # sigs_direct   = []
    # sigs_indirect = []
    # structs_primary   = []
    # structs_secondary = []
    # astructs_primary   = []
    # astructs_secondary = []

    # ofiles_direct   = [] # never? ofiles only come from deps
    # ofiles_indirect = []
    # afiles_direct   = []
    # afiles_indirect = []
    # archives_direct = []
    # archives_secondary = []

    ################################
    ####  call impl_library  ####
    # FIXME: improve the return vals handling
    # print("CALL IMPL_LIB %s" % ctx.label)
    lib_providers = impl_library(ctx, True) #, tc.target, tool, tool_args)

    # if _linkage == None:
    #     return lib_providers

    ## NB: lib_providers cannot be indexed by provider name, its just an array
    libDefaultInfo = lib_providers[0]
    if debug_lib:
        print("libDefaultInfo: %s" % libDefaultInfo.files.to_list())

    libOCamlDepsProvider = lib_providers[1]
    if debug_lib:
        print("libOCamlDepsProvider: %s" % type(libOCamlDepsProvider))
    # fail("x")

    outputGroupInfo = lib_providers[2]
    if debug_lib:
        print("lib outputGroupInfo: %s" % outputGroupInfo)

    libOCamlLibProvider = lib_providers[3] # OCamlLibraryProvider

    ppxCodepsProvider = lib_providers[4] ## may be empty
    if debug_lib:
        print("lib ppxCodepsProvider: %s" % ppxCodepsProvider)

    lib_CcInfo  = lib_providers[5] # may be empty
    if debug_lib:
        print("lib lib_CcInfo")
        print("%s" % dump_CcInfo(ctx, lib_CcInfo))

    if ctx.attr._rule.startswith("ocaml_ns"):
        nsMarker = lib_providers[6]  # OcamlNsMarker

    # if ctx.label.name == "tezos-legacy-store":
    #     print("LEGACY CC: %s" % lib_CcInfo)
        # dump_ccdep(ctx, dep)

    ################################
    # if libOCamlDepsProvider.ns_resolver == None:
    #     print("NO NSRESOLVER FROM NSLIB")
    #     fail("NO NSRESOLVER FROM NSLIB")
    # else:
    #     ns_resolver = libOCamlDepsProvider.ns_resolver
    #     if debug:
    #         print("ARCH GOT NSRESOLVER FROM NSLIB")
    #         for f in libOCamlDepsProvider.ns_resolver: # .files.to_list():
    #             print("nsrsolver: %s" % f)

    paths_direct = []
    paths_indirect = libOCamlDepsProvider.paths

    action_outputs = []

    _options = get_options(ctx.attr._rule, ctx)

    # shared = False
    # if ctx.attr.shared:
    #     shared = ctx.attr.shared or "-shared" in _options
    #     if shared:
    #         if "-shared" in _options:
    #             _options.remove("-shared") ## avoid dup

    ext = None
    if tc.target == "vm":
        ext = ".cma"
    else:
        ## FIXME: handle ["-shared"] in opts attr
        if _linkage == "static":
            ext = ".cmxa"
        elif _linkage == "shared":
            ext = ".cmxs"
        # else: # do not archive
        #     ext = None

    #### declare output files ####
    ## same for plain and ns archives
    if ctx.attr._rule.startswith("ocaml_ns"):
        if ctx.attr.ns_name:
            archive_name = ctx.attr.ns_name ## normalize_module_name(ctx.attr.ns_name)
        elif ctx.attr.archive_name:
            archive_name = ctx.attr.archive_name
        else:
            archive_name = ctx.label.name ## normalize_module_name(ctx.label.name)
    else:
        archive_name = ctx.label.name ## normalize_module_name(ctx.label.name)

    if debug:
        print("archive_name: %s" % archive_name)

    archive_filename = tmpdir + archive_name + ext
    archive_file = ctx.actions.declare_file(archive_filename)
    paths_direct.append(archive_file.dirname)
    action_outputs.append(archive_file)

    archive_a_file = None
    if ((tc.target == "sys")
        and _linkage == "static"):
        archive_a_filename = tmpdir + archive_name + ".a"
        archive_a_file = ctx.actions.declare_file(archive_a_filename)
        paths_direct.append(archive_a_file.dirname)
        action_outputs.append(archive_a_file)

    #########################
    args = ctx.actions.args()

    if _linkage == "static":
      args.add("-a")
    elif _linkage == "shared":
      args.add("-shared")
    # elif  _linkage == None:
    #   args.add("-a")
    elif  _linkage != None:
        ## should not be possible
        fail("Unrecognized linkage spec: %s" % _linkage)

    args.add_all(_options)

    ## Submodules can be listed in ctx.files.manifest in any order,
    ## so we need to put them in correct order on the command line.
    ## Order is encoded in their depsets, which were merged by
    ## impl_library; the result contains the files of
    ## ctx.files.manifest in the correct order.
    ## submod[DefaultInfo].files won't work, it contains OcamlProvider
    ## for only one module, so order would be lost. The aggregate
    ## fiels of libOCamlDepsProvider have the ordering info, but we need
    ## to filter out the direct submodules.

    submod_arglist = [] # direct deps

    ## ns_archives have submodules, plain archives have modules
    # direct_submodule_deps = ctx.files.manifest if ctx.attr._rule.startswith("ocaml_ns") else ctx.files.manifest

    # if OcamlProvider in ns_resolver:
    #     ns_resolver_files = ns_resolver[OcamlProvider].inputs.to_list()
    # else:
    #     ns_resolver_files = []

    # print("ns_resolver_files: %s" % ns_resolver_files)

    # print("direct_submodule_deps: %s" % direct_submodule_deps)

    # NB: ns lib linkargs not same as ns archive linkargs
    # the former contains resolver and submodules, which we add to the
    # cmd for building archive;
    # the latter excludes them (since they are in the archive)
    # NB also: ns_resolver only present if lib is ns
    # for dep in libOCamlDepsProvider.linkargs.to_list():
    ## libDefaultInfo is the DefaultInfo provider of the underlying lib

    for f in ns_resolver: # [0][DefaultInfo].files:
        submod_arglist.append(f)

    # these will be archives for libs:
    direct_submodule_deps = ctx.files.manifest
    # print("direct_submodule_deps: %s" % direct_submodule_deps)

    libdeps = depset(transitive = [libOCamlLibProvider.manifest])
    for dep in libdeps.to_list():
        # print("LIB ITEM %s" % dep)
        submod_arglist.append(dep)

    # for any archive file in manifest, we need to obtain
    # the corresponding library, provided in OCamlLibraryProvider?

    # for dep in libDefaultInfo.files.to_list():
    #     ## this logic won’t work for lib deps:
    #     # if dep in direct_submodule_deps: # = manifest
    #         submod_arglist.append(dep)
    #     ## so, workaround:
    #     else:
    #         submod_arglist.append(dep)

    if debug_cc:
        dump_CcInfo(ctx, lib_CcInfo)

    [static_cc_deps, dynamic_cc_deps] = extract_cclibs(ctx, lib_CcInfo)
    if debug_cc:
        print("static_cc_deps:  %s" % static_cc_deps)
        print("dynamic_cc_deps: %s" % dynamic_cc_deps)

    for dep in static_cc_deps:
        if debug_cc: print("STATIC DEP: %s" % dep)
        # args.add(dep.path)
        # args.add(dep)

        args.add("-ccopt", "-L" + dep.dirname)
        args.add("-cclib", "-l" + dep.basename[3:-2])

        # includes.append(dep.dirname)
        # sincludes.append("-L" + dep.dirname)
    for dep in dynamic_cc_deps:
        if debug_cc: print("DYNAMIC DEP: %s" % dep)
        # args.add(dep.path)

        # -dllpath and -dllib is for ocamlc only
        # args.add("-dllpath", dep.dirname)

        if dep.basename.startswith("dll"):
            if tc.target == "vm":
                args.add("-dllib", "-l" + dep.basename[3:-3])

    ordered_submodules_depset = depset(direct=submod_arglist)

    archive_link_deps = [] # excluding direct (manifest) deps
    # print("submod list %s" % submod_arglist)
    for dep in libOCamlDepsProvider.cli_link_deps.to_list():
        # print("maybe dep %s" % dep)
        if dep in submod_arglist:
            if debug: print("adding link dep to args: %s" % dep)
            # args.add(dep)
        else:
            # args.add(dep)
            archive_link_deps.append(dep)

    args.add_all(submod_arglist)

    ##FIXME: cc deps same as for ocaml_binary, all indirect cc_deps in
    ## manifest should be added to cmd line of archive, plus direct cc
    ## deps in cc_deps attr.

    ##FIXME: what if deps include resolvers?
    # if ns_resolver:
    #     args.add_all(ns_resolver)

    args.add("-o", archive_file)

    action_inputs_depset = depset(
        direct =
        static_cc_deps + dynamic_cc_deps
        ,
        transitive =
        [libOCamlDepsProvider.sigs,
         libOCamlDepsProvider.structs,
         libOCamlDepsProvider.ofiles,
         libOCamlDepsProvider.archives,
         libOCamlDepsProvider.astructs,
         libOCamlDepsProvider.afiles]
    )

    if ctx.attr._rule == "ocaml_ns_archive":
        mnemonic = "ArchiveOCamlNsLibrary"
    elif ctx.attr._rule == "ocaml_archive":
        mnemonic = "ArchiveOCamlArchive"
    elif ctx.attr._rule == "ocaml_ns_library":
        mnemonic = "ArchiveOCamlNsLibrary"
    elif ctx.attr._rule == "ocaml_library":
        mnemonic = "ArchiveOCamlLibrary"
    else:
        fail("Unexpected rule type for impl_archive: %s" % ctx.attr._rule)

    ################
    ctx.actions.run(
        # env = env,
        executable = tc.compiler,
        arguments = [args],
        inputs = action_inputs_depset,
        outputs = action_outputs,
        tools = [tc.compiler],
        mnemonic = mnemonic,
        progress_message = "{mode} compiling {rule}: @{ws}//{pkg}:{tgt}".format(
            mode = tc.host + ">" + tc.target,
            rule = ctx.attr._rule,
            ws  = ctx.label.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )

    ###################
    #### PROVIDERS ####
    ###################
    default_depset = depset(
        order  = dsorder,
        direct = [archive_file] # .cmxa, .cma, .cmxs
    )
    newDefaultInfo = DefaultInfo(files = default_depset)

    archive_depset = depset(direct = [archive_file])
    ocamlArchiveProvider = OCamlArchiveProvider(
        archive = archive_file
    )

    # new_inputs_depset = depset(
    #     direct     = action_outputs, # + ns_resolver,
    #     transitive = [libOCamlDepsProvider.inputs]
    # )

    # linkargs_depsets = depset(
    #     ## indirect deps (excluding direct deps, i.e. submodules & resolver)
    #     # direct = linkargs_list,
    #     transitive = [libOCamlDepsProvider.linkargs]
    # )

    # linkargs_depset = depset(
    #     direct     = linkargs_list
    #     # transitive = [libOCamlDepsProvider.linkargs]
    #     # transitive = [linkargs_depsets]
    # )
    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = [libOCamlDepsProvider.paths]
    )

    sigs_depset = depset(order=dsorder,
                         transitive = [libOCamlDepsProvider.sigs])
                          # direct=sigs_direct,
                          # transitive=sigs_indirect),

    structs_depset = depset(order=dsorder,
                            # direct=structs_primary,
                            transitive = [libOCamlDepsProvider.structs])

    astructs_depset = depset(order=dsorder,
                             # direct=astructs_primary,
                             transitive =[libOCamlDepsProvider.astructs])
    # transitive = [libOCamlDepsProvider.structs]),
    # transitive=structs_indirect),

    ## FIXME: move direct submodules from libOCamlDepsProvider.structs to
    ## astructs
    ## FIXME: just deliver libOCamlDepsProvider directly?

    # if not hasattr(libOCamlDepsProvider, "cli_link_deps"):

    ofiles_depset = depset(order=dsorder,
                           transitive = [libOCamlDepsProvider.ofiles])
    # direct=ofiles_direct,
    # transitive=ofiles_indirect),

    archives_depset = depset(order=dsorder,
                             direct = [archive_file],
                             transitive = [libOCamlDepsProvider.archives])
    # direct=archives_direct,
    # transitive=archives_indirect),

    afiles_depset   = depset(order=dsorder,
                             direct = [archive_a_file] if archive_a_file else [],
                             transitive = [libOCamlDepsProvider.afiles])
    # direct=afiles_direct,
    # transitive=afiles_indirect),

    srcs_depset  = depset(order = dsorder,
                          transitive = [libOCamlDepsProvider.srcs])

    if _linkage == "shared":
        cmxs_depset  = depset(order = dsorder,
                              direct = [archive_file],
                              transitive = [libOCamlDepsProvider.cmxs])
    else:
        cmxs_depset  = depset(order = dsorder,
                              transitive = [libOCamlDepsProvider.cmxs])


    cmts_depset  = depset(order = dsorder,
                          transitive = [libOCamlDepsProvider.cmts])

    cmtis_depset  = depset(order = dsorder,
                           transitive = [libOCamlDepsProvider.cmtis])

    cli_link_depset = depset(
        order=dsorder,
        # direct = submod_arglist,
        # transitive = [depset(archive_link_deps)]
        # transitive = [depset(archive_link_deps)]
        transitive = [libOCamlDepsProvider.cli_link_deps]
    )

    link_archives_depset = depset(
        order=dsorder,
        direct = [archive_file],
        transitive = [libOCamlDepsProvider.link_archives_deps]
        # transitive = [depset(archive_link_deps)]
    )

    ocamlDepsProvider = OCamlDepsProvider(
        # files   = libOCamlDepsProvider.files,
        # fileset = libOCamlDepsProvider.fileset,
        # inputs   = new_inputs_depset,
        # linkargs = linkargs_depset,
        # cdeps    = libOCamlDepsProvider.cdeps,
        # ldeps    = libOCamlDepsProvider.ldeps,

        cli_link_deps = cli_link_depset,
        link_archives_deps = link_archives_depset,

        sigs   = sigs_depset,
        structs = structs_depset,
        astructs = astructs_depset,
        # astructs   = depset(order=dsorder,
        #                    direct=astructs_primary),
                           # transitive = [libOCamlDepsProvider.astructs]),
                           # transitive=astructs_indirect),
        ofiles   = ofiles_depset,
        archives = archives_depset,
        afiles   = afiles_depset,
        cmxs     = cmxs_depset,
        cmts     = cmts_depset,
        cmtis    = cmtis_depset,
        srcs     = srcs_depset,
        paths    = libOCamlDepsProvider.paths
    )

    installProvider = OpamInstallProvider(
        archives = default_depset,
        structs = ordered_submodules_depset
    )

    providers = [
        newDefaultInfo,
        ocamlArchiveProvider,
        ocamlDepsProvider,
        installProvider,
        libOCamlLibProvider,
    ]

    # FIXME: only if needed
    # if has ppx codeps:
    providers.append(ppxCodepsProvider)
    # ppx_codeps_depset = ppxCodepsProvider.ppx_codeps

    if lib_CcInfo:
        providers.append(lib_CcInfo)

    # we may be called by ocaml_ns_archive, so:
    if ctx.attr._rule.startswith("ocaml_ns"):
        providers.append(OcamlNsMarker(
            # marker = "OcamlNsMarker",
            # ns_name     = nsMarker.ns_name
        ))

    outputGroupInfo = OutputGroupInfo(
        archive  = archive_depset,
        archives = archives_depset,
        afiles   = afiles_depset,
        cli_link = cli_link_depset,
        link_archives = link_archives_depset,
        sigs    = sigs_depset,
        structs = structs_depset,
        ofiles   = ofiles_depset,
        astructs = astructs_depset,

        # resolver = ns_resolver,
        # ppx_codeps = ppx_codeps_depset,
        # linkargs = linkargs_depset,
        # cdeps    = libOCamlDepsProvider.cdeps,
        # ldeps    = libOCamlDepsProvider.ldeps,
        all = depset(transitive=[
            archives_depset,
            astructs_depset,
            afiles_depset,
            sigs_depset,
            structs_depset,
            ofiles_depset,
            cli_link_depset,
            # new_inputs_depset,
            # ppx_codeps_depset,
            # cclib_files_depset,
        ])
    )
    providers.append(outputGroupInfo)

    # print(providers)
    return providers
