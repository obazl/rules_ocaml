load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlArchiveProvider",
     "OcamlSDK",
     "PpxArchiveProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_projroot",
)

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl", "normalize_module_name")

load(":impl_common.bzl",
     "merge_deps",
     # "tmpdir"
     )

tmpdir = ""

##################################################
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
    outputs = [resolver_cm_, resolver_cmi]
    if resolver_o: outputs.append(resolver_o)

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
        outputs = outputs,
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

    outputs.append(ctx.outputs.resolver)
    return outputs

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
    OCAMLFIND_IGNORE = ""
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif/c"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"

    env = {
        "OPAMROOT": get_opamroot(),
        "PATH": get_sdkpath(ctx),
        "OCAMLFIND_IGNORE_DUPS_IN": OCAMLFIND_IGNORE
    }

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    resolver_outputs = []
    if ctx.attr.resolver:
        resolver_outputs = _generate_resolver(ctx, tc, env, mode)

    # print("RESOLVER OUTPUTS: %s" % resolver_outputs)

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
    includes = []
    outputs = []
    # if ctx.attr.resolver:
    #     outputs.append(ctx.outputs.resolver)

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
    outputs.append(out_cm_a)

    if mode == "native":
        if  not shared:
            out_a = ctx.actions.declare_file(tmpdir + module_name + ".a")
            outputs.append(out_a)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    args.add_all(_options)

    merge_deps(ctx.attr.modules,
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

    # opam_depset = depset(transitive = indirect_opam_depsets)
    ## DO NOT USE -linkpkg, it tells ocamlfind to put dep files on command line,
    ## which for native mode may result in:
    ## `Option -a cannot be used with .cmxa input files.`
    # for opam in opam_depset.to_list():
    #     args.add("-package", opam)  ## add dirs to search path

    indirect_paths_depset = depset(transitive = merged_paths_depsets)
    for path in indirect_paths_depset.to_list():
        includes.append(path)

    args.add_all(includes, before_each="-I", uniquify = True)

    ## modules to include in archive must be on command line
    ## use depsets to get the right ordering, then select to get only direct deps
    ## module links only; archives cannot depend on archives
    module_links_depset = depset(transitive = merged_module_links_depsets)
    for dep in module_links_depset.to_list():
        if ctx.attr.standalone:
            args.add(dep)
        else:
            if dep in ctx.files.modules:
                args.add(dep)

    direct_inputs = []
    if ctx.attr.resolver:
        args.add(resolver_outputs[0])
        direct_inputs = resolver_outputs

    if shared:
        args.add("-shared")
    else:
        args.add("-a")
    args.add("-o", out_cm_a)

    inputs_depset = depset(
        direct     = direct_inputs,
        transitive = merged_depgraph_depsets
    )

    ################
    ################
    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = inputs_depset,
        outputs = outputs,
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

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            direct = [out_cm_a]
        )
    )

    ## Avoid duplicate defns: remove direct deps from merged links depset
    links = depset(transitive = merged_module_links_depsets)
    filtered_links = []
    for link in links.to_list():
        if not link in ctx.files.modules:
            filtered_links.append(link)
    #     else:
    #         print("FILTERING OUT: %s" % link)
    # print("ARCHIVE MDEPSET: %s" % filtered_links)
    if ctx.attr._rule in ["ocaml_archive"]: # , "coq_plugin"]:
        archiveProvider = OcamlArchiveProvider(
            module_links     = depset(
                order = "postorder",
                direct = [out_cm_a],
                transitive = [depset(direct=filtered_links)]
            ),
            archive_links = depset(
                order = "postorder",
                direct = [out_cm_a],
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = [out_cm_a.dirname],
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                direct = outputs + resolver_outputs,
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = merged_archived_modules_depsets
            ),
        )
    elif ctx.attr._rule == "ppx_archive":
        archiveProvider = PpxArchiveProvider(
            module_links     = depset(
                order = "postorder",
                # direct = [out_cm_a],
                transitive = [depset(direct=filtered_links)]
            ),
            archive_links = depset(
                order = "postorder",
                direct = [out_cm_a],
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = [out_cm_a.dirname],
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                direct = outputs,
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = merged_archived_modules_depsets
            ),
        )

    cclibs = {}
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs
    )

    return [defaultInfo,
            archiveProvider,
            ## FIXME: opamProvider?
            ccProvider
            ]


