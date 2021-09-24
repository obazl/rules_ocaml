load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlCcInfo",
     "OcamlArchiveProvider",
     "CompilationModeSettingProvider",

     "PpxAdjunctsProvider",
     "CcDepsProvider",
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
     "get_sdkpath",
)
load("//ocaml/_functions:module_naming.bzl",
     "file_to_lib_name",
     "normalize_module_name")

load(":impl_ccdeps.bzl", "handle_ccdeps", "link_ccdeps", "dump_ccdep")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir"
     )

scope = tmpdir

#####################
def impl_module(ctx):

    debug = False

    print("++ MODULE {}".format(ctx.label))

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

    env = {
        "PATH": get_sdkpath(ctx),
    }

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    if mode == "native":
        exe = tc.ocamlopt.basename
    else:
        exe = tc.ocamlc.basename

    ext  = ".cmx" if  mode == "native" else ".cmo"

    ################
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_cc_deps  = {}

    ################
    includes   = []
    default_outputs   = []
    action_outputs   = []
    direct_linkargs = []
    out_cmi = None

    ## module name is derived from sigfile name, so start with sig
    # if we have an input cmi, we will pass it on as Provider output,
    # but it is not an output of this action- do NOT add incoming cmi to action outputs
    ## TODO: support compile of mli source
    module_name = None
    mlifile = None
    if ctx.attr.sig:
        print("SIG_%s" % ctx.label.name)

        # derive module name from sigfile
        # for submodules, sigfile name will already contain ns prefix
        sigProvider = ctx.attr.sig[OcamlSignatureProvider]
        out_cmi = sigProvider.cmi
        # direct_linkargs.append(out_cmi)
        mlifile = sigProvider.mli
        # direct_linkargs.append(mlifile)
        # print("OUT CMI: %s" % out_cmi)
        module_name = out_cmi.basename[:-4]
        print("Mnmsig: %s" % module_name)
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

        print("Mnm {src} => {dst}".format(src=from_name, dst=module_name))

        # and declare cmi output, since ocaml will generate it
        out_cmi = ctx.actions.declare_file(scope + module_name + ".cmi")
        action_outputs.append(out_cmi)
        # direct_linkargs.append(out_cmi)

    out_cm_ = ctx.actions.declare_file(scope + module_name + ext) # fname)
    action_outputs.append(out_cm_)
    direct_linkargs.append(out_cm_)
    default_outputs.append(out_cm_)

    if mode == "native":
        out_o = ctx.actions.declare_file(scope + module_name + ".o")
        action_outputs.append(out_o)
        direct_linkargs.append(out_o)
    # print("ACTION_OUTPUTS: %s" % action_outputs)

    paths_direct = [d.dirname for d in direct_linkargs]
    if ctx.files._ns_resolver:
        paths_direct.extend([f.dirname for f in ctx.files._ns_resolver])
    # print("PATHS_DIRECT: %s" % paths_direct)

    if ctx.attr.ppx:
        # module_name was derived above. ppx xform does not change it.
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

    #########################
    args = ctx.actions.args()

    _options = get_options(ctx.attr._rule, ctx)
    # if "-for-pack" in _options:
    #     for_pack = True
    #     _options.remove("-for-pack")
    # else:
    #     for_pack = False

    # if ctx.attr.pack:
    #     args.add("-for-pack", ctx.attr.pack)

    args.add_all(_options)

    ## FIXME: support -bin-annot
    # if "-bin-annot" in _options: ## Issue #17
    #     out_cmt = ctx.actions.declare_file(scope + paths.replace_extension(module_name, ".cmt"))
    #     action_outputs.append(out_cmt)

    if debug:
        print("INCLUDES: %s" % includes)

    # [
    #     action_inputs_ccdep_filelist, ccDepsProvider
    #  ] = handle_ccdeps(ctx,
    #                  # True if ctx.attr.pack else False,
    #                 tc.linkmode,
    #                  # cc_deps_dict,
    #                 args,
    #                  # includes,
    #                  # cclib_deps,
    #                  # cc_runfiles)
    #               )
    # print("CCDEPS INPUTS: %s" % action_inputs_ccdep_filelist)

    # link_ccdeps(ctx, args)

    # if "-g" in _options:
    #     args.add("-runtime-variant", "d")
    # if ctx.attr.pack:
    #     args.add("-linkpkg")

    paths_indirect = []
    all_deps_list = []
    direct_deps_list = []
    archive_deps_list = []
    archive_inputs_list = [] # not for command line!
    resolver_dep = None

    input_deps_list = []

    ## FIXME: handle deps_deferred

    ################ Direct Deps ################
    the_deps = []
    the_deps.extend(ctx.attr.deps) # + [ctx.attr._ns_resolver]
    # print("THE_DEPS: %s" % the_deps)

    #### INDIRECT DEPS first ####
    # these are "indirect" from the perspective of the consumer
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    ccInfo_list = []

    for dep in the_deps:
        # print("MDEP: %s" % dep)

        if CcInfo in dep:
            dump_ccdep(ctx, dep)
            ## we do not need to do anything with ccdeps here,
            ## just pass them on in a provider
            ccInfo_list.append(dep[CcInfo])
            # handle_ccinfo_dep(ctx, dep, ccdeps_list,)

        if OcamlProvider in dep:
            # ignore DefaultInfo, its just for printing, not propagation
            indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
            indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
            indirect_paths_depsets.append(dep[OcamlProvider].paths)

            input_deps_list.append(dep[OcamlProvider].files)
            direct_deps_list.append(dep[DefaultInfo].files)

            if OcamlSignatureProvider in dep:
                # ocaml_signature produces .cmi in DefaultInfo, which we
                # do not want on the cmd line, so we do not put it in
                # direct_deps_list. It will also be in OcamlProvider.files
                # direct_deps_list.append(dep[DefaultInfo].files)
                _ = 1 # nop: just avoid appending to direct_deps_list

            ################ OCamlProvider ################
            if OcamlProvider in dep:
                # print("PPPProv: %s" % dep[OcamlProvider])
                # input_deps_list.append(dep[OcamlProvider].files)
                if dep[OcamlProvider].archives:
                    # print("AAAARCHIVES %s" % dep[OcamlProvider].archives)
                    archive_deps_list.append(dep[OcamlProvider].archives)
                if dep[OcamlProvider].archive_deps:
                    archive_inputs_list.append(dep[OcamlProvider].archive_deps)
                paths_indirect.append(dep[OcamlProvider].paths)

            ################ OCamlArchiveProvider ################
            ## only produced by ocaml_*_archive, _import
            if OcamlArchiveProvider in dep:
                archive_deps_list.append(dep[OcamlArchiveProvider].files)
            ## the rest should be cmx modules only
            ## BUT: if ocaml_ns_archive is direct dep it delivers cmxa in default

            all_deps_list.append(dep[DefaultInfo].files)

    ################ Signature Dep ################
    if ctx.attr.sig:
        dep = ctx.attr.sig

        # ignore DefaultInfo, its just for printing, not propagation
        indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
        indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        indirect_paths_depsets.append(dep[OcamlProvider].paths)

        ####
        input_deps_list.append(dep[OcamlProvider].files)
        direct_deps_list.append(dep[DefaultInfo].files)

        if OcamlProvider in dep:
            # print("PPPProv: %s" % dep[OcamlProvider])
            all_deps_list.append(dep[OcamlProvider].files)
            if dep[OcamlProvider].archives:
                # print("AAAARCHIVES %s" % dep[OcamlProvider].archives)
                archive_deps_list.append(dep[OcamlProvider].archives)
            if dep[OcamlProvider].archive_deps:
                archive_inputs_list.append(dep[OcamlProvider].archive_deps)
            paths_indirect.append(dep[OcamlProvider].paths)

        ################ OCamlArchiveProvider ################
        ## only produced by ocaml_*_archive, _import
        if OcamlArchiveProvider in dep:
            archive_deps_list.append(dep[OcamlArchiveProvider].files)
        ## the rest should be cmx modules only
        ## BUT: if ocaml_ns_archive is direct dep it delivers cmxa in default

    # print("MTHE_DEPS: %s" % the_deps)

    ################ PPX Adjunct Deps ################
    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []
    # print("TGT: %s" % ctx.label.name)
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[PpxAdjunctsProvider]

        ## NB: it seems to be sufficient to put the ppx_adjunct in the
        ## search path with -I; the archive itself need not be added?
        ## omitting the path: e.g. "Unbound module Ppx_inline_test_lib"
        ## adding the path makes the compile work.
        ## BUT: the ppx_adjunct must be propagated to
        ## ocaml_executable, otherwise the link will fail with:
        ## "No implementations provided for the following modules:..."
        dlist = provider.ppx_adjuncts.to_list()
        args.add("-ccopt", "-DPPX_ADJUNCTS_START")
        for f in dlist: ## provider.files.to_list():
            adjunct_deps.append(f)
            # if OcamlImportArchivesMarker in files:
            #     adjuncts = files[OcamlImportArchivesMarker].archives
            # for f in adjuncts.to_list():
            if f.extension in ["cmxa", "a"]:
                if (f.path.startswith(opam_lib_prefix)):
                    dir = paths.relativize(f.dirname, opam_lib_prefix)
                    includes.append( "+../" + dir )
                else:
                    includes.append(f.dirname)
                # if f.extension in ["cmxa", "cmx"]:
                #     args.add(f.path)
        args.add("-ccopt", "-DPPX_ADJUNCTS_END")

        for path in provider.paths.to_list():
            includes.append(path)
            # args.add("-I", path)

    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = indirect_paths_depsets
        # transitive = paths_indirect
    )

    args.add_all(paths_depset.to_list(), before_each="-I")

    all_deps = depset(
        order = dsorder,
        transitive = all_deps_list
    )

    if archive_deps_list:
        archives_depset = depset(transitive = archive_deps_list)
        # args.add("-ccopt", "-DARCHIVE_DEPS_START")
        # for d in archives_depset.to_list():
        #     if d.extension not in ["a"]:
        #         args.add(d.path)
        # args.add("-ccopt", "-DARCHIVE_DEPS_END")
    else:
        archives_depset = False

    archive_inputs_depset = depset(transitive = archive_inputs_list)

    # if direct_deps_list:
    #     direct_deps = depset(transitive=direct_deps_list)
    #     args.add("-ccopt", "-DDIRECT_DEPS_START")
    #     for dep in direct_deps.to_list():
    #         ## DefaultInfo contains some stuff we do not want in cmd:
    #         ## cmxa (direct ocaml_ns_archive dep)
    #         ## cmi (direct ocaml_signature dep)
    #         if dep.extension not in ["cmxa", "a", "o", "cmi", "mli"]:
    #             args.add(dep)
    #     args.add("-ccopt", "-DDIRECT_DEPS_END")

    # print("LINKARGS indirect: %s" % indirect_linkargs_depsets)
    _linkargs_depset = depset(
        transitive = indirect_linkargs_depsets
    )
    # print("LINKARGS _depset: %s" % _linkargs_depset)

    args.add("-ccopt", "-DLINKARGS_START")
    # for dep in _linkargs_depset.to_list():
    #     ## DefaultInfo contains some stuff we do not want in cmd:
    #     ## cmxa (direct ocaml_ns_archive dep)
    #     ## cmi (direct ocaml_signature dep)

    # ## FIXME: filter these out at the start, so we don't need to do so here
    #     if dep.extension not in ["a", "o", "cmi", "mli"]:
    #         args.add(dep)
    args.add("-ccopt", "-DLINKARGS_END")

    ## now add this output
    # print("LINKARGS direct: %s" % direct_linkargs)

    linkargs_depset = depset(
        direct = direct_linkargs,
        transitive = [_linkargs_depset]
    )

    # link_args = []
    # for f in all_deps.to_list():
    #     if f.extension not in [
    #         "cmi", "mli",
    #         "ml", # from _ns_resolver
    #         # "cmxa",
    #         "a", "o"
    #     ]:
    #         link_args.append(f.path) # paths already in paths depset?

    # args.add_all(link_args)

    # args.add("-ccopt", "-DNS_RESOLVER_START")
    # for f in ctx.files._ns_resolver:
    #     if f.extension == "cmx":
    #         # args.add("-I", f.dirname)
    #         args.add(f.path)
    # args.add("-ccopt", "-DNS_RESOLVER_END")

    # _ns_resolver has out transition, forcing a list:
    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
        ## this will only be the case if this is a submodule in an ns
        args.add("-no-alias-deps")
        args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    args.add_all(includes, before_each="-I", uniquify = True)

    # attr '_ns_resolver' a label_flag that resolves to a (fixed)
    # ocaml_ns_resolver target whose params are set by transition fns.
    # by default the 'resolver' field is null.

    # if "-shared" in _options:
    #     args.add("-shared")
    # else:

    ## if we rec'd a .cmi sigfile, we must add its SOURCE file to the dep graph!
    ## otherwise the ocaml compiler will not use the cmx file, it will generate
    ## one from the module source.
    mli_out = [mlifile] if mlifile else []

    ## runtime deps must be added to the depgraph (so they get built),
    ## but not the command line (they are not build-time deps).

    # print("RESOLVER DEPS:")
    # for resolv in ctx.files._ns_resolver:
    #     print(" RESOLV: %s" % resolv)

    # print("IN_ALL_DEPS for MODULE %s" % ctx.label)
    # # for d in reversed(all_deps.to_list()):
    # for d in all_deps.to_list():
    #     print(" ADEPS: {d} mod: {m}".format(d=d, m = ctx.label))

    # print("MINPUTS ALL_DEPS: %s" % all_deps)
    # print("MINPUTS structfile: %s" % structfile)
    # print("MINPUTS mli_out: %s" % mli_out)
    # print("MINPUTS ns_resolver: %s" % ctx.files._ns_resolver)
    # print("MINPUTS indirect_inputs_depsets: %s" % indirect_inputs_depsets)
    inputs_depset = depset(
        order = dsorder,
        direct = [structfile]
        + mli_out
        + ctx.files.deps_runtime
        + ctx.files._ns_resolver,
        # transitive = input_deps_list
        transitive = indirect_inputs_depsets
        ## + [depset(action_inputs_ccdep_filelist)]
    )
    # inputs_depset = depset(
    #     order = dsorder,
    #     direct = [structfile]
    #     + mli_out
    #     # + cclib_deps
    #     + ctx.files.deps_runtime
    #     + ctx.files._ns_resolver,
    #     transitive = [
    #         # (archives_depset if archives_depset else depset()),
    #         archive_inputs_depset,
    #         depset(action_inputs_ccdep_filelist)
    #     ] + input_deps_list + [archives_depset] + [all_deps]
    # )

    # print("MODULE {m} INPUTS_DEPSET: {ds}".format(
    #     m=ctx.label, ds=inputs_depset))

    # for dep in inputs_depset.to_list():
    #     if dep.extension not in ["cmi", "mli", "ml"]:
    #         args.add(dep)

    args.add("-c")
    args.add("-o", out_cm_)

    args.add("-impl", structfile)

    #     print(" MODDEP: {d}    || MOD: {m}".format(d=dep.path, m = ctx.label.name))

        # NB: these are NOT in the depgraph: cc_direct_depfiles + adjunct_deps + ctx.files.ppx,
        # Why not? cc deps need only be built for executable targets
        # adjunct deps are not needed to build this target
        # ppx has already been used above to transform source, not needed to build transformed source

    ################
    ctx.actions.run(
        env = env,
        executable = exe,
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
        direct = action_outputs, # + [out_cmi] + mli_out,
        # transitive = input_deps_list
        # transitive = [dep[DefaultInfo].files for dep in ctx.attr.deps]
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    ## pass on adjunct deps rec'd from deps of this module
    ## do we need to do this?
    ppx_adjuncts_depset = depset(
        order = dsorder,
        direct = adjunct_deps,
        transitive = indirect_adjunct_depsets
    )

    adjunctsMarker = PpxAdjunctsProvider(
        ppx_adjuncts = ppx_adjuncts_depset,
        paths = depset(order = dsorder,
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

    ocamlProvider_files_depset = depset(
        order  = dsorder,
        direct = action_outputs, # + [out_cmi] + mli_out,
        transitive = input_deps_list

        # transitive = [all_deps]
        # depset(direct_linkargs),
    )
    # print("ACTION_OUPUTS: %s" % action_outputs)

    new_inputs_depset = depset(
        direct = action_outputs,
        transitive = indirect_inputs_depsets
    )
    # paths_depset = depset(
    #     direct = direct_paths_list,
    #     transitive = indirect_paths_depsets
    # )

    ocamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,

        files = ocamlProvider_files_depset,
        archives = archives_depset if archives_depset else False,
        archive_deps = archive_inputs_depset if archive_inputs_depset else False,
    )
    # print("EXPORTING OcamlProvider files: %s" % ocamlProvider)

    nsResolverProvider = OcamlNsResolverProvider(
        files = ctx.attr._ns_resolver.files,
        paths = depset([d.dirname for d in ctx.attr._ns_resolver.files.to_list()])
    )

    ################################################################
    outputGroupInfo = OutputGroupInfo(
        archives = archives_depset if archives_depset else depset(),
        archive_deps = archive_inputs_depset if archive_inputs_depset else depset(),
        ppx_adjuncts = ppx_adjuncts_depset,
        # cc = action_inputs_ccdep_filelist,
        inputs = inputs_depset,
        all = depset(
            order = dsorder,
            transitive=[
                default_depset,
                ocamlProvider_files_depset,
                archives_depset if archives_depset else depset(),
                archive_inputs_depset if archive_inputs_depset else depset(),
                ppx_adjuncts_depset,
                # cclib_files_depset,
                # depset(ccDepsProvider.ccdeps_map.keys()),
                # depset(action_inputs_ccdep_filelist)
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
        # archiveProvider,
        nsResolverProvider,
        outputGroupInfo,
        # moduleMarker,
        # ocamlPathsMarker,
        adjunctsMarker,
        # ccDepsProvider
    ]
    ## now merge ccInfo list
    ## example: https://github.com/bazelbuild/bazel/blob/master/src/main/starlark/builtins_bzl/common/cc/cc_import.bzl

    if ccInfo_list:
        ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        if ctx.label.name == "rustzcash_ctypes_stubs":
            print("CC deps for %s" % ctx.label.name)
            [action_inputs_ccdep_filelist, cc_runfiles
             ] = link_ccdeps(ctx, tc.linkmode, ccInfo, args)
            for f in action_inputs_ccdep_filelist:
                print("ccInfo f: %s" % f.path)

        providers.append(ccInfo )

    return providers
