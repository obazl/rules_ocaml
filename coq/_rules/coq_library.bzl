load("//coq:providers.bzl",
     "CoqLibraryProvider",
     "CoqSublibraryProvider")

# load("//ocaml/_rules:options.bzl", "options", "options_library")

# load(":impl_coq_library.bzl", "impl_coq_library")

def impl_coq_library(ctx):

    debug = False
    # if (ctx.label.name == "zexe_backend_common"):
    #     debug = True

    if debug:
        print("COQLIBRARY TARGET: %s" % ctx.label.name)

    # env = {"OPAMROOT": get_opamroot(),
    #        "PATH": get_sdkpath(ctx)}

    # tc = ctx.toolchains["@ocaml//ocaml:toolchain"]

    # mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ################
    # merged_module_links_depsets = []
    # merged_archive_links_depsets = []

    # merged_paths_depsets = []
    # merged_depgraph_depsets = []
    # merged_archived_modules_depsets = []

    # indirect_opam_depsets  = []

    # indirect_adjunct_depsets = []
    # indirect_adjunct_path_depsets = []
    # indirect_adjunct_opam_depsets  = []

    # indirect_cc_deps  = {}

    ################
    # merge_deps(ctx.attr.modules,
    #            merged_module_links_depsets,
    #            merged_archive_links_depsets,
    #            merged_paths_depsets,
    #            merged_depgraph_depsets,
    #            merged_archived_modules_depsets,
    #            indirect_opam_depsets,
    #            indirect_adjunct_depsets,
    #            indirect_adjunct_path_depsets,
    #            indirect_adjunct_opam_depsets,
    #            indirect_cc_deps)

    merged_deps = []
    for sublib in ctx.attr.sublibraries:
        merged_deps.append(sublib[DefaultInfo].files)

    sublibs_depset = depset(transitive=merged_deps)

    ## Library targets do not produce anything, they just build their deps and pass them on.
    #######################
    #######################
    ctx.actions.do_nothing( # force build of deps?
        mnemonic = "CoqLibrary",
        inputs = sublibs_depset
    )
    #######################
    #######################

    defaultInfo = DefaultInfo(
        files = depset(
            order = dsorder,
            transitive = [sublibs_depset]
        )
    )

    return [
        defaultInfo,
        CoqLibraryProvider(),
    ]

###############################
# rule_options = options("ocaml")

#####################
coq_library = rule(
    implementation = impl_coq_library,
    doc = """Aggregates a collection of coq_sublibrary modules.""",
    attrs = dict(
        # rule_options,
        sublibraries = attr.label_list(
            doc = "List of component modules.",
            providers = [[CoqSublibraryProvider], [CoqLibraryProvider]]
        ),
        _rule = attr.string( default = "coq_library" ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    ## this is not an ns library, and it does not use ns ConfigState,
    ## but we need to reset the ConfigState anyway, so the deps are not affected.
    # cfg     = nslib_in_transition,
    provides = [CoqLibraryProvider],
    executable = False,
    toolchains = ["@ocaml//ocaml:toolchain"],
)
