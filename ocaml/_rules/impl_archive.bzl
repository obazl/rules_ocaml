load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@rules_ocaml//providers:moduleinfo.bzl", "OCamlModuleInfo")

load("@rules_ocaml//ocaml:ocamlinfo.bzl", "OCamlInfo")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlNsResolverProvider",

     "OcamlArchiveMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
)

load("//ppx:providers.bzl",
     "PpxCodepsInfo",
)

load(":impl_ccdeps.bzl", "extract_cclibs", "dump_CcInfo")

load(":impl_library.bzl", "impl_library")

load("//ocaml/_functions:module_naming.bzl", "normalize_module_name")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "tmpdir", "dsorder")

load("@rules_ocaml//ocaml/_debug:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCBLUBG",
     "CCMAG", "CCMAGBG",
     "CCCYN", "CCCYNBG",
     "CCYEL", "CCUYEL", "CCYELBG", "CCYELBGH",
     "CCRESET",
     )

CCBLUCYN="\033[44m\033[36m"

######################
def impl_archive(ctx):

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
        if ns_resolver:
            print("XXXXXXXXXXXXXXXX")
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

    ## NB: lib_providers cannot be indexed by provider name, its just an array
    libDefaultInfo = lib_providers[0]
    if debug_lib:
        print("libDefaultInfo: %s" % libDefaultInfo.files.to_list())

    libOcamlProvider = lib_providers[1]
    if debug_lib:
        print("libOcamlProvider: %s" % type(libOcamlProvider))
    # fail("x")

    outputGroupInfo = lib_providers[2]
    if debug_lib:
        print("lib outputGroupInfo: %s" % outputGroupInfo)

    _ = lib_providers[3] # OcamlLibraryMarker

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
    # if libOcamlProvider.ns_resolver == None:
    #     print("NO NSRESOLVER FROM NSLIB")
    #     fail("NO NSRESOLVER FROM NSLIB")
    # else:
    #     ns_resolver = libOcamlProvider.ns_resolver
    #     if debug:
    #         print("ARCH GOT NSRESOLVER FROM NSLIB")
    #         for f in libOcamlProvider.ns_resolver: # .files.to_list():
    #             print("nsrsolver: %s" % f)

    paths_direct = []
    paths_indirect = libOcamlProvider.paths

    action_outputs = []

    _options = get_options(ctx.attr._rule, ctx)

    shared = False
    if ctx.attr.shared:
        shared = ctx.attr.shared or "-shared" in _options
        if shared:
            if "-shared" in _options:
                _options.remove("-shared") ## avoid dup

    if tc.target == "vm":
        ext = ".cma"
    else:
        if shared:
            ext = ".cmxs"
        else:
            ext = ".cmxa"

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

    if tc.target == "vm":
        archive_a_file = None
    else:
        archive_a_filename = tmpdir + archive_name + ".a"
        archive_a_file = ctx.actions.declare_file(archive_a_filename)
        paths_direct.append(archive_a_file.dirname)
        action_outputs.append(archive_a_file)

    #########################
    args = ctx.actions.args()

    args.add("-a")

    args.add_all(_options)

    ## Submodules can be listed in ctx.files.manifest in any order,
    ## so we need to put them in correct order on the command line.
    ## Order is encoded in their depsets, which were merged by
    ## impl_library; the result contains the files of
    ## ctx.files.manifest in the correct order.
    ## submod[DefaultInfo].files won't work, it contains OcamlProvider
    ## for only one module, so order would be lost. The aggregate
    ## fiels of libOcamlProvider have the ordering info, but we need
    ## to filter out the direct submodules.

    submod_arglist = [] # direct deps

    ## ns_archives have submodules, plain archives have modules
    # direct_submodule_deps = ctx.files.manifest if ctx.attr._rule.startswith("ocaml_ns") else ctx.files.manifest
    direct_submodule_deps = ctx.files.manifest
    # for dep in ctx.attr.manifest:
    #     if OCamlModuleInfo in dep:
    #         print("DIRDEP %s" % dep[OCamlModuleInfo])
        # print("ODEP %s" % dep[OCamlInfo])
        # print("ODEP %s" % dep[OcamlProvider])

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
    # for dep in libOcamlProvider.linkargs.to_list():
    ## libDefaultInfo is the DefaultInfo provider of the underlying lib

    for f in ns_resolver: # [0][DefaultInfo].files:
        submod_arglist.append(f)

    for dep in libDefaultInfo.files.to_list():
        if dep in direct_submodule_deps: # = manifest
            submod_arglist.append(dep)

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
        # args.add("-ccopt", "-L" + dep.dirname)
        args.add("-cclib", "-l" + dep.basename[3:-2])
        # includes.append(dep.dirname)
        # sincludes.append("-L" + dep.dirname)
    for dep in dynamic_cc_deps:
        print("DYNAMIC DEP: %s" % dep)
        # args.add(dep.path)
        args.add("-dllpath", dep.dirname)
        if dep.basename.startswith("dll"):
            args.add("-dllib", "-l" + dep.basename[3:-3])
        else:
            args.add("-ccopt", "-l" + dep.basename[:-3])

    # if ctx.label.name == "jsoo_runtime":
    #     fail("r")

    ordered_submodules_depset = depset(direct=submod_arglist)

    # only direct deps go on cmd line:
    # if libOcamlProvider.ns_resolver != None:
    #     for ds in libOcamlProvider.ns_resolver:
    #         for f in ds.files.to_list():
    #             # print("ns_resolver: %s" % f)
    #             if f.extension == "cmx":
    #                 args.add(f)

    # for dep in libOcamlProvider.archives.to_list():
    #     # print("inputs dep: %s" % dep)
    #     # print("ns_resolver: %s" % ns_resolver)
    #     if dep in submod_arglist:
    #         # print("adding to args: %s" % dep)
    #         args.add(dep)

    ## structs: free-standing struct deps (not archived)
    # for dep in libOcamlProvider.structs.to_list():
    #     # print("inputs dep: %s" % dep)
    #     # print("ns_resolver: %s" % ns_resolver)
    #     if dep in submod_arglist:
    #         print("adding struct to args: %s" % dep)
    #         args.add(dep)

            # astructs_primary.append(dep)
        # else:
        #     # ensure this dep will go on link cmd line
        #     # astructs_secondary.append(dep)
        #     structs_primary.append(dep)
        # elif dep == ns_resolver:
        #     args.add(dep)

    ## this won't work because astructs contains entire depgraph, not
    ## just the files in ctx.attr.manifest:
    # for dep in libOcamlProvider.astructs.to_list():
    #     args.add(dep)

    ## this won't work because it does not respect dep ordering:
    # for dep in ctx.files.manifest:
    #     args.add(dep)

    ## astructs are in dep order, but includes entire depgraph, so we
    ## filter against manifest list:
    # for dep in  libOcamlProvider.astructs.to_list():
    archive_link_deps = [] # excluding direct (manifest) deps
    for dep in libOcamlProvider.cli_link_deps.to_list():
        if dep in submod_arglist:
            if debug:
                print("adding link dep to args: %s" % dep)
            args.add(dep)
        else:
            archive_link_deps.append(dep)

    # for dep in libOcamlProvider.cli_link_deps.to_list():
    #     args.add(dep)

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
        [libOcamlProvider.sigs,
         libOcamlProvider.structs,
         libOcamlProvider.ofiles,
         libOcamlProvider.archives,
         libOcamlProvider.astructs,
         libOcamlProvider.afiles]
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
        direct = [archive_file] # .cmxa
    )
    newDefaultInfo = DefaultInfo(files = default_depset)

    # new_inputs_depset = depset(
    #     direct     = action_outputs, # + ns_resolver,
    #     transitive = [libOcamlProvider.inputs]
    # )

    # linkargs_depsets = depset(
    #     ## indirect deps (excluding direct deps, i.e. submodules & resolver)
    #     # direct = linkargs_list,
    #     transitive = [libOcamlProvider.linkargs]
    # )

    # linkargs_depset = depset(
    #     direct     = linkargs_list
    #     # transitive = [libOcamlProvider.linkargs]
    #     # transitive = [linkargs_depsets]
    # )
    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = [libOcamlProvider.paths]
    )

    structs_depset = depset(order=dsorder,
                            # direct=structs_primary,
                            transitive = [libOcamlProvider.structs])

    # if ctx.label.name == "ppx_sexp_conv_expander":
    #     print("astructs: %s" % libOcamlProvider.astructs)
    #     fail()

    astructs_depset = depset(order=dsorder,
                             # direct=astructs_primary,
                             transitive =[libOcamlProvider.astructs])
    # transitive = [libOcamlProvider.structs]),
    # transitive=structs_indirect),

    ## FIXME: move direct submodules from libOcamlProvider.structs to
    ## astructs
    ## FIXME: just deliver libOcamlProvider directly?

    # if not hasattr(libOcamlProvider, "cli_link_deps"):

    cli_link_depset = depset(
        order=dsorder,
        direct = [archive_file],
        transitive = [depset(archive_link_deps)]
        # transitive = [libOcamlProvider.cli_link_deps]
    )

    ocamlProvider = OcamlProvider(
        # files   = libOcamlProvider.files,
        # fileset = libOcamlProvider.fileset,
        # inputs   = new_inputs_depset,
        # linkargs = linkargs_depset,
        # cdeps    = libOcamlProvider.cdeps,
        # ldeps    = libOcamlProvider.ldeps,

        cli_link_deps = cli_link_depset,

        sigs   = depset(order=dsorder,
                        transitive = [libOcamlProvider.sigs]),
                          # direct=sigs_direct,
                          # transitive=sigs_indirect),
        structs = structs_depset,
        astructs = astructs_depset,
        # astructs   = depset(order=dsorder,
        #                    direct=astructs_primary),
                           # transitive = [libOcamlProvider.astructs]),
                           # transitive=astructs_indirect),
        ofiles   = depset(order=dsorder,
                           transitive = [libOcamlProvider.ofiles]),
                          # direct=ofiles_direct,
                          # transitive=ofiles_indirect),
        archives   = depset(order=dsorder,
                            direct = [archive_file],
                            transitive = [libOcamlProvider.archives]),
                          # direct=archives_direct,
                          # transitive=archives_indirect),
        afiles   = depset(order=dsorder,
                          direct = [archive_a_file] if archive_a_file else [],
                           transitive = [libOcamlProvider.afiles]),
                           # direct=afiles_direct,
                           # transitive=afiles_indirect),

        paths    = libOcamlProvider.paths
    )

    providers = [
        newDefaultInfo,
        ocamlProvider,
        OcamlLibraryMarker(),
        OcamlArchiveMarker(marker = "OcamlArchive"),
    ]

    # FIXME: only if needed
    # if has ppx codeps:
    providers.append(ppxCodepsProvider)
    # ppx_codeps_depset = ppxCodepsProvider.ppx_codeps

    outputGroupInfo = OutputGroupInfo(
        structs = structs_depset,
        astructs = astructs_depset,
        # resolver = ns_resolver,
        # ppx_codeps = ppx_codeps_depset,
        # linkargs = linkargs_depset,
        # cdeps    = libOcamlProvider.cdeps,
        # ldeps    = libOcamlProvider.ldeps,
        all = depset(transitive=[
            # new_inputs_depset,
            # ppx_codeps_depset,
            # cclib_files_depset,
        ])
    )
    providers.append(outputGroupInfo)

    if lib_CcInfo:
        providers.append(lib_CcInfo)

    # we may be called by ocaml_ns_archive, so:
    if ctx.attr._rule.startswith("ocaml_ns"):
        providers.append(OcamlNsMarker(
            # marker = "OcamlNsMarker",
            # ns_name     = nsMarker.ns_name
        ))

    return providers
