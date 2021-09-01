load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
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
        print("")
        print("Start: IMPL_NS_LIBRARY: %s" % ctx.label)
        if ctx.attr._rule in ["ocaml_ns_archive", "ppx_ns_archive"]:
            print("  (for ns_archive)")
        print("ConfigState (%s):" % ctx.label)
        print("  NS_RESOLVER: %s" % ctx.attr._ns_resolver[0].files)
        print("  NS_PREFIX: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
        print("  NS_SUBMODULES: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)

    # if ctx.attr._rule in ["ocaml_ns_library", "ppx_ns_library"]:
        # if not ctx.label.name.startswith("#"):
        #     fail("NS Library names must start with at least one '#' followed by a legal OCaml module name: %s" % ctx.label.name)

    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ################
    merged_module_links_depsets = []
    merged_archive_links_depsets = []

    merged_paths_depsets = []
    merged_depgraph_depsets = []
    merged_archived_modules_depsets = []

    indirect_opam_depsets  = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets = []

    indirect_cc_deps  = {}

    ################
    mdeps = ctx.attr.submodules + ctx.attr._ns_resolver ## _ns_resolver is a list too
    merge_deps(mdeps,
               merged_module_links_depsets,
               merged_archive_links_depsets,
               merged_paths_depsets,
               merged_depgraph_depsets,
               merged_archived_modules_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    inputs_depset = depset(
        order = "postorder",
        direct = ctx.files._ns_resolver,
        transitive = merged_depgraph_depsets
    )

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
            transitive = merged_module_links_depsets
            # direct = ctx.files.submodules + ctx.files._ns_resolver,
        )
    )

    if ctx.attr._rule == "ocaml_ns_library":
        nslibProvider = OcamlNsLibraryProvider(
            module_links = depset(
                order = "postorder",
                # direct = ctx.files.submodules + ctx.files._ns_resolver,
                direct = ctx.files._ns_resolver,
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

    return [
        defaultInfo,
        nslibProvider,
        opamProvider,
        ## FIXME: adjuncts?
        ccProvider
    ]

