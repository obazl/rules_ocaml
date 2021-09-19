load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",

     "AdjunctDepsMarker",
     "OcamlArchiveMarker",
     "OcamlModuleMarker",
     # "OcamlPathsMarker",
     "OcamlSDK",
     "PpxArchiveMarker")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_projroot",
)

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl", "normalize_module_name")

load(":impl_common.bzl",
     "dsorder",
     "merge_deps",
     "tmpdir"
     )

##################################################
## obsolete?
def _generate_resolver(ctx, tc, env, mode):

    aliases = ""
    for submod in ctx.attr.modules:
        aliases = aliases + "module {sm} = {sm}\n".format( sm = normalize_module_name(submod.label.name) )

    ctx.actions.write(
        output  = ctx.outputs.resolver,
        content = aliases
    )

    # resolver_module = normalize_module_name(ctx.attr.resolver.name)
    # print("XXXX %s" % ctx.outputs.resolver.extension)
    if ctx.outputs.resolver.extension == "ml":
        resolver_module = ctx.attr.resolver.name[:-3]
    else:
        resolver_module = ctx.attr.resolver.name

    if  mode == "native":
        resolver_o = ctx.actions.declare_file(tmpdir + resolver_module + ".o")
        ext = ".cmx"
    else:
        resolver_o = None
        ext = ".cmo"

    resolver_cm_ = ctx.actions.declare_file(tmpdir + resolver_module + ext)
    resolver_cmi = ctx.actions.declare_file(tmpdir + resolver_module + ".cmi")
    action_outputs = [resolver_cm_, resolver_cmi]
    if resolver_o: action_outputs.append(resolver_o)

    resolver_args = ctx.actions.args()
    if mode == "native":
        resolver_args.add(tc.ocamlopt.basename)
    else:
        resolver_args.add(tc.ocamlc.basename)

    resolver_args.add("-w", "-49") # Warning 49: no cmi file was found in path for module
    resolver_args.add("-no-alias-deps")
    resolver_args.add("-linkall")
    resolver_args.add("-c")
    resolver_args.add("-impl", ctx.outputs.resolver)
    resolver_args.add("-o", resolver_cm_)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [resolver_args],
        inputs = [ctx.outputs.resolver],
        outputs = action_outputs,
        tools = [tc.ocamlfind, tc.ocamlopt],
        mnemonic = "CompileOcamlArchiveResolver",
        progress_message = "{mode} compiling: @{ws}//{pkg}:{tgt}".format(
            mode = mode,
            # arch = ctx.attr._rule,
            ws  = ctx.label.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )

    action_outputs.append(ctx.outputs.resolver)
    return action_outputs

