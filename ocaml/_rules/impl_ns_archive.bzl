load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
    "CompilationModeSettingProvider",
     "DefaultMemo",
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

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    ####  call impl_ns_library  ####
    [
        defaultInfo,
        defaultMemo,
        nslibProvider,
        opamProvider,
        ccProvider
    ] = impl_ns_library(ctx)
    ####

    ## now archive the lib

    ################################################################
    ns_archive_name = normalize_module_name(ctx.label.name) # .replace("-", "_")
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

    # args.add_all(defaultMemo.paths, before_each="-I", uniquify = True)

    # for dep in defaultInfo.files.to_list():
    #     if dep.extension not in ["cmxa", "cmi", "mli", "o"]:
    #         # args.add("-I", dep.dirname)
    #         args.add(dep)

    # for dep in ctx.files.submodules:
    #     # print("DEP %s" % dep)
    #     if dep.extension == "cmx":
    #         args.add(dep)

    # for dep in nslibProvider.module_links.to_list():
    # submods = nslibProvider.module_links.to_list()
    ## we must use depgraph to ensure correct ordering,
    ## but we only want to list what is explicitly listed in submodules
    submods = ctx.files.submodules
    for dep in nslibProvider.depgraph.to_list():
        if dep in submods:
            args.add(dep)
        elif dep.extension == "cmx":
            mod = normalize_module_name(dep.basename)
            if mod == ns_archive_name:
                args.add(dep)
            elif mod == ns_archive_name + "__0Resolver":
                args.add(dep)

    args.add("-a")

    args.add("-o", ns_archive_file)

    if ctx.attr._rule == "ocaml_ns_archive":
        mnemonic = "OcamlNsArchive"
    elif ctx.attr._rule == "ppx_ns_archive":
        mnemonic = "PpxNsArchive"
    else:
        fail("Unexpected rule type for impl_ns_archive: %s" % ctx.attr_rule)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = nslibProvider.depgraph,
        # depset(transitive = [defaultInfo.files] + [defaultMemo.files]),
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

    newDefaultInfo = DefaultInfo(
        files = depset(
            order  = "postorder",
            direct = [ns_archive_file], # ns_archive_a_file],
            # transitive = [defaultInfo.files]
        )
    )

    # execroot = get_projroot(ctx)
    # apath = execroot + "/" + ctx.workspace_name + "/" + ns_archive_file.dirname

    newDefaultMemo = DefaultMemo(
        # paths     = depset(direct = [apath], transitive = [defaultMemo.paths]),
        paths     = depset( transitive = [defaultMemo.paths] ),
        ## for archives: these are deps that need to go in the depgraph but not the command line
        files = depset(
            order  = "postorder",
            transitive = [defaultInfo.files]
        )
    )

    if ctx.attr._rule == "ocaml_ns_archive":
        nsArchiveProvider = OcamlNsArchiveProvider(
            module_links = depset(
                order = "postorder",
                # transitive = [nslibProvider.module_links]
            ),
            archive_links = depset(
                order = "postorder",
                direct = [ns_archive_file],
                transitive = [nslibProvider.archive_links]
            ),
            paths    = depset(
                direct = [ns_archive_file.dirname],
                transitive = [nslibProvider.paths]
            ),
            depgraph = depset( ## includes link files?
                order = "postorder",
                direct = [ns_archive_file, ns_archive_a_file],
                transitive = [nslibProvider.depgraph]
            ),
            archived_modules = depset( ## augments depgraph
                order = "postorder",
                transitive = [nslibProvider.archived_modules]
                # [defaultInfo.files] + [defaultMemo.files]
            ),
            # name   = ns_archive_name,
            # module = ns_archive_file
        )
    elif ctx.attr._rule == "ppx_ns_archive":
        nsArchiveProvider = PpxNsArchiveProvider(
            module_links = depset(
                order = "postorder",
                # transitive = [nslibProvider.module_links]
            ),
            archive_links = depset(
                order = "postorder",
                direct = [ns_archive_file],
                transitive = [nslibProvider.archive_links]
            ),
            paths    = depset(
                direct = [ns_archive_file.dirname],
                transitive = [nslibProvider.paths]
            ),
            depgraph = depset( ## includes link files?
                order = "postorder",
                direct = [ns_archive_file, ns_archive_a_file],
                transitive = [nslibProvider.depgraph]
            ),
            archived_modules = depset( ## augments depgraph
                order = "postorder",
                transitive = [nslibProvider.archived_modules]
                # [defaultInfo.files] + [defaultMemo.files]
            ),
            # name   = ns_archive_name,
            # module = ns_archive_file
        )
    # elif ctx.attr._rule == "ocaml_ns_library":
    #     nsArchiveProvider = OcamlNsArchiveProvider(
    #             name   = ns_archive_name,
    #             module = ns_archive_file
    #         )
    # elif ctx.attr._rule == "ppx_ns_library":
    #     nsArchiveProvider = PpxNsArchiveProvider(
    #             name   = ns_archive_name,
    #             module = ns_archive_file
    #         )
    else:
        fail("Unrecognized ctx.attr._rule: %s" % ctx.attr._rule)

    return [
        newDefaultInfo,
        newDefaultMemo,
        nsArchiveProvider,
        opamProvider,
        ccProvider
    ]


