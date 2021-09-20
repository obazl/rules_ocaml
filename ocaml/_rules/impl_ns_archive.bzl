load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlProvider",

     "AdjunctDepsMarker",
     "CompilationModeSettingProvider",
     "OcamlArchiveMarker",
     "OcamlModuleMarker",
     "OcamlNsArchiveMarker",
     "PpxNsArchiveMarker")

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

    debug = True #False
    # if ctx.label.name in ["jemalloc"]: # ["mina_metrics", "memory_stats"]:
    #     debug = True

    debug = True #False

    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ################################
    ####  call impl_ns_library  ####
    [
        defaultInfo,
        nslibMarker,
        ocamlProvider,
        adjunctsMarker,
        ccMarker,
        outputGroupInfo,
    ] = impl_ns_library(ctx)
    ################################

    all_deps = ocamlProvider.files
    paths_direct = []
    paths_indirect = ocamlProvider.paths

    ## now archive the nslib

    ns_archive_name = normalize_module_name(ctx.label.name)
    ns_ext = ".cmxa" if mode == "native" else ".cma"
    ns_archive_filename = tmpdir + ns_archive_name + ns_ext
    ns_archive_file = ctx.actions.declare_file(ns_archive_filename)
    paths_direct.append(ns_archive_file.dirname)

    ns_archive_a_filename = tmpdir + ns_archive_name + ".a"
    ns_archive_a_file = ctx.actions.declare_file(ns_archive_a_filename)
    paths_direct.append(ns_archive_a_file.dirname)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    options = get_options(ctx.attr._rule, ctx)
    args.add_all(options)


    for d in all_deps.to_list():
        # print("ALL_DEPS: %s" % d)
        if d.extension not in ["cmxa", "cmi", "mli", "a", "o"]:
            # includes.append("-I", d.dirname)
            args.add(d.path) # d.basename)

    # _paths = depset(transitive=paths_indirect).to_list()
    # args.add_all(_paths, before_each="-I") #, uniquify = True)

    # print("ALL_DEPS for MODULE %s" % ctx.label)
    # # for d in reversed(all_deps.to_list()):
    # for d in all_deps.to_list():
    #     # print("ALL_DEPS: %s" % d)
    #     # "Option -a cannot be used with .cmxa input files."
    #     if d.extension not in ["cmxa", "cma", "cmi", "mli", "a", "o"]:
    #         args.add(d.path)

    # ## use depgraph to ensure correct ordering, filter to include only direct deps
    # ## FIXME: use merged_module_links_depsets, merged_archive_links_depsets?
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

    if ctx.label.name == "Tezos_crypto":
        for d in ocamlProvider.files.to_list():
            print("NSLIBPROV DEP: %s" % d)

    if ctx.attr._rule == "ocaml_ns_archive":
        mnemonic = "CompileOcamlNsArchive"
    elif ctx.attr._rule == "ppx_ns_archive":
        mnemonic = "CompilePpxNsArchive"
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
    ################
    ################

    default_depset = depset(
        order  = dsorder,
        direct = [ns_archive_file] # , ns_archive_a_file],
    )

    newDefaultInfo = DefaultInfo(
        files = default_depset
    )
    ## adjuncts handled by impl_ns_library() above
    # indirect_adjunct_depsets = []
    # indirect_adjunct_paths = []
    # for submod in ctx.attr.submodules:
    #     if AdjunctDepsMarker in submod:
    #         ds = submod[AdjunctDepsMarker].nopam
    #         indirect_adjunct_depsets.append(ds)
    #         indirect_adjunct_paths.append(submod[AdjunctDepsMarker].nopam_paths)

    ppx_adjuncts_depset = adjunctsMarker.nopam
    # adjunctsMarker = AdjunctDepsMarker(
    #     # opam = depset(
    #     #     direct     = ctx.attr.deps_adjunct_opam,
    #     #     transitive = indirect_adjunct_opam_depsets
    #     # ),
    #     nopam = ppx_adjuncts_depset,
    #     # nopam = depset(
    #     #     # direct     = ctx.attr.deps_adjunct,
    #     #     # direct     = ctx.files.deps_adjunct,
    #     #     transitive = indirect_adjunct_depsets
    #     # ),
    #     nopam_paths = depset(transitive=indirect_adjunct_paths)
    # )

    cclib_files = []
    for tgt in ccMarker.libs.keys():
        cclib_files.extend(tgt.files.to_list())
    cclib_files_depset = depset(cclib_files)

    # ocamlPathsMarker = OcamlPathsMarker(
    #     paths  = depset(
    #         order = dsorder,
    #         direct = paths_direct,
    #         transitive = paths_indirect)
    # )

    ocamlProviderFiles_depset = depset(
        order  = dsorder,
        direct = [ns_archive_file],
        transitive = [all_deps]
    )
    ocamlProviderPaths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = [ocamlProvider.paths]
    )

    ocamlProvider = OcamlProvider(
        files = ocamlProviderFiles_depset,
        paths = ocamlProviderPaths_depset
    )

    # print("NS_ARCHIVE ADJUNCTS: %s" % adjunctsMarker)
    outputGroupInfo = OutputGroupInfo(
        # module_links  = module_links,
        # archive_links = archive_links,
        # depgraph = depgraph,
        # archived_modules = archived_modules,
        ppx_adjuncts = ppx_adjuncts_depset,
        cclibs = cclib_files_depset,
        all_files = depset(transitive=[
            default_depset,
            ocamlProviderFiles_depset,
            # module_links,
            # archive_links,
            ppx_adjuncts_depset,
            cclib_files_depset
        ])
    )

    if ctx.attr._rule == "ocaml_ns_archive":
        nsArchiveMarker = OcamlNsArchiveMarker(marker = "OcamlNsArchiveMarker")
    else:
        nsArchiveMarker = PpxNsArchiveMarker(marker = "PpxNsArchiveMarker")


    return [
        newDefaultInfo,
        nsArchiveMarker,
        ocamlProvider,
        outputGroupInfo,
        # ocamlPathsMarker,
        # nsArchiveMarker,
        adjunctsMarker,
        ccMarker
    ]