##################################################
def impl_archive(ctx):

    debug = False
    # if (ctx.label.name == "zexe_backend_common"):
    #     debug = True

    if debug:
        print("ARCHIVE TARGET: %s" % ctx.label.name)

    if ctx.attr._rule == "ppx_archive":
        if "-linkpkg" in ctx.attr.opts:
            fail("-linkpkg option not supported for ppx_archive rule")

    ## topdirs.cmi, digestif.cmi, ...
    # OCAMLFIND_IGNORE = ""
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif/c"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"

    env = {
        "OPAMROOT": get_opamroot(),
        "PATH": get_sdkpath(ctx),
        # "OCAMLFIND_IGNORE_DUPS_IN": OCAMLFIND_IGNORE
    }

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    # resolver_outputs = []
    # if ctx.attr.resolver:       # ns_archive
    #     resolver_outputs = _generate_resolver(ctx, tc, env, mode)

    # print("RESOLVER OUTPUTS: %s" % resolver_outputs)

    ################
    # merged_module_links_depsets = []
    # merged_archive_links_depsets = []

    # merged_paths_depsets = []
    # merged_depgraph_depsets = []
    # merged_archived_modules_depsets = []

    # indirect_opam_depsets = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    # indirect_adjunct_opam_depsets = []

    indirect_cc_deps  = {}

    ################
    includes = []
    default_outputs = []
    action_outputs = []
    rule_outputs   = []
    # if ctx.attr.resolver:
    #     action_outputs.append(ctx.outputs.resolver)

    module_name = normalize_module_name(ctx.label.name)

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
        ext = ".cmx"

    if shared:
        module_name = ctx.label.name
        out_cm_a = ctx.actions.declare_file(tmpdir + module_name + ext)
    else:
        out_cm_a = ctx.actions.declare_file(tmpdir + module_name + ext)
    action_outputs.append(out_cm_a)
    rule_outputs.append(out_cm_a)

    if mode == "native":
        if  not shared:
            out_a = ctx.actions.declare_file(tmpdir + module_name + ".a")
            action_outputs.append(out_a)
            rule_outputs.append(out_a)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    args.add_all(_options)

    # merge_deps(ctx.attr.modules,
    #            merged_module_links_depsets,
    #            merged_archive_links_depsets,
    #            merged_paths_depsets,
    #            merged_depgraph_depsets,
    #            merged_archived_modules_depsets,
    #            # indirect_opam_depsets,
    #            indirect_adjunct_depsets,
    #            indirect_adjunct_path_depsets,
    #            # indirect_adjunct_opam_depsets,
    #            indirect_cc_deps)

    # opam_depset = depset(transitive = indirect_opam_depsets)
    ## DO NOT USE -linkpkg, it tells ocamlfind to put dep files on command line,
    ## which for native mode may result in:
    ## `Option -a cannot be used with .cmxa input files.`
    # for opam in opam_depset.to_list():
    #     args.add("-package", opam)  ## add dirs to search path

    # indirect_paths_depset = depset(transitive = merged_paths_depsets)
    # for path in indirect_paths_depset.to_list():
    #     includes.append(path)

    # args.add_all(includes, before_each="-I", uniquify = True)

    paths_direct = [d.dirname for d in rule_outputs]
    paths_indirect = []
    all_deps_list = []

    for dep in ctx.attr.modules:
        print("MDEP: {host} => {d}".format(host=ctx.label, d = dep.label))
        ################ OCamlMarker ################
        if OcamlProvider in dep:
            all_deps_list.append(dep[OcamlProvider].files)
            paths_indirect.append(dep[OcamlProvider].paths)

        # ################ Paths ################
        # if OcamlPathsMarker in dep:
        #     ps = dep[OcamlPathsMarker].paths
        #     print("MPATHS: %s" % ps)
        #     paths_indirect.append(ps)

        # ################ Archive Deps ################
        # if OcamlArchiveMarker in dep:
        #     all_deps_list.append(dep[OcamlArchiveMarker].files)

        # ################ module deps ################
        # if OcamlModuleMarker in dep:
        #     all_deps_list.append(dep[OcamlModuleMarker].files)


    all_deps = depset(
        order = dsorder,
        transitive = all_deps_list
    )

    print("ALL_DEPS for MODULE %s" % ctx.label)
    # for d in reversed(all_deps.to_list()):
    for d in all_deps.to_list():
        # print("ALL_DEPS: %s" % d)
        # "Option -a cannot be used with .cmxa input files."
        if d.extension not in ["cmxa", "cma", "cmi", "mli", "a", "o"]:
            args.add(d.path)

    # ## modules to include in archive must be on command line
    # ## use depsets to get the right ordering, then select to get only direct deps
    # ## module links only; archives cannot depend on archives
    # module_links_depset = depset(transitive = merged_module_links_depsets)
    # for dep in module_links_depset.to_list():
    #     if ctx.attr.standalone:
    #         if dep.extension not in ["cmi"]:
    #             args.add(dep)
    #     else:
    #         if dep in ctx.files.modules:
    #             if dep.extension not in ["cmi"]:
    #                 args.add(dep)

    # direct_inputs = []
    # if ctx.attr.resolver:
    #     args.add(resolver_outputs[0])
    #     direct_inputs = resolver_outputs

    if shared:
        args.add("-shared")
    else:
        args.add("-a")
    args.add("-o", out_cm_a)

    inputs_depset = depset(
        # direct     = direct_inputs,
        transitive = [all_deps]  ## merged_depgraph_depsets
    )

    ################
    ################
    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = inputs_depset,
        outputs = action_outputs,
        tools = [tc.ocamlfind, tc.ocamlopt],
        mnemonic = "CompileOcamlArchive" if ctx.attr._rule == "ocaml_archive" else "CompilePpxArchive",
        progress_message = "{mode} compiling {arch}: @{ws}//{pkg}:{tgt}".format(
            mode = mode,
            arch = ctx.attr._rule,
            ws  = ctx.label.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )
    ################
    ################

    default_depset = depset(
        order = dsorder,
        direct = [out_cm_a]
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    paths_depset = depset(
        direct = paths_direct, ## [out_cm_a.dirname],
        transitive = paths_indirect
    )

    ## Avoid duplicate defns: remove direct deps from merged links depset
    # links = depset(transitive = merged_module_links_depsets)
    # filtered_links = []
    # for link in links.to_list():
    #     if not link in ctx.files.modules:
    #         filtered_links.append(link)
    # #     else:
    # #         print("FILTERING OUT: %s" % link)
    # # print("ARCHIVE MDEPSET: %s" % filtered_links)

    # module_links     = depset(
    #     order = dsorder,
    #     direct = [out_cm_a],
    #     # ppx? direct = [out_cm_a],
    #     transitive = [depset(direct=filtered_links)]
    # )
    # archive_links = depset(
    #     order = dsorder,
    #     direct = [out_cm_a],
    #     transitive = merged_archive_links_depsets
    # )
    # depgraph = depset(
    #     order = dsorder,
    #     # ppx? direct = outputs,
    #     direct = rule_outputs, # + resolver_outputs,
    #     transitive = merged_depgraph_depsets
    # )
    # archived_modules = depset(
    #     order = dsorder,
    #     transitive = merged_archived_modules_depsets
    # )

    # if ctx.attr._rule in ["ocaml_archive"]: # , "coq_plugin"]:
    #     archiveMarker = OcamlArchiveMarker(
    #         files = depset(
    #             direct = rule_outputs,
    #             transitive = all_deps_list
    #         ),
    #         module_links = module_links,
    #         archive_links = archive_links,
    #         paths = paths_depset,
    #         depgraph = depgraph,
    #         archived_modules = archived_modules
    #     )
    # elif ctx.attr._rule == "ppx_archive":
    #     archiveMarker = PpxArchiveMarker(
    #         files = depset(
    #             direct = rule_outputs,
    #             transitive = all_deps_list
    #         ),
    #         module_links = module_links,
    #         archive_links = archive_links,
    #         paths = paths_depset,
    #         depgraph = depgraph,
    #         archived_modules = archived_modules
    #     )

    ppx_adjuncts_depset = depset(
        # direct = adjunct_deps,
        transitive = indirect_adjunct_depsets
    )

    adjunctsMarker = AdjunctDepsMarker(
        nopam       = ppx_adjuncts_depset,
        nopam_paths = depset(transitive = indirect_adjunct_path_depsets)
    )

    cclibs = {}
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccMarker = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        ccdeps_map = cclibs
    )
    cclib_files = []
    for tgt in cclibs.keys():
        cclib_files.extend(tgt.files.to_list())
    cclib_files_depset = depset(cclib_files)

    if ctx.attr._rule in ["ocaml_archive"]: # , "coq_plugin"]:
        ruleMarker = OcamlArchiveMarker(marker = "OcamlArchiveMarker")
    else:
        ruleMarker = PpxArchiveMarker(marker = "PpxArchiveMarker")

    ocamlProviderDepset = depset(
        order  = dsorder,
        direct = action_outputs, # + [out_cmi] + mli_out,
        transitive = [all_deps]
    )

    ocamlProvider = OcamlProvider(
        files = ocamlProviderDepset,
        paths = paths_depset
    )

    outputGroupInfo = OutputGroupInfo(
        # module_links  = module_links,
        # archive_links = archive_links,
        # depgraph = depgraph,
        # archived_modules = archived_modules,
        ppx_adjuncts = ppx_adjuncts_depset,
        cclibs = cclib_files_depset,
        all_files = depset(transitive=[
            # module_links,
            # archive_links,
            ppx_adjuncts_depset,
            cclib_files_depset
        ])
    )

    return [defaultInfo,
            ruleMarker,
            outputGroupInfo,
            # archiveMarker,
            adjunctsMarker,
            ccMarker
            ]


