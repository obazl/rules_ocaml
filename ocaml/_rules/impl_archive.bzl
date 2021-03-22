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
     "tmpdir")

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

    ext  = ".cmxa" if  mode == "native" else ".cma"

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

    module_name = normalize_module_name(ctx.label.name)

    out_cm_a = ctx.actions.declare_file(tmpdir + module_name + ext)
    outputs.append(out_cm_a)

    if mode == "native":
        out_a = ctx.actions.declare_file(tmpdir + module_name + ".a")
        outputs.append(out_a)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    options = get_options(ctx.attr._rule, ctx)
    args.add_all(options)

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

    opam_depset = depset(transitive = indirect_opam_depsets)
    ## DO NOT USE -linkpkg, it tells ocamlfind to put dep files on command line,
    ## which for native mode may result in:
    ## `Option -a cannot be used with .cmxa input files.`
    for opam in opam_depset.to_list():
        args.add("-package", opam)  ## add dirs to search path

    indirect_paths_depset = depset(transitive = merged_paths_depsets)
    for path in indirect_paths_depset.to_list():
        includes.append(path)

    args.add_all(includes, before_each="-I", uniquify = True)

    ## modules to include in archive must be on command line
    ## use depsets to get the right ordering, then select to get only direct deps
    ## module links only; archives cannot depend on archives
    module_links_depset = depset(transitive = merged_module_links_depsets)
    for dep in module_links_depset.to_list():
        if dep in ctx.files.modules:
            args.add(dep)

    args.add("-a")
    args.add("-o", out_cm_a)

    inputs_depset = depset(transitive = merged_depgraph_depsets)

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
            ## this maintains dep ordering of archive files among all deps
            direct = [out_cm_a]
        )
    )

    if ctx.attr._rule == "ocaml_archive":
        archiveProvider = OcamlArchiveProvider(
            module_links     = depset(
                ## do NOT pass on component module links, only the archive links
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
    else:
        archiveProvider = PpxArchiveProvider(
            module_links     = depset(
                ## do NOT pass on component module links, only the archive links
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
            ccProvider
            ]


