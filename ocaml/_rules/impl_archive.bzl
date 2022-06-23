load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlNsResolverProvider",

     "OcamlArchiveMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
)

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
)

load(":impl_library.bzl", "impl_library")

load("//ocaml/_functions:module_naming.bzl", "normalize_module_name")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "tmpdir", "dsorder")

#################
def impl_archive(ctx, mode, linkmode, tool, tool_args):

    debug = False # True
    # if ctx.label.name == "Bare_structs":
    #     debug = True #False

    # env = {"PATH": get_sdkpath(ctx)}

    # ns_resolver = ctx.files._ns_resolver if ctx.attr._rule.startswith("ocaml_ns") else []

    # if debug:
    #     for f in ns_resolver:
    #         print("_ns_resolver f: %s" % f.path)

    ################################
    ####  call impl_ns_library  ####
    # FIXME: improve the return vals handling
    # print("CALL IMPL_LIB %s" % ctx.label)
    lib_providers = impl_library(ctx, mode, tool, tool_args)

    libDefaultInfo = lib_providers[0]
    # print("libDefaultInfo: %s" % libDefaultInfo.files.to_list())

    libOcamlProvider = lib_providers[1]
    if debug:
        # print("libOcamlProvider.inputs type: %s" % type(libOcamlProvider.inputs))
        # print("libOcamlProvider.linkargs: %s" % libOcamlProvider.linkargs)
        print("libOcamlProvider.cdeps: %s" % libOcamlProvider.cdeps)
        print("libOcamlProvider.ldeps: %s" % libOcamlProvider.ldeps)
        # print("libOcamlProvider.paths type: %s" % type(libOcamlProvider.paths))
        # print("libOcamlProvider.ns_resolver: %s" % libOcamlProvider.ns_resolver)

    ppxAdjunctsProvider = lib_providers[2] ## FIXME: only as needed

    outputGroupInfo = lib_providers[3]

    _ = lib_providers[4] # OcamlLibraryMarker

    if ctx.attr._rule.startswith("ocaml_ns"):
        nsMarker = lib_providers[5]  # OcamlNsMarker
        ccInfo  = lib_providers[6] if len(lib_providers) == 7 else False
    else:
        ccInfo  = lib_providers[5] if len(lib_providers) == 6 else False

    # if ctx.label.name == "tezos-legacy-store":
    #     print("LEGACY CC: %s" % ccInfo)
        # dump_ccdep(ctx, dep)

    ################################
    if libOcamlProvider.ns_resolver == None:
        print("NO NSRESOLVER FROM NSLIB")
        fail("NO NSRESOLVER FROM NSLIB")
    else:
        ns_resolver = libOcamlProvider.ns_resolver
        if debug:
            print("ARCH GOT NSRESOLVER FROM NSLIB")
            for f in libOcamlProvider.ns_resolver: # .files.to_list():
                print("nsrsolver: %s" % f)

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

    if mode == "native":
        if shared:
            ext = ".cmxs"
        else:
            ext = ".cmxa"
    else:
        ext = ".cma"

    #### declare output files ####
    ## same for plain and ns archives
    if ctx.attr._rule.startswith("ocaml_ns"):
        if ctx.attr.ns:
            archive_name = ctx.attr.ns ## normalize_module_name(ctx.attr.ns)
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

    if mode == "native":
        archive_a_filename = tmpdir + archive_name + ".a"
        archive_a_file = ctx.actions.declare_file(archive_a_filename)
        paths_direct.append(archive_a_file.dirname)
        action_outputs.append(archive_a_file)

    #########################
    args = ctx.actions.args()

    args.add_all(tool_args)

    args.add_all(_options)

    ## Submodules can be listed in ctx.files.submodules in any order,
    ## so we need to put them in correct order on the command line.
    ## Order is encoded in their depsets, which were merged by
    ## impl_ns_library; the result contains the files of
    ## ctx.files.submodules in the correct order.
    ## submod[DefaultInfo].files won't work, it contains only one
    ## module OcamlProvider. linkargs contains the deptree we need,
    ## but it may contain additional modules, so we need to filter.

    submod_arglist = [] # direct deps

    ## ns_archives have submodules, plain archives have modules
    # direct_submodule_deps = ctx.files.submodules if ctx.attr._rule.startswith("ocaml_ns") else ctx.files.modules
    direct_submodule_deps = ctx.files.manifest

    if OcamlProvider in ns_resolver:
        ns_resolver_files = ns_resolver[OcamlProvider].inputs.to_list()
    else:
        ns_resolver_files = []
    # print("ns_resolver_files: %s" % ns_resolver_files)

    # print("direct_submodule_deps: %s" % direct_submodule_deps)

    # NB: ns lib linkargs not same as ns archive linkargs
    # the former contains resolver and submodules, which we add to the
    # cmd for building archive;
    # the latter excludes them (since they are in the archive)
    # NB also: ns_resolver only present if lib is ns
    # for dep in libOcamlProvider.linkargs.to_list():
    ## libDefaultInfo is the DefaultInfo provider of the underlying lib
    for dep in libDefaultInfo.files.to_list():
        # print("linkarg: %s" % dep)
        if dep in direct_submodule_deps: # add direct deps to cmd line...
            submod_arglist.append(dep)
        elif ctx.attr._rule.startswith("ocaml_ns"):
            if dep in ns_resolver_files:
                submod_arglist.append(dep)
            else: # should not happen!
                ## nslib linkargs should only contain what's needed to
                ## link and executable or build and archive.
                # linkargs_list.append(dep)
                fail("ns lib contains extra linkarg: %s" % dep)
        else:
            # linkargs should match direct deps list?
            fail("lib contains extra linkarg: %s" % dep)
            # submod_arglist.append(dep)

    ordered_submodules_depset = depset(direct=submod_arglist)

    # only direct deps go on cmd line:
    # if libOcamlProvider.ns_resolver != None:
    #     for ds in libOcamlProvider.ns_resolver:
    #         for f in ds.files.to_list():
    #             # print("ns_resolver: %s" % f)
    #             if f.extension == "cmx":
    #                 args.add(f)

    # for dep in ordered_submodules_depset.to_list():
    for dep in libOcamlProvider.inputs.to_list():
        # print("inputs dep: %s" % dep)
        # print("ns_resolver: %s" % ns_resolver)
        if dep in submod_arglist:
            # print("adding to args: %s" % dep)
            args.add(dep)
        elif dep == ns_resolver:
            args.add(dep)

    linkargs_list = []
    # lbl_name = "tezos-lwt-result-stdlib.bare.structs"
    # if ctx.label.name == lbl_name:
    #     print("ns_name: %s" % nsMarker.ns_name)
    for dep in libOcamlProvider.linkargs.to_list():
        #FIXME: dep is not namespaced so we won't match ever:
        # if ctx.label.name == lbl_name:
        #     print("RULE: %s" % ctx.attr._rule)
        #     print("TESTING: %s" % dep.basename)
        if ctx.attr._rule.startswith("ocaml_ns"):
            # if ctx.label.name == lbl_name:
                # print("NS PFX: %s" % nsMarker.ns_name + "__")
                # print("TEST1: %s" % dep.basename.startswith(nsMarker.ns_name + "__"))
                # print("TEST2: %s" % (dep.basename != nsMarker.ns_name + ".cmxa"))
            if dep.basename.startswith(nsMarker.ns_name):
                if (dep.basename != nsMarker.ns_name + ".cmxa") and (dep.basename != nsMarker.ns_name + ".cma"):
                    if not dep.basename.startswith(nsMarker.ns_name + "__"):
                        # if ctx.label.name == lbl_name:
                        #     print("xxxx")
                        linkargs_list.append(dep)
                    # else:
                    #     if ctx.label.name == lbl_name:
                    #         print("OMIT1 %s" % dep)
                # else:
                #     if ctx.label.name == lbl_name:
                #         print("OMIT RESOLVER: %s" % dep)
            else:
                # if ctx.label.name == lbl_name:
                #     print("APPEND: %s" % dep)
                linkargs_list.append(dep)
        else:
            if not dep in direct_submodule_deps:
                linkargs_list.append(dep)

    # for dep in submod_arglist:
    #     # if dep.extension in ["cmx"]:
    #     args.add(dep)

    args.add("-a")

    args.add("-o", archive_file)

    if ctx.attr._rule == "ocaml_ns_archive":
        mnemonic = "CompileOcamlNsArchive"
    elif ctx.attr._rule == "ocaml_archive":
        mnemonic = "CompileOcamlArchive"
    else:
        fail("Unexpected rule type for impl_archive: %s" % ctx.attr._rule)

    ################
    ctx.actions.run(
        # env = env,
        executable = tool,
        arguments = [args],
        inputs = libOcamlProvider.inputs,
        outputs = action_outputs,
        tools = [tool] + tool_args, # [tc.ocamlopt, tc.ocamlc],
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
    default_depset = depset(
        order  = dsorder,
        direct = [archive_file] # .cmxa
    )
    newDefaultInfo = DefaultInfo(files = default_depset)

    new_inputs_depset = depset(
        direct     = action_outputs, # + ns_resolver,
        transitive = [libOcamlProvider.inputs]
    )

    # linkargs_depsets = depset(
    #     ## indirect deps (excluding direct deps, i.e. submodules & resolver)
    #     # direct = linkargs_list,
    #     transitive = [libOcamlProvider.linkargs]
    # )

    linkargs_depset = depset(
        direct     = linkargs_list
        # transitive = [libOcamlProvider.linkargs]
        # transitive = [linkargs_depsets]
    )
    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = [libOcamlProvider.paths]
    )

    ocamlProvider = OcamlProvider(
        files   = libOcamlProvider.files,
        fileset = libOcamlProvider.fileset,
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        cdeps    = libOcamlProvider.cdeps,
        ldeps    = libOcamlProvider.ldeps,
        paths    = paths_depset,
    )

    providers = [
        newDefaultInfo,
        ocamlProvider,
        OcamlArchiveMarker(marker = "OcamlArchive"),
    ]

    # FIXME: only if needed
    # if has ppx codeps:
    providers.append(ppxAdjunctsProvider)
    ppx_codeps_depset = ppxAdjunctsProvider.ppx_codeps

    outputGroupInfo = OutputGroupInfo(
        # resolver = ns_resolver,
        ppx_codeps = ppx_codeps_depset,
        linkargs = linkargs_depset,
        cdeps    = libOcamlProvider.cdeps,
        ldeps    = libOcamlProvider.ldeps,
        all = depset(transitive=[
            new_inputs_depset,
            ppx_codeps_depset,
            # cclib_files_depset,
        ])
    )
    providers.append(outputGroupInfo)

    if ccInfo:
        providers.append(ccInfo)

    # we may be called by ocaml_ns_archive, so:
    if ctx.attr._rule.startswith("ocaml_ns"):
        providers.append(OcamlNsMarker(
            marker = "OcamlNsMarker",
            ns_name     = nsMarker.ns_name
        ))

    return providers


