load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlArchiveProvider",
     "OcamlModuleProvider",
     "OcamlNsResolverProvider",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "OcamlSDK",
     "PpxModuleProvider")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "normalize_module_name",
     "get_opamroot",
     "get_sdkpath",
)

load(":impl_common.bzl",
     "merge_deps",
     "tmpdir")

scope = tmpdir

#####################
def impl_module(ctx):

    debug = False
    # if ctx.label.name in ["_Snarky_group_map"]: # ["_Color", "_Demo__Red"]: # ["_Red", "_Green", "_Blue"]:
    #     debug = True

    if normalize_module_name(ctx.label.name) != normalize_module_name(ctx.file.struct.basename):
        print("Rule name: %s" % normalize_module_name(ctx.label.name))
        print("Structname: %s" % normalize_module_name(ctx.file.struct.basename))
        fail("Rule name and structfile name must yield same module name. Rule name may be prefixed with one or more underscores ('_'). Rule name: {rn}; structfile: {s}".format(rn=ctx.label.name, s=ctx.file.struct.basename))

    ns_prefixes     = ctx.attr._ns_prefixes[BuildSettingInfo].value
    ns_submodules = ctx.attr._ns_submodules[BuildSettingInfo].value

    if debug:
        print("")
        if ctx.attr._rule == "ocaml_module":
            print("Start: OCAMLMOD %s" % ctx.label)
        elif ctx.attr._rule == "ppx_module":
            print("Start: PPXMOD %s" % ctx.label)
        else:
            fail("Unexpected rule for 'impl_module': %s" % ctx.attr._rule)

        print("  _NS_RESOLVER: %s" % ctx.attr._ns_resolver[DefaultInfo])
        print("  _NS_RESOLVER Provider: %s" % ctx.attr._ns_resolver[OcamlNsResolverProvider])
        print("  _NS_PREFIXES: %s" % ns_prefixes)
        print("  _NS_SUBMODULES: %s" % ns_submodules)

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    if hasattr(ctx.attr, "ppx_tags"):
        if len(ctx.attr.ppx_tags) > 1:
            fail("Only one ppx_tag allowed currently.")

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    ## FIXME: use a build flag to pass these dirs.
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

    ################
    merged_module_links_depsets = []
    merged_archive_links_depsets = []

    merged_paths_depsets = []
    merged_depgraph_depsets = []
    merged_archived_modules_depsets = []

    indirect_opam_depsets = []

    indirect_cc_deps  = {}

    ## adjunct deps will be passed on but not used directly by this module
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets = []
    ################

    includes   = []
    outputs   = []

    (from_name, module_name) = get_module_name(ctx, ctx.file.struct)

    if ctx.attr.ppx:
        srcfile = impl_ppx_transform(ctx.attr._rule, ctx, ctx.file.struct, module_name + ".ml")
    elif module_name != from_name:
        srcfile = rename_srcfile(ctx, ctx.file.struct, module_name + ".ml")
    else:
        srcfile = ctx.file.struct

    basename = capitalize_initial_char(srcfile.basename)
    if mode == "native":
        ofname = paths.replace_extension(basename, ".o")
        out_o = ctx.actions.declare_file(scope + ofname)
        outputs.append(out_o)
        fname = paths.replace_extension(basename, ".cmx")
    else:
        fname = paths.replace_extension(basename, ".cmo")

    out_cm_ = ctx.actions.declare_file(scope + fname)
    outputs.append(out_cm_)
    includes.append(out_cm_.dirname)

    out_cmi = None
    out_cmt = None

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    options = get_options(ctx.attr._rule, ctx)
    args.add_all(options)

    mydeps = ctx.attr.deps + [ctx.attr._ns_resolver]
    merge_deps(mydeps,
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

    if debug:
        print("MERGED_MODULE_LINKS_DEPSETS: %s" % merged_module_links_depsets)
        print("MERGED_ARCHIVE_LINKS_DEPSETS: %s" % merged_archive_links_depsets)
        print("MERGED_ARCHIVED_MODULES_DEPSETS: %s" % merged_archived_modules_depsets)

    # if we have an input cmi, we will pass it on as Provider output,
    # but it is not an output of this action- do NOT add incoming cmi to action outputs
    ## TODO: support compile of mli source
    if ctx.attr.sig:
        for f in ctx.attr.sig:
            merged_module_links_depsets.append(f[OcamlSignatureProvider].module_links)
            merged_archive_links_depsets.append(f[OcamlSignatureProvider].archive_links)
            merged_paths_depsets.append(f[OcamlSignatureProvider].paths)
            merged_depgraph_depsets.append(f[OcamlSignatureProvider].depgraph)
            merged_archived_modules_depsets.append(f[OcamlSignatureProvider].archived_modules)
    else:
        ## no sigfile provided: compiler will infer and emit .cmi from .ml src,
        ## so we need to add the output file
        cmifname = paths.replace_extension(basename, ".cmi")
        out_cmi = ctx.actions.declare_file(scope + cmifname)
        outputs.append(out_cmi)

    if "-bin-annot" in options: ## Issue #17
        out_cmt = ctx.actions.declare_file(scope + paths.replace_extension(srcfile.basename, ".cmt"))
        outputs.append(out_cmt)

    indirect_paths_depset = depset(transitive = merged_paths_depsets)
    for path in indirect_paths_depset.to_list():
        includes.append(path)

    args.add_all(includes, before_each="-I", uniquify = True)

    opam_depset = depset(direct = ctx.attr.deps_opam,
                         transitive = indirect_opam_depsets)
    for dep in opam_depset.to_list():
        args.add("-package", dep)  ## add dirs to search path

    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[AdjunctDepsProvider]
        for opam in provider.opam.to_list():
            args.add("-package", opam)

        for nopam in provider.nopam.to_list():
            for nopamfile in nopam.files.to_list():
                adjunct_deps.append(nopamfile)
        for path in provider.nopam_paths.to_list():
            args.add("-I", path)

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
        ## this will only be the case if this is a submodule of an nslib
        args.add("-no-alias-deps")
        args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    module_links_depset = depset(transitive = merged_module_links_depsets)
    for dep in module_links_depset.to_list():
        if dep in ctx.files.deps:
            args.add(dep)

    args.add("-c")

    args.add("-o", out_cm_)

    args.add("-impl", srcfile)

    cc_direct_depfiles = []
    cc_indirect_depfiles = []
    for (dep, linkmode) in ctx.attr.cc_deps.items():
        if debug:
            print("Depgraph: direct CC dep %s" % dep[DefaultInfo].files.to_list())
        # add to dep graph but not command line:
        cc_direct_depfiles.extend(dep[DefaultInfo].files.to_list())

    for k in indirect_cc_deps.keys():
        if debug:
            print("Depgraph: Indirect CC k %s" % k[DefaultInfo].files.to_list())
        # add to dep graph but not command line:
        cc_indirect_depfiles.extend(k[DefaultInfo].files.to_list())

    input_depset = depset(
        order = "postorder",
        direct = [srcfile],
        # NB: these are NOT in the depgraph: cc_direct_depfiles + adjunct_deps + ctx.files.ppx,
        # Why not? cc deps need only be built for executable targets
        # adjunct deps are not needed to build this target
        # ppx has already been used above to transform source, not needed to build transformed source
        transitive = merged_depgraph_depsets
    )

    ################
    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs    = input_depset,
        outputs   = outputs,
        tools = [tc.ocamlfind, tc.ocamlopt, tc.ocamlc],
        mnemonic = "OCamlModuleCompile" if ctx.attr._rule == "ocaml_module" else "PpxModuleCompile",
        progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
            mode = mode,
            rule=ctx.attr._rule,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )
    ################

    search_paths = sets.to_list(sets.make(includes))  ## uniqify

    # DefaultInfo: only used to show outputs on cmd line;
    # depgraph etc. constructed from other providers.
    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            direct = [out_cm_],
        ),
    )

    if ctx.attr._rule == "ocaml_module":
        moduleProvider = OcamlModuleProvider(
            module_links     = depset(
                order = "postorder",
                direct = [out_cm_],
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = "postorder",
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = search_paths + [out_cm_.dirname],
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
    elif ctx.attr._rule == "ppx_module":
        moduleProvider = PpxModuleProvider(
            module_links     = depset(
                order = "postorder",
                direct = [out_cm_],
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = "postorder",
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = search_paths + [out_cm_.dirname],
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

    opamProvider = OpamDepsProvider(
        pkgs = opam_depset
    )

    adjunctsProvider = AdjunctDepsProvider(
        opam        = depset(transitive = indirect_adjunct_opam_depsets),
        nopam       = depset(transitive = indirect_adjunct_depsets),
        nopam_paths = depset(transitive = indirect_adjunct_path_depsets)
    )

    ## FIXME: catch incompatible key dups
    cclibs = {}
    cclibs.update(ctx.attr.cc_deps)
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs

    )

    return [
        defaultInfo,
        moduleProvider,
        opamProvider,
        adjunctsProvider,
        ccProvider
    ]
