load("@bazel_skylib//lib:collections.bzl", "collections")

load("@obazl_rules_ocaml//ocaml:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlModuleProvider")

load("//coq:providers.bzl", "CoqSublibraryProvider")

scope = "" # "__obazl/"

#####################
def impl_coq_sublibrary(ctx):

    debug = False
    # if ctx.label.name in ["Ltac", "Logic", "Hurkens"]:
    #     debug = True

    if debug:
        print("")
        print("Start: COQ_SUBLIBRARY %s" % ctx.label)

    # env = {
    #     "OPAMROOT": get_opamroot(),
    #     "PATH": get_sdkpath(ctx),
    # }

    # tc = ctx.toolchains["@coq_sdk//toolchains:toolchain_type"]
    tc = ctx.toolchains["@obazl_rules_ocaml//coq:toolchain_type"]
    # tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    # mode = ctx.attr._mode[CompilationModeSettingProvider].value

    # ext  = ".cmx" if  mode == "native" else ".cmo"

    ################
    merged_module_links_depsets = []
    merged_archive_links_depsets = []

    merged_paths_depsets = []
    merged_depgraph_depsets = []
    merged_archived_modules_depsets = []

    indirect_opam_depsets = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets = []

    indirect_cc_deps  = {}

    ################
    includes   = []
    outputs   = []

    # (from_name, module_name) = get_module_name(ctx, ctx.file.struct)
    # module_name = ctx.file.src.short_path[:-2]
    module_name = ctx.label.name

    ## OUTPUTS:
    ## Wf.vo Wf.glob Wf.v.beautified Wf.required_vo:
    ## Wf.vio:

    out_vo = ctx.actions.declare_file(scope + module_name + ".vo")
    outputs.append(out_vo)

    # out_vok = ctx.actions.declare_file(scope + module_name + ".vok")
    # outputs.append(out_vok)

    # out_vos = ctx.actions.declare_file(scope + module_name + ".vos")
    # outputs.append(out_vos)

    # out_glob = ctx.actions.declare_file(scope + module_name + ".glob")
    # outputs.append(out_glob)

    # if mode == "native":
    #     out_o = ctx.actions.declare_file(tmpdir + module_name + ".o")
    #     outputs.append(out_o)

    #########################
    args = ctx.actions.args()

    args.add_all(ctx.attr.opts)

    # if mode == "native":
    #     args.add(tc.ocamlopt.basename)
    # else:
    #     args.add(tc.ocamlc.basename)

    # _options = get_options(ctx.attr._rule, ctx)

    # if not ctx.label.name == "Ring_tac":
    # args.add("-boot") # don't bind the `Coq.` prefix to the default -coqlib dir (NB: _default_ -coqlib dir)
    # args.add("-noinit") # don't load Coq.Init.Prelude on start
    args.add("-coqlib", "bazel-out/darwin-fastbuild/bin")
    # args.add("-I", "bazel-out/darwin-fastbuild/bin/plugins/ltac")
    # args.add("-I", "bazel-out/darwin-fastbuild/bin")
    args.add("-q")
    args.add("-R")
    args.add("bazel-out/darwin-fastbuild/bin/theories", "Coq")

    plugin_includes = []
    load_paths = []

    plugins_indirect = []

    ## FIXME: with_libs means adjunct deps? the coqc tool depends on them at compile time?
    if ctx.attr.with_libs:
        for (lbl, lib) in ctx.attr.with_libs.items():
            args.add("-ri", lib)
            for f in lbl[DefaultInfo].files.to_list():
                if f.extension == "cmxs":
                    plugin_includes.append(f.dirname)
                load_paths.append(f.dirname) # "bazel-out/darwin-fastbuild/bin/theories/Init")
            # now handle indirect plugins
            if CoqSublibraryProvider in lbl:
                plugins = lbl[CoqSublibraryProvider].plugins
                plugins_indirect.append(plugins)
                for plugin in plugins.to_list():
                    load_paths.append(plugin.dirname)

    for dep in ctx.attr.deps:  ## coq_sublibrary deps
        plugins_indirect.append(dep[CoqSublibraryProvider].plugins)
        # print("INDIRECT PLUGINS: %s" % dep[CoqSublibraryProvider].plugins)
        for f in dep[DefaultInfo].files.to_list():
            # if f.extension == "cmxs":
            #     plugin_includes.append(f.dirname)
            load_paths.append(f.dirname) # "bazel-out/darwin-fastbuild/bin/theories/Init")
        for plugin in dep[CoqSublibraryProvider].plugins.to_list():
            if debug:
                print("XXXX %s" % plugin)
            load_paths.append(plugin.dirname)

    if debug:
        print("PLUGINS_INDIRECT %s" % plugins_indirect)

    args.add_all(load_paths, before_each="-I", uniquify = True)
    # load_paths = collections.uniq(load_paths)

    # for path in load_paths:
    #     args.add("-I", path)
    #     args.add("-R", path)
    #     args.add("")
        # args.add("-R", path)
        # args.add("Coq")

            # args.add("Coq")
            # args.add("-Q", "theories/Init")
            # args.add("-ri", "Coq.Init.Notation")
            # args.add("-load-vernac-source-verbose", dep.basename[:-3])

            # args.add("-load-vernac-object", dep.basename[:-3])

            # args.add("theories.Init")
            # args.add("-ri", dep.short_path) # "plugins/ltac")


    plugins_direct = []
    if ctx.attr.plugins:
        for plugin in ctx.attr.plugins:
            if OcamlArchiveProvider in plugin:
                provider = plugin[OcamlArchiveProvider]
            else:
                provider = plugin[OcamlModuleProvider]
                # plugins_direct.append(plugin[OcamlModuleProvider].depgraph) # FIXME temporary hack
            plugins_direct.extend(plugin.files.to_list()) # provider.depgraph)

            for path in provider.paths.to_list():
                plugin_includes.append(path)

    if debug:
        print("PLUGINS_DIRECT: %s" % plugins_direct)
        print("PLUGIN INCLUDES: %s" % plugin_includes)

    # plugin_includes = collections.uniq(plugin_includes)
    args.add_all(plugin_includes, before_each="-I", uniquify=True)

    # args.add("-Q", "plugins/ltac")
    # args.add("Coq")
    # args.add("Ltac")
    # args.add("-vos")
    # args.add("-vok")
    # args.add("-vio")

    args.add("-o", out_vo)

    # args.add("-vos")

    args.add(ctx.file.src)

    libs = []
    for lib in ctx.attr.with_libs.keys():
        for f in lib[DefaultInfo].files.to_list():
            libs.append(f)

    inputs_depset = depset(
        order = dsorder,
        direct = [ctx.file.src] + ctx.files.deps + libs + plugins_direct + [
            # ctx.file.tool
            # tc.coqc
        ],
        transitive = plugins_indirect
    )
        # NB: these are NOT in the depgraph: cc_direct_depfiles + adjunct_deps + ctx.files.ppx,
        # Why not? cc deps need only be built for executable targets
        # adjunct deps are not needed to build this target
        # ppx has already been used above to transform source, not needed to build transformed source

    ################
    ################
    ctx.actions.run(
        executable = tc.coqc,
        # executable = ctx.file.tool.path,
        # env = env,
        arguments = [args],
        inputs    = inputs_depset,
        outputs   = outputs,
        # tools = [tc.coqc],
        mnemonic = "CompileCoqModule",
        progress_message = "compiling {rule}: {ws}//{pkg}:{tgt}".format(
            rule=ctx.attr._rule,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )
    ################
    ################

    indirects = []
    for dep in ctx.attr.deps:
        indirects.append(dep[DefaultInfo].files)

    # for dep in ctx.attr.plugins:
    #     indirects.append(dep[DefaultInfo].files)

    defaultInfo = DefaultInfo(
        files = depset(
            order = dsorder,
            direct = [out_vo],
            transitive = indirects ## + [plugins_direct]
        ),
    )

    sublibProvider = CoqSublibraryProvider(
        plugins = depset(direct = plugins_direct, transitive = plugins_indirect)
    )

    return [
        defaultInfo,
        sublibProvider
    ]

####################
coq_sublibrary = rule(
    implementation = impl_coq_sublibrary,
    doc = """Compiles .v file.""",
    attrs = dict(

        src = attr.label(
            doc = "A single .v source file",
            # mandatory = True, # pack libs may not need a src file
            allow_single_file = True # no constraints on extension
        ),
        with_libs = attr.label_keyed_string_dict(
            doc = "Dict of (path, lib) pairs"
        ),
        opts = attr.string_list(
        ),
        plugins = attr.label_list(
        ),
        deps = attr.label_list(
            doc = ".vo deps",
            # providers = [CoqSublibraryProvider]
        ),
        deps_vio = attr.label_list(
            doc = ".vio deps",
            # providers = providers,
            # transition undoes changes that may have been made by ns_lib
        ),
        _rule = attr.string( default = "coq_sublibrary" ),
        _debug = attr.bool(),
        # tool = attr.label(
        #     allow_single_file = True,
        #     default = "@//topbin:coqc"
        #     # executable = True,
        #     # cfg        = "exec",
        # ),
    ),
    provides = [CoqSublibraryProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//coq:toolchain_type"],
    # toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"]
    # toolchains = ["@coq_sdk//toolchains:toolchain_type"],
)
