load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlNsLibraryProvider",
     "OpamDepsProvider",
     "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
)

load(":impl_common.bzl", "merge_deps")

#################
def impl_ns_library(ctx):

    debug = False
    # if ctx.label.name in ["jemalloc"]: # ["mina_metrics", "memory_stats"]:
    #     debug = True

    if debug:
        print("ConfigState (%s):" % ctx.label)
        print("  NS_RESOLVER: %s" % ctx.attr._ns_resolver[0].files)
        print("  NS_PREFIX: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
        print("  NS_SUBMODULES: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)

    if debug:
        print("")
        print("Start: IMPL_NS_LIBRARY: %s" % ctx.label)
        if ctx.attr._rule in ["ocaml_ns_archive", "ppx_ns_archive"]:
            print("  (for ns_archive)")

    if ctx.attr._rule in ["ocaml_ns_library", "ppx_ns_library"]:
        if not ctx.label.name.startswith("#"):
            fail("NS Library names must start with at least one '#' followed by a legal OCaml module name: %s" % ctx.label.name)

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    aliases = []

    ################
    merged_module_links_depsets = []
    merged_archive_links_depsets = []

    merged_paths_depsets = []
    merged_depgraph_depsets = []
    merged_archived_modules_depsets = []
    # direct_file_deps = []
    # indirect_file_depsets  = []
    # indirect_archive_depsets  = []

    indirect_opam_depsets  = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets = []

    # indirect_path_depsets  = []

    direct_resolver = None

    direct_cc_deps  = {}
    indirect_cc_deps  = {}
    ################

    resolver_files = None

    submodules = []
    includes   = []

    mydeps = ctx.attr.submodules + ctx.attr._ns_resolver #  + ctx.attr.sublibs
    merge_deps(mydeps,
               merged_module_links_depsets,
               merged_archive_links_depsets,
               merged_paths_depsets,
               merged_depgraph_depsets,
               merged_archived_modules_depsets,
               # indirect_file_depsets,
               # indirect_archive_depsets,
               # indirect_path_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    resolver_dep = ctx.files._ns_resolver

    inputs_depset = depset(
        order = "postorder",
        direct = resolver_dep,
        transitive = merged_depgraph_depsets
        # transitive = indirect_file_depsets + indirect_archive_depsets
    )

    if debug:
        print("INPUTS_DEPSET: %s" % inputs_depset)

    ## NS Lib targets do not directly produce anything, they just pass
    ## on their deps. The real work is done in the transition
    ## functions, which set the ConfigState that controls build
    ## actions of deps.

    #######################
    ctx.actions.do_nothing(
        mnemonic = "NS_LIB",
        inputs = inputs_depset
    )
    #######################

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            direct = ctx.files.submodules + ctx.files._ns_resolver,
            # transitive = indirect_file_depsets
            # transitive = indirect_file_depsets
        )
    )

    if debug:
        print("NSLIB DEFAULTINFO: %s" % defaultInfo)

    defaultMemo = DefaultMemo(
        paths  = depset(transitive = merged_paths_depsets),
        # files     = depset(
        #     order = "postorder",
        #     transitive = indirect_archive_depsets + indirect_file_depsets
        # )
    )
    if debug:
        print("NSLIB DEFAULTMEMO: %s" % defaultMemo)

    if ctx.attr._rule == "ocaml_ns_library":
        nslibProvider = OcamlNsLibraryProvider(
            module_links = depset(
                order = "postorder",
                direct = ctx.files.submodules + ctx.files._ns_resolver,
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = "postorder",
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                direct = ctx.files.submodules + ctx.files._ns_resolver,
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = merged_archived_modules_depsets
            ),
        )
    else:
        nslibProvider = PpxNsLibraryProvider(
            module_links = depset(
                order = "postorder",
                direct = ctx.files.submodules + ctx.files._ns_resolver,
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = "postorder",
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                direct = ctx.files.submodules + ctx.files._ns_resolver,
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = merged_archived_modules_depsets
            ),
        )

    opam_depset = depset(transitive = indirect_opam_depsets)
    opamProvider = OpamDepsProvider(
        pkgs = opam_depset
    )

    cclibs = {}
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs
    )

    if debug:
        print("NSLIB returning depgraph: %s" % nslibProvider.depgraph)

    return [
        defaultInfo,
        defaultMemo,
        nslibProvider,
        opamProvider,
        ccProvider
    ]

