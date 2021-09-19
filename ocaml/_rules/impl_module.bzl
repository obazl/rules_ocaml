load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "CompilationModeSettingProvider",

     "AdjunctDepsMarker",
     "CcDepsProvider",
     "OcamlArchiveMarker",
     "OcamlModuleMarker",
     "OcamlNsResolverProvider",
     "OcamlSignatureProvider",
     "OcamlSDK",
     "PpxModuleMarker")

# load("//ocaml:providers.bzl",
#      "OcamlImportMarker",
#      "OcamlImportArchivesMarker",
#      "OcamlImportPluginsMarker",
#      "OcamlImportSignaturesMarker",
#      "OcamlImportPathsMarker",
#      "OcamlImportPpxAdjunctsMarker")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load("//ocaml/_rules/utils:utils.bzl",
     "get_options",
     )

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "file_to_lib_name",
     "get_opamroot",
     "get_sdkpath",
     "normalize_module_name",
)

load(":impl_ccdeps.bzl", "handle_ccdeps")

load(":impl_common.bzl",
     "dsorder",
     "merge_deps",
     "opam_lib_prefix",
     "tmpdir"
     )

scope = tmpdir

#####################
def impl_module(ctx):

    debug = False

    print("**************** MODULE {} ****************".format(ctx.label))

    # if ctx.label.name in ["embedded_cmis"]:
        # debug = True

    # if normalize_module_name(ctx.label.name) != normalize_module_name(ctx.file.struct.basename):
    #     print("Rule name: %s" % normalize_module_name(ctx.label.name))
    #     print("Structname: %s" % normalize_module_name(ctx.file.struct.basename))
        # fail("Rule name and structfile name must yield same module name. Rule name may be prefixed with one or more underscores ('_'). Rule name: {rn}; structfile: {s}".format(rn=ctx.label.name, s=ctx.file.struct.basename))

    if hasattr(ctx.attr, "ppx_tags"):
        if len(ctx.attr.ppx_tags) > 1:
            fail("Only one ppx_tag allowed currently.")

    if debug:
        print("")
        if ctx.attr._rule == "ocaml_module":
            print("Start: OCAMLMOD %s" % ctx.label)
        elif ctx.attr._rule == "ppx_module":
            print("Start: PPXMOD %s" % ctx.label)
        else:
            fail("Unexpected rule for 'impl_module': %s" % ctx.attr._rule)

        print("  _NS_RESOLVER: %s" % ctx.attr._ns_resolver[DefaultInfo])
        print("  _NS_RESOLVER Marker: %s" % ctx.attr._ns_resolver[OcamlNsResolverProvider])
        ns_prefixes     = ctx.attr._ns_prefixes[BuildSettingInfo].value
        ns_submodules = ctx.attr._ns_submodules[BuildSettingInfo].value
        print("  _NS_PREFIXES: %s" % ns_prefixes)
        print("  _NS_SUBMODULES: %s" % ns_submodules)

    ## FIXME: use a build flag to pass these dirs.
    ## topdirs.cmi, digestif.cmi, ...
    # OCAMLFIND_IGNORE = ""
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif" ## FIXME: mina-specific
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif/c" ## FIXME: mina-specific
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml"
    # OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"

    env = {
        "OPAMROOT": get_opamroot(),
        "PATH": get_sdkpath(ctx),
        # "OCAMLFIND_IGNORE_DUPS_IN": OCAMLFIND_IGNORE
    }

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    # if len(ctx.attr.deps_opam) > 0:
    #     using_ocamlfind = True
    #     ocamlfind_opts = ["-predicates", "ppx_driver"]
    #     exe = tc.ocamlfind
    # else:
    # using_ocamlfind = False
    # ocamlfind_opts = []
    if mode == "native":
        exe = tc.ocamlopt.basename
    else:
        exe = tc.ocamlc.basename

    ext  = ".cmx" if  mode == "native" else ".cmo"

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
    includes   = []
    default_outputs   = []
    action_outputs   = []
    rule_outputs = []
    out_cmi = None

    ## module name is derived from sigfile name, so start with sig
    module_name = None
    mlifile = None
    if ctx.attr.sig:
        print("SIG_%s" % ctx.label.name)

        # derive module name from sigfile
        # for submodules, sigfile name will already contain ns prefix
        sigProvider = ctx.attr.sig[OcamlSignatureProvider]
        out_cmi = sigProvider.cmi
        rule_outputs.append(out_cmi)
        mlifile = sigProvider.mli
        rule_outputs.append(mlifile)
        # print("OUT CMI: %s" % out_cmi)
        module_name = out_cmi.basename[:-4]
        if sigProvider.mli.is_source:  # not a generated file
            # print("IN SIG: %s" % mlifile)
            tmp = capitalize_initial_char(sigProvider.mli.basename)
            normalized_modname = normalize_module_name(sigProvider.mli.basename) + ".mli"
            if (tmp != normalized_modname):
                mlifile = rename_srcfile(ctx, sigProvider.mli, normalized_modname)
            else:
                mlifile = sigProvider.mli
            # print("OUT SIG: %s" % mlifile)
            includes.append(mlifile.dirname)

    if module_name == None:
        print("NOSIG_%s" % ctx.label.name)
        # no sigfile dependency, so derive module name from structfile
        # detects and adds ns prefix if appropriate:
        (from_name, module_name) = get_module_name(ctx, ctx.file.struct)
        # and declare cmi output, since ocaml will generate it
        out_cmi = ctx.actions.declare_file(scope + module_name + ".cmi")
        action_outputs.append(out_cmi)
        rule_outputs.append(out_cmi)

    out_cm_ = ctx.actions.declare_file(scope + module_name + ext) # fname)
    action_outputs.append(out_cm_)
    rule_outputs.append(out_cm_)
    default_outputs.append(out_cm_)

    if mode == "native":
        out_o = ctx.actions.declare_file(scope + module_name + ".o")
        action_outputs.append(out_o)
        rule_outputs.append(out_o)

    paths_direct = [d.dirname for d in rule_outputs]
    # print("PATHS_DIRECT: %s" % paths_direct)

    #########################
    args = ctx.actions.args()

    # if using_ocamlfind:
    #     if mode == "native":
    #         args.add(tc.ocamlopt.basename)
    #     else:
    #         args.add(tc.ocamlc.basename)

    _options = get_options(ctx.attr._rule, ctx)
    # if "-for-pack" in _options:
    #     for_pack = True
    #     _options.remove("-for-pack")
    # else:
    #     for_pack = False
    # args.add_all(_options)

    ## FIXME: support -bin-annot
    # if "-bin-annot" in _options: ## Issue #17
    #     out_cmt = ctx.actions.declare_file(scope + paths.replace_extension(module_name, ".cmt"))
    #     action_outputs.append(out_cmt)

    # mdeps = []
    # mdeps.extend(ctx.attr.deps)
    # mdeps.append(ctx.attr._ns_resolver)
    # mdeps.append(ctx.attr.cc_deps)
    # if ctx.attr.sig:
    #     mdeps.append(ctx.attr.sig)

    # if debug:
    #     print("MDEPS: %s" % mdeps)
    # merge_deps(mdeps,
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

    # if ctx.label.name == "rustzcash":
    #     ds = depset(order = dsorder,
    #                 transitive=merged_module_links_depsets)
    #     for dep in ds.to_list():
    #         if dep.basename.startswith("bls12"):
    #             print("XDEPM: %s" % dep.basename)
    #     ds = depset(order = dsorder,
    #                 transitive=merged_archive_links_depsets)
    #     for dep in ds.to_list():
    #         if dep.basename.startswith("bls12"):
    #             print("XDEPA: %s" % dep.basename)

    #     print("XMODULE {m} MODULE_LINKS_DEPSETS: {ds}".format(
    #         m = ctx.label, ds = merged_module_links_depsets)
    #           )
        # print("YMODULE {m} MERGED_MODULE_LINKS_DEPSETS: {ds}".format(
        #     m = ctx.label,
        #     ds = depset(transitive=merged_module_links_depsets)
        # ))

    # if debug:
    #     print("Merged depgraph depsets:")
    #     print(merged_depgraph_depsets)

    # if we have an input cmi, we will pass it on as Marker output,
    # but it is not an output of this action- do NOT add incoming cmi to action outputs
    ## TODO: support compile of mli source
    # if ctx.attr.sig:
    #     # args.add("-intf", ctx.file.sig)
    #     for f in ctx.attr.sig:
    #         merged_module_links_depsets.append(f[OcamlSignatureMarker].module_links)
    #         merged_archive_links_depsets.append(f[OcamlSignatureMarker].archive_links)
    #         merged_paths_depsets.append(f[OcamlSignatureMarker].paths)
    #         merged_depgraph_depsets.append(f[OcamlSignatureMarker].depgraph)
    #         merged_archived_modules_depsets.append(f[OcamlSignatureMarker].archived_modules)

    # if debug:
    #     print("BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
    #     print(merged_depgraph_depsets)

    if debug:
        print("INCLUDES: %s" % includes)

    ## handle cc deps: 1) add to cmd line; 2) propagate in CcDepsProvider
    # cclib_deps  = []
    # direct_cc_deps    = {}
    # direct_cc_deps.update(ctx.attr.cc_deps)

    # cc_runfiles = []
    # cc_deps_dict = {}
    # cc_deps_dict.update(direct_cc_deps)
    # cc_deps_dict.update(indirect_cc_deps)
    [
        action_inputs_ccdep_filelist, ccDepsProvider
     ] = handle_ccdeps(ctx,
                     # True if ctx.attr.pack else False,
                    tc.linkmode,
                     # cc_deps_dict,
                    args,
                     # includes,
                     # cclib_deps,
                     # cc_runfiles)
                  )
    print("CCDEPS INPUTS: %s" % action_inputs_ccdep_filelist)

    # if "-g" in _options:
    #     args.add("-runtime-variant", "d")
    if ctx.attr.pack:
        args.add("-linkpkg")

    # opam_depset = depset(direct = ctx.attr.deps_opam,
    #                      transitive = indirect_opam_depsets)
    # if using_ocamlfind:
    #     for opam in opam_depset.to_list():
    #         args.add("-package", opam)  ## add dirs to search path

    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []
    # print("TGT: %s" % ctx.label.name)
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[AdjunctDepsMarker]
        # if using_ocamlfind:
        #     for opam in provider.opam.to_list():
        #         args.add("-package", opam)
        # else:
        dlist = provider.nopam.to_list()
        for f in dlist: ## provider.nopam.to_list():
            adjunct_deps.append(f)
            # if OcamlImportArchivesMarker in nopam:
            #     adjuncts = nopam[OcamlImportArchivesMarker].archives
            # for f in adjuncts.to_list():
            if f.extension in ["cmxa"]: ## , "a"]:
                if (f.path.startswith(opam_lib_prefix)):
                    dir = paths.relativize(f.dirname, opam_lib_prefix)
                    includes.append( "+../" + dir )
                else:
                    includes.append(f.dirname)
                args.add(f.path)

        for path in provider.nopam_paths.to_list():
            includes.append(path)
            # args.add("-I", path)

    # print("ADJUNCT_DEPS 2: %s" % adjunct_deps)
    # for adjunct in adjunct_deps:
    #     print("ADJUNCT dep: %s" % adjunct.files)
    #     # print("ADJUNCT short-path: %s" % adjunct.short_path)
    #     for f in adjunct.files.to_list():
    #         print("ADJUNCT f: %s" % f)
    #         if f.extension in ["cmxa", "a"]:
    #             # FIXME: remove hardcoded "external... " stuff
    #             if (f.path.startswith(opam_lib_prefix)):
    #                 dir = paths.relativize(f.dirname, opam_lib_prefix)
    #                 includes.append( "+../" + dir )
    #             else:
    #                 includes.append(f.dirname)

    #         # includes.append(
    #         #     ctx.attr._opam_lib[BuildSettingInfo].value + "/" + dir
    #         # )
    #         # includes.append( adjunct.path )
    #         args.add(f.path)

    # indirect_paths_depset = depset(order = dsorder,
    #                                transitive = merged_paths_depsets)
    # for apath in indirect_paths_depset.to_list():
    #     if (apath.startswith(opam_lib_prefix)):
    #         dir = paths.relativize(apath, opam_lib_prefix)
    #         includes.append( "+../" + dir )
    #     else:
    #         includes.append( apath )

    # module_links_ds = depset(order = dsorder,
    #                          transitive = merged_module_links_depsets)
    # archive_links_ds = depset(order = dsorder,
    #                           transitive = merged_archive_links_depsets)
    # for dep in archive_links_ds.to_list():
        # if dep in ctx.files.deps:
        # if dep.extension != "a":
        #     args.add(dep.basename)

    # mdeps = []
    # mdeps.extend(ctx.attr.deps)
    # mdeps.append(ctx.attr._ns_resolver)
    # mdeps.append(ctx.attr.cc_deps)
    # if ctx.attr.sig:
    #     mdeps.append(ctx.attr.sig)

    # if ctx.file.sig: paths_direct.append(ctx.file.sig.dirname)
    # print("PATHS_DIRECT: %s" % paths_direct)

    paths_indirect = []
    all_deps_list = []
    resolver_dep = None

    # this_archivedeps_archive_file_list = []
    # this_archivedeps_components_depset_list = []
    # this_archivedeps_subdeps_depset_list = []

    # this_module_deps_depset_list = []
    # this_module_subdeps_depset_list = []

    # this_sigdeps_depset_list = []

    ## FIXME: handle deps_deferred

    the_deps = []
    the_deps.extend(ctx.attr.deps) # + [ctx.attr._ns_resolver]
    if ctx.attr.sig:
        the_deps.append(ctx.attr.sig)

    for dep in the_deps:
        # print("MDEP: {host} => {d}".format(host=ctx.label, d = dep.label))

        # all_deps_list.append(dep[DefaultInfo].files)
        ################ OCamlMarker ################
        if OcamlProvider in dep:
            all_deps_list.append(dep[OcamlProvider].files)

            # print("PATHS: %s" % dep[OcamlProvider].paths)
            paths_indirect.append(dep[OcamlProvider].paths)

        ################ Archive Deps ################
        # if OcamlArchiveMarker in dep:
        #     # archive_list = dep[OcamlArchiveMarker].archive
        #     # print("  OAP.archive %s" % archive_list)
        #     # this_archivedeps_archive_file_list.extend(archive_list)
        #     # all_deps_list.append(depset(order = dsorder,
        #     #                             direct=dep[OcamlArchiveMarker].archive,
        #     #                             transitive=[dep[OcamlArchiveMarker].subdeps]))
        #     all_deps_list.append(dep[OcamlArchiveMarker].files)

            # components = dep[OcamlArchiveMarker].components
            # print("  OAP.components %s" % components)
            # this_archivedeps_components_depset_list.append(components)
            # archive already contains components
            # all_deps_list.append(dep[OcamlArchiveMarker].components)

            # subdeps = dep[OcamlArchiveMarker].subdeps
            # print("  OAP.subdeps %s" % subdeps)
            # this_archivedeps_subdeps_depset_list.append(subdeps)
            # all_deps_list.append(dep[OcamlArchiveMarker].subdeps)

        ################ module deps ################
        # if OcamlModuleMarker in dep:
        #     all_deps_list.append(dep[OcamlModuleMarker].files)

        #     sigs = dep[OcamlModuleMarker].sigs
        #     print("  OMP.sigs %s" % sigs)
        #     this_sigdeps_depset_list.append(sigs)

        #     deps = dep[OcamlModuleMarker].deps
        #     print("  OMP.deps %s" % deps)
        #     this_module_deps_depset_list.append(deps)
        #     all_deps_list.append(dep[OcamlModuleMarker].deps)

        #     subdeps = dep[OcamlModuleMarker].subdeps
        #     print("  OMP.subdeps %s" % subdeps)
        #     this_module_subdeps_depset_list.append(subdeps)
            # deps already contains subdeps
            # all_deps_list.append(dep[OcamlModuleMarker].subdeps)

        ################ Paths ################
        # if OcamlPathsMarker in dep:
        #     ps = dep[OcamlPathsMarker].paths
        #     # print("MPATHS: %s" % ps)
        #     paths_indirect.append(ps)


    # this_archivedeps_archives_depset = depset(
    #     order = dsorder,
    #     direct = this_archivedeps_archive_file_list
    # )
    # this_archivedeps_components_depset = depset(
    #     order = dsorder,
    #     transitive = this_archivedeps_components_depset_list
    # )
    # this_archivedeps_subdeps_depset = depset(
    #     order = dsorder,
    #     transitive = this_archivedeps_subdeps_depset_list
    # )

    ################ module deps ################
    # this_module_deps_depset = depset(
    #     order = dsorder,
    #     transitive = this_module_deps_depset_list
    # )
    # print("THIS_module_deps_depset: %s" % this_module_deps_depset)
    # this_module_subdeps_depset = depset(
    #     order = dsorder,
    #     transitive = this_module_subdeps_depset_list
    # )
    # print("THIS_module_subdeps_depset: %s" % this_module_subdeps_depset)

    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = paths_indirect
    )

    # deps may include modules, sigs, and archives
    # above extracted each, now we iterate


    # nb: iterating over ctx.files.deps won't work, it will only
    # enumerate DefaultInfo.files(?)

    args.add_all(paths_depset.to_list(), before_each="-I")

    # print("MOD ALL_DEPS_LIST: %s" % all_deps_list)
    # order should not matter, it's already encoded in depsets
    all_deps = depset(
        order = dsorder,
        ## submods depend on resolver, so keep this order:
        # transitive = [ctx.attr._ns_resolver.files] + all_deps_list
        transitive = all_deps_list
    )

    # print("MOD ALLDEPS: %s" % all_deps)
    # for d in all_deps.to_list():
    #     print(" ADEP: %s" % d)

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
        ## this will only be the case if this is a submodule in an ns
        args.add("-no-alias-deps")
        args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    args.add("-absname")
    # print("ALL_DEPS for MODULE %s" % ctx.label)
    # for d in reversed(all_deps.to_list()):
    for d in all_deps.to_list():
        # print("ALL_DEPS: %s" % d)
        if d.extension not in [
            "cmi", "mli",
            "ml", # provided by _ns_resolver
            "a", "o"
        ]:
            # includes.append("-I", d.dirname)
            args.add(d.path) # d.basename)

    for f in ctx.files._ns_resolver:
        if f.extension == "cmx":
            args.add("-I", f.dirname)
            args.add(f.path)

    args.add("-absname")

    # for f in ctx.files.deps:
    #     print("ctx.files.deps FFFFFFFFFFFFFFFF %s" % f)

    ################################################################
    # for f in archive_links_ds.to_list() + module_links_ds.to_list():
    #     # print("Mod DEP: %s" % f)
    #     if f.extension in ["cmxa", "a"]:
    #         # args.add( f.path )
    #         if (f.path.startswith(opam_lib_prefix)):
    #             dir = paths.relativize(f.dirname, opam_lib_prefix)
    #             includes.append( "+../" + dir )
    #         else:
    #             includes.append( f.dirname )
    #     ## We do not need to put cmx files on cmd line, so long as we
    #     ## add their dirs using -I (?)
    #     if f.extension in ["cmi", "mli"]:
    #         if (f.path.startswith(opam_lib_prefix)):
    #             dir = paths.relativize(f.dirname, opam_lib_prefix)
    #             includes.append( "+../" + dir )
    #         else:
    #             includes.append( f.dirname )

    if ctx.attr.ppx:
        structfile = impl_ppx_transform(ctx.attr._rule, ctx, ctx.file.struct, module_name + ".ml")
    else:
        ## cp src file to working dir (__obazl)
        ## this is necessary(?) for .mli/.cmi resolution to work
        # print("STRUCT: %s" % ctx.file.struct)
        # print("MODULE NM: %s" % module_name + ".ml")
        tmp = capitalize_initial_char(ctx.file.struct.basename)
        if (tmp != module_name + ".ml"):
            structfile = rename_srcfile(ctx, ctx.file.struct, module_name + ".ml")
        else:
            structfile = ctx.file.struct

    if ctx.attr.pack:
        args.add("-for-pack", ctx.attr.pack)

    args.add_all(includes, before_each="-I", uniquify = True)

    # attr '_ns_resolver' a label_flag that resolves to a (fixed)
    # ocaml_ns_resolver target whose params are set by transition fns.
    # by default the 'resolver' field is null.

    # if "-shared" in _options:
    #     args.add("-shared")
    # else:

    args.add_all(_options)

    args.add("-c")
    args.add("-o", out_cm_)

    args.add("-impl", structfile)

    ## if we rec'd a .cmi sigfile, we must add its SOURCE file to the dep graph!
    ## otherwise the ocaml compiler will not use the cmx file, it will generate
    ## one from the module source.
    mli_out = [mlifile] if mlifile else []

    ## runtime deps must be added to the depgraph (so they get built),
    ## but not the command line (they are not build-time deps).
    inputs_depset = depset(
        order = dsorder,
        direct = [structfile]
        + mli_out
        # + cclib_deps
        + ctx.files.deps_runtime,
        transitive = [
            all_deps, depset(ctx.files._ns_resolver),
            depset(action_inputs_ccdep_filelist)
        ]
        # transitive = merged_depgraph_depsets
        # + merged_module_links_depsets
        # + merged_archive_links_depsets
    )
    # print("INPUTS_DEPSET:")
    # for dep in inputs_depset.to_list():
    #     print(" DEP: %s" % dep)


        # NB: these are NOT in the depgraph: cc_direct_depfiles + adjunct_deps + ctx.files.ppx,
        # Why not? cc deps need only be built for executable targets
        # adjunct deps are not needed to build this target
        # ppx has already been used above to transform source, not needed to build transformed source

    ################
    ctx.actions.run(
        env = env,
        executable = exe, ## tc.ocamlfind,
        arguments = [args],
        inputs    = inputs_depset,
        outputs   = action_outputs,
        tools = [tc.ocamlopt, tc.ocamlc], #tc.ocamlfind, 
        mnemonic = "CompileOCamlModule" if ctx.attr._rule == "ocaml_module" else "CompilePpxModule",
        progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
            mode = mode,
            rule=ctx.attr._rule,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )
    ################
    ################

    default_depset = depset(
        order = dsorder,
        direct = rule_outputs # + [out_cmi] + mli_out,
        # transitive = merged_module_links_depsets
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    # sigs_depset = depset(
    #     order = dsorder,
    #     direct = [out_cmi] + mli_out,
    #     transitive = this_sigdeps_depset_list
    # )
    # # print("INCLUDES: %s" % includes)
    # module_links_depset = depset(
    #     order = dsorder,
    #     direct = rule_outputs, # + [out_cm_],
    #     # ppx? direct = [out_cm_],
    #     transitive = merged_module_links_depsets
    # )
    # archive_links_ds = depset(
    #     order = dsorder,
    #     transitive = merged_archive_links_depsets
    # )
    # paths_depset = depset(
    #     order = dsorder,
    #     direct = includes + [out_cm_.dirname], ## depset will uniquify includes
    #     transitive = merged_paths_depsets
    # )
    # depgraph = depset(
    #     order = dsorder,
    #     direct = rule_outputs + [structfile, out_cmi] + mli_out,
    #     # + adjunct_deps,
    #             transitive = merged_depgraph_depsets
    # )
    # archived_modules = depset(
    #     order = dsorder,
    #     transitive = merged_archived_modules_depsets
    # )

    # ocamlPathsMarker = OcamlPathsMarker(
    #     paths = depset
    #     # paths  = depset(
    #     #     order = dsorder,
    #     #     direct = paths_direct,
    #     #     transitive = paths_indirect)
    # )
    # print("MPATHSPATHS: %s " % ocamlPathsMarker)

    # if (ctx.attr._rule == "ocaml_module"):
    #     moduleMarker = OcamlModuleMarker(
    #         files = depset(
    #             direct = rule_outputs,
    #             transitive = all_deps_list
    #         ),
    #         sigs = sigs_depset,
    #         deps = depset(
    #             order = dsorder,
    #             direct = rule_outputs, #  + [out_cmi] + mli_out,
    #             transitive = this_module_deps_depset_list
    #             + [this_archivedeps_archives_depset]
    #             + [this_archivedeps_subdeps_depset]
    #         ),
    #         subdeps = depset(
    #             order = dsorder,
    #             transitive = this_module_subdeps_depset_list
    #             + this_archivedeps_subdeps_depset_list
    #         ),
    #         module_links = module_links_depset,
    #         archive_links = archive_links_ds,
    #         paths = paths_depset,
    #         depgraph = depgraph,
    #         archived_modules = archived_modules
    #     )
    # elif ctx.attr._rule == "ppx_module":
    #     moduleMarker = PpxModuleMarker(
    #         deps = depset(
    #             order = dsorder,
    #             direct = default_outputs,
    #             # direct = default_depset,
    #             transitive = [this_module_deps_depset]
    #         ),
    #         subdeps = depset(
    #             order = dsorder,
    #             transitive = [this_module_subdeps_depset]
    #         ),
    #         module_links = module_links_depset,
    #         archive_links = archive_links_ds,
    #         paths    = depset(
    #             order = dsorder,
    #             direct = includes + [out_cm_.dirname], ## depset will uniquify includes
    #             transitive = merged_paths_depsets
    #         ),
    #         depgraph = depset(
    #             order = dsorder,
    #             direct = rule_outputs + [structfile, out_cmi] + mli_out,
    #             # + adjunct_deps,
    #             transitive = merged_depgraph_depsets
    #         ),
    #         archived_modules = depset(
    #             order = dsorder,
    #             transitive = merged_archived_modules_depsets
    #         ),
    #     )

    ## pass on adjunct deps rec'd from deps of this module
    ## do we need to do this?
    ppx_adjuncts_depset = depset(
        order = dsorder,
        direct = adjunct_deps,
        transitive = indirect_adjunct_depsets
    )

    adjunctsMarker = AdjunctDepsMarker(
        nopam       = ppx_adjuncts_depset,
        nopam_paths = depset(order = dsorder,
                             transitive = indirect_adjunct_path_depsets)
    )

    ## FIXME: catch incompatible key dups
    # cclibs = {}
    # cclibs.update(ctx.attr.cc_deps)
    # if len(indirect_cc_deps) > 0:
    #     cclibs.update(indirect_cc_deps)
    # ccDepsProvider = CcDepsProvider(
    #     ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
    #     libs = cclibs
    # )
    # cclib_files = []
    # for tgt in cclibs.keys():
    #     cclib_files.extend(tgt.files.to_list())
    # # order: preorder?
    # cclib_files_depset = depset(cclib_files)

    ocamlProviderDepset = depset(
        order  = dsorder,
        direct = rule_outputs, # + [out_cmi] + mli_out,
        transitive = [all_deps]
    )
    # print("ACTION_OUPUTS: %s" % action_outputs)

    ocamlProvider = OcamlProvider(
        files = ocamlProviderDepset,
        paths = paths_depset
    )
    # print("EXPORTING OcamlProvider files: %s" % ocamlProvider)
    # for f in ocamlProvider.files.to_list():
    #     print("DX: %s" % f)

    nsResolverProvider = OcamlNsResolverProvider(
        files = ctx.attr._ns_resolver.files,
        paths = depset([d.dirname for d in ctx.attr._ns_resolver.files.to_list()])
    )
    # print("EXPORTING OcamlNsResolverProvider files:")
    # for f in nsResolverProvider.files.to_list():
    #     print("RX: %s" % f)
    # print("EXPORTING OcamlNsResolverProvider paths:")
    # for f in nsResolverProvider.paths.to_list():
    #     print("PATHX: %s" % f)

    # print("EXPORTING OcamlProvider paths:")
    # for f in ocamlProvider.paths.to_list():
    #     print("PX: %s" % f)

    # print("LBL: %s" % ctx.label)
    # print("XMODULE_PROVIDER %s" % moduleMarker)
    outputGroupInfo = OutputGroupInfo(
        # modules  = module_links_depset,
        # sigs     = sigs_depset,
        # archives = archive_links_ds,
        # depgraph = depgraph,
        # archived_modules = archived_modules,
        ppx_adjuncts = ppx_adjuncts_depset,
        cc = action_inputs_ccdep_filelist,
        all = depset(
            order = dsorder,
            transitive=[
                default_depset,
                ocamlProviderDepset,
                # ppx_adjuncts_depset,
                # cclib_files_depset,
                depset(action_inputs_ccdep_filelist)
            ]
        )
    )

    if (ctx.attr._rule == "ocaml_module"):
        moduleMarker = OcamlModuleMarker(marker="OcamlModule")
    else:
        moduleMarker = PpxModuleMarker(marker="PpxModule")

    providers = [
        defaultInfo,
        moduleMarker,
        ocamlProvider,
        nsResolverProvider,
        outputGroupInfo,
        # moduleMarker,
        # ocamlPathsMarker,
        adjunctsMarker,
        ccDepsProvider
    ]

    return providers
