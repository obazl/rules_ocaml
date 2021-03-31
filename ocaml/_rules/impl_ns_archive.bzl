load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
    "CompilationModeSettingProvider",
     "OcamlNsArchiveProvider",
     "PpxNsArchiveProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_projroot",
     "get_sdkpath",
)

load(":impl_ns_library.bzl", "impl_ns_library")

load("//ocaml/_functions:utils.bzl", "normalize_module_name")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "tmpdir")

#################
def impl_ns_archive(ctx):

    debug = False
    # if ctx.label.name in ["jemalloc"]: # ["mina_metrics", "memory_stats"]:
    #     debug = True

    if debug:
        print("ConfigState (%s):" % ctx.label)
        print("  NS_RESOLVER: %s" % ctx.attr._ns_resolver[0].files)
        print("  NS_PREFIX: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
        print("  NS_SUBMODULES: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)
    ## FIXME: do we need OCAMLFIND_IGNORE here?

    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ################################
    ####  call impl_ns_library  ####
    [
        defaultInfo,
        nslibProvider,
        opamProvider,
        ccProvider
    ] = impl_ns_library(ctx)
    ################################

    ## now archive the nslib

    ns_archive_name = normalize_module_name(ctx.label.name)
    ns_ext = ".cmxa" if mode == "native" else ".cma"
    ns_archive_filename = tmpdir + ns_archive_name + ns_ext
    ns_archive_file = ctx.actions.declare_file(ns_archive_filename)

    ns_archive_a_filename = tmpdir + ns_archive_name + ".a"
    ns_archive_a_file = ctx.actions.declare_file(ns_archive_a_filename)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    options = get_options(ctx.attr._rule, ctx)
    args.add_all(options)

    ## use depgraph to ensure correct ordering, filter to include only direct deps
    ## FIXME: use merged_module_links_depsets, merged_archive_links_depsets?
    submods = ctx.files.submodules
    for dep in nslibProvider.depgraph.to_list():
        if dep in submods:
            args.add(dep)
        ## direct submod deplist may not contain resolver
        elif dep.extension == "cmx":
            mod = normalize_module_name(dep.basename)
            if mod == ns_archive_name:
                args.add(dep)
            elif mod == ns_archive_name + "__0Resolver":
                args.add(dep)

    args.add("-a")

    args.add("-o", ns_archive_file)

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
        inputs = nslibProvider.depgraph,
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

    newDefaultInfo = DefaultInfo(
        files = depset(
            order  = "postorder",
            direct = [ns_archive_file],
        )
    )

    if ctx.attr._rule == "ocaml_ns_archive":
        nsArchiveProvider = OcamlNsArchiveProvider(
            module_links = depset( ),
            archive_links = depset(
                order = "postorder",
                direct = [ns_archive_file],
                transitive = [nslibProvider.archive_links]
            ),
            paths    = depset(
                direct = [ns_archive_file.dirname],
                transitive = [nslibProvider.paths]
            ),
            depgraph = depset(
                order = "postorder",
                direct = [ns_archive_file, ns_archive_a_file],
                transitive = [nslibProvider.depgraph]
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = [nslibProvider.archived_modules]
            ),
        )
    elif ctx.attr._rule == "ppx_ns_archive":
        nsArchiveProvider = PpxNsArchiveProvider(
            module_links = depset( ),
            archive_links = depset(
                order = "postorder",
                direct = [ns_archive_file],
                transitive = [nslibProvider.archive_links]
            ),
            paths    = depset(
                direct = [ns_archive_file.dirname],
                transitive = [nslibProvider.paths]
            ),
            depgraph = depset(
                order = "postorder",
                direct = [ns_archive_file, ns_archive_a_file],
                transitive = [nslibProvider.depgraph]
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = [nslibProvider.archived_modules]
            ),
        )
    else:
        fail("Unrecognized ctx.attr._rule: %s" % ctx.attr._rule)

    return [
        newDefaultInfo,
        nsArchiveProvider,
        opamProvider, ## FIXME: not needed?
        ccProvider
    ]


