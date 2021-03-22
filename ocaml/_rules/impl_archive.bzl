load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
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

    if ctx.attr._rule == "ppx_module":
        mode = ctx.attr._mode[0]
    else:
        mode = ctx.attr._mode[CompilationModeSettingProvider].value

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

    ext  = ".cmxa" if  mode == "native" else ".cma"

    if ctx.attr._rule == "ppx_archive":
        if "-linkpkg" in ctx.attr.opts:
            fail("-linkpkg option not supported for ppx_archive rule")

    obj_files = []
    obj_cm_a = None
    obj_a    = None

    module_name = normalize_module_name(ctx.label.name)
    obj_cm_a = ctx.actions.declare_file(tmpdir + module_name + ext) # ctx.label.name + ext)
    if mode == "native":
        obj_a = ctx.actions.declare_file(tmpdir + module_name + ".a") # ctx.label.name + ".a")

    build_deps = []  # for the command line
    includes = []
    dep_graph = []  # for the run action inputs

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

    direct_resolver = None

    direct_cc_deps  = {}
    indirect_cc_deps  = {}
    ################

    ################################################################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    cc_linkmode = tc.linkmode            # used below to determine linkmode for deps
    if ctx.attr._cc_linkmode:
        if ctx.attr._cc_linkmode[BuildSettingInfo].value == "static": # override toolchain default?
            cc_linkmode = "static"

    configurable_defaults = get_options(ctx.attr._rule, ctx)
    args.add_all(configurable_defaults)

    ## No direct cc_deps for archives - they should be attached to archive members
    # cc_deps   = []
    link_search  = []

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

    if len(indirect_opam_depsets) > 0:
        ## DO NOT USE -linkpkg, it tells ocamlfind to put dep files on command line,
        ## which for native mode may result in:
        ## `Option -a cannot be used with .cmxa input files.`
        opams = depset(transitive = indirect_opam_depsets)
        for opam in opams.to_list():
            # -package tells ocamlfind to add OPAM file dirs to search path with -I
            args.add("-package", opam)

    args.add("-a")

    indirect_paths_depset = depset(transitive = merged_paths_depsets)
    for path in indirect_paths_depset.to_list():
        # print("PATH: %s" % path)
        includes.append(path)
    args.add_all(includes, before_each="-I", uniquify = True)

    ## modules to include in archive must be on command line
    ## use depsets to get the right ordering, then select to get only direct deps
    ## module links only; archives cannot depend on archives
    module_links_depset = depset(transitive = merged_module_links_depsets)
    for dep in module_links_depset.to_list():
        if dep in ctx.files.modules:
            args.add(dep)

    inputs_depset = depset(transitive = merged_depgraph_depsets)

    args.add_all(link_search, before_each="-ccopt", uniquify = True)

    if mode == "native":
        obj_files.append(obj_a)

    obj_files.append(obj_cm_a)

    args.add("-o", obj_cm_a)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = inputs_depset,
        outputs = obj_files,
        tools = [tc.ocamlfind, tc.ocamlopt],
        mnemonic = "OcamlArchiveImpl" if ctx.attr._rule == "ocaml_archive" else "PpxArchiveImpl",
        progress_message = "{mode} compiling ocaml_archive: @{ws}//{pkg}:{tgt}".format(
            mode = mode,
            ws  = ctx.label.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            ## this maintains dep ordering of archive files among all deps
            direct = [obj_cm_a, obj_a] if obj_a else [obj_cm_a],
        )
    )

    defaultMemo = DefaultMemo(
        paths     = indirect_paths_depset,
    )

    ## ArchiveProvider.archives used for command line construction
    ## ArchiveProvider.deps for depgraph construction
    if ctx.attr._rule == "ocaml_archive":
        archiveProvider = OcamlArchiveProvider(
            module_links     = depset(
                order = "postorder",
            ),
            archive_links = depset(
                order = "postorder",
                direct = [obj_cm_a],
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = [obj_cm_a.dirname],
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                direct = obj_files,
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = merged_archived_modules_depsets
            ),
        )
    else:
        archiveProvider = PpxArchiveProvider(
            ## do NOT pass on component module links, only the archive links
            module_links     = depset(
                order = "postorder",
            ),
            archive_links = depset(
                order = "postorder",
                direct = [obj_cm_a],
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = [obj_cm_a.dirname],
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                direct = obj_files,
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
            defaultMemo,
            archiveProvider,
            ccProvider
            ]


