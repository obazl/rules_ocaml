load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",

     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider",
     "OcamlNsSubmoduleMarker",
     "OcamlSignatureProvider")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
     "PpxModuleMarker",
)

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     # "get_sdkpath",
)

load("//ocaml/_functions:module_naming.bzl",
     "file_to_lib_name",
     "module_name_from_label",
     "normalize_module_name")

load(":impl_ccdeps.bzl",
     "filter_ccinfo"
     # "extract_cclibs", "dump_CcInfo",
     )

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir"
     )

load("@rules_ocaml//ocaml/_debug:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCMAG", "CCCYAN", "CCRESET")

scope = tmpdir

################
def _handle_ns_deps(ctx):
    debug    = False
    debug_ns = False

    if debug: print("_handle_ns_deps ****************")

    ## renaming and ppx already handled we need: ns name for '-open
    ## <nsname>', deps for action inputs and target outputs.

    ## the resolver will be in one of two places:
    ##   ctx.attr._ns_resolver (topdown) default "@rules_ocaml//cfg/ns:resolver", or
    ##   ctx.attr.ns_resolver  (bottomup) - defaults to None

    ## _ns_resolver is always present since it has a default value

    ns_enabled = False
    nsrp       = None  # OcamlNsResolverProvider
    nsop       = None  # ns resolver OcamlProvider
    ns_name    = None

    if ctx.attr.ns_resolver:
        if debug_ns: print("has ns_resolver")
        if debug_ns: print("BOTTOMUP NS")
        ns_enabled = True
        ## topdown (hidden) resolver (nsrp: ns resolver provider)
        nsrp = ctx.attr.ns_resolver[OcamlNsResolverProvider]
        nsop = ctx.attr.ns_resolver[OcamlProvider]
        # print("_NS_RESOLVER: %s" % nsrp)
        if hasattr(nsrp, "ns_name"):
            ns_name = nsrp.ns_name
            if debug_ns:
                print("TOP DOWN ns name: %s" % ns_name)

    elif ctx.attr._ns_resolver:
        if debug_ns: print("has _ns_resolver")
        nsrp = ctx.attr._ns_resolver[OcamlNsResolverProvider]
        nsop = ctx.attr._ns_resolver[OcamlProvider]
        if nsrp.ns_name:
            ns_name = nsrp.ns_name
            if debug_ns: print("TOPDOWN, ns name: %s" % ns_name)
            ns_enabled = True
        else:
            if debug_ns: print("NOT NAMEPACED - exiting _handle_ns_deps")
            return None

    ## DEPS
    ## default (hidden) ns resolvers have no deps
    ## however a user-defined resolver may have deps. sigh.
    ## so we need all six dep classes: sig, struct, ofile, archive, etc.
    ns_cmi    = None
    ns_struct = None
    ns_ofile  = None

    sigs_secondary = []
    structs_secondary = []
    ofiles_secondary = []
    astructs_secondary = []
    afiles_secondary = []
    archives_secondary = []
    paths_secondary = []

    if debug_ns:
        print("collecting ns deps from nsrp:")
        print("nsrp: %s" % nsrp)
        print("nsop: %s" % nsop)

    resolver_cmi    = nsrp.cmi
    resolver_struct = nsrp.struct
    resolver_ofile  = nsrp.ofile
    sigs_secondary.append(nsop.sigs)
    structs_secondary.append(nsop.structs)
    ofiles_secondary.append(nsop.ofiles)
    archives_secondary.append(nsop.archives)
    afiles_secondary.append(nsop.afiles)
    astructs_secondary.append(nsop.astructs)
    paths_secondary.append(nsop.paths)

    if debug_ns: print("**************** exiting _handle_ns_deps")
    # fail("nsrp")

    return (ns_enabled, ns_name,
            resolver_cmi, resolver_struct, resolver_ofile,
            sigs_secondary, structs_secondary, ofiles_secondary,
            archives_secondary, afiles_secondary, astructs_secondary,
            paths_secondary,
            nsrp.submodules)

################
def _handle_precompiled_sig(ctx, modname, ext):

    debug      = False
    debug_deps = False
    debug_ppx  = False
    debug_ns   = False

    sigProvider = ctx.attr.sig[OcamlSignatureProvider]
    # cmifile = sigProvider.cmi
    # cmi_workfile = cmifile
    # old_cmi = [cmifile]
    # mlifile = sigProvider.mli
    # mli_workfile = mlifile
    xmo = sigProvider.xmo

    if debug:
        print("cmifile: %s" % sigProvider.cmi)
        print("mlifile: %s" % sigProvider.mli)

    ## we have three Bazel packages, which may be different:
    ## target pkg: the pkg containing this ocaml_module target
    ## sig pkg:    pkg containing the `sig` dep target
    ## struct pkg: pkg containing the `struct` dep target

    ## we need ensure all compile inputs are in <target>/__obazl

    ## for cmi deps, only symlink sigfiles if sigfile dir
    ## different than the target dir

    tgt_short_path_dir = ctx.label.package
    if paths.basename(tgt_short_path_dir) + "/" == scope:
        tgt_pkgdir = paths.dirname(tgt_short_path_dir)
    else:
        tgt_pkgdir = tgt_short_path_dir

    sig_short_path = sigProvider.mli.short_path
    sig_short_path_dir = paths.dirname(sig_short_path)
    if paths.basename(sig_short_path_dir) + "/" == scope:
        sig_pkgdir = paths.dirname(sig_short_path_dir)
    else:
        sig_pkgdir = sig_short_path_dir

    struct_short_path = ctx.file.struct.short_path
    struct_short_path_dir = paths.dirname(struct_short_path)
    if paths.basename(struct_short_path_dir) + "/" == scope:
        struct_pkgdir = paths.dirname(struct_short_path_dir)
    else:
        struct_pkgdir = struct_short_path_dir

    if debug:
        print("tgt_pkgdir: %s" % tgt_pkgdir)
        print("struct_pkgdir: %s" % struct_pkgdir)
        print("sig_pkgdir: %s" % sig_pkgdir)

    # if struct_pkgdir == sig_pkgdir:
    if tgt_pkgdir == sig_pkgdir:
        ## already in same dir
        if debug: print("NOT SYMLINKING mli/cmi")
        work_mli = sigProvider.mli
        work_cmi = sigProvider.cmi
    else:
        if debug: print("SYMLINKING mli/cmi")
        work_mli = ctx.actions.declare_file(
            scope + sigProvider.mli.basename
        )
        ctx.actions.symlink(output = work_mli, target_file = sigProvider.mli)
        work_cmi = ctx.actions.declare_file(
            scope + sigProvider.cmi.basename
        )
        ctx.actions.symlink(output = work_cmi, target_file = sigProvider.cmi)

    if ctx.attr.ppx:
        if debug_ppx: print("ppxing sig:")
        work_ml = impl_ppx_transform(
            ctx.attr._rule, ctx,
            ctx.file.struct, modname + ".ml"
        )
    else:
        if debug_ppx: print("no ppx")
        work_ml = ctx.actions.declare_file(
            # scope + ctx.file.struct.basename
            scope + modname + ".ml"
        )
        ctx.actions.symlink(output = work_ml, target_file = ctx.file.struct)

    work_struct = ctx.actions.declare_file(
        scope + modname + ext
    )
    ## no symlink, cmox output by compile action

    return(work_ml, work_struct,
           work_mli, work_cmi,
           xmo)

########################
def _handle_source_sig(ctx, modname, ext):
    # we always link ml/mli/cmi under modname to workdir
    # so we return (work_ml, work_mli, work_cmi)
    # all are symlinked, to be listed as compile action inputs,
    # none as compile action outputs

    debug = False
    if debug: print("_handle_source_sig")

    # xmo = True  # convention, no -opaque

    if debug: print("sigattr is src: %s" % ctx.file.sig)

    work_mli = ctx.actions.declare_file(
        scope + modname + ".mli"
    )
    ctx.actions.symlink(output = work_mli, target_file = ctx.file.sig)

    work_cmi = ctx.actions.declare_file(
        scope + modname + ".cmi"
    )
    # no symlink, will be output of compile action

    work_ml = ctx.actions.declare_file(
        scope + modname + ".ml"
    )
    ctx.actions.symlink(output = work_ml, target_file = ctx.file.struct)

    out_struct = ctx.actions.declare_file(
        scope + modname + ext
    )
    ## no symlink, cmox output by compile action

    return(work_ml, out_struct,
           work_mli, work_cmi,
           False) # xmo determined by opt

########################
def _resolve_modname(ctx):
    debug = False

    if debug: print("_resolve_modname")


    # if ctx.label.name[:1] == "@":
    # if ctx.attr.forcename: ## FIXME: ctx.attr.module, name string

    ## 'module' attrib overrides module name
    if ctx.attr.module:
        if ctx.attr.sig:
            if OcamlSignatureProvider in ctx.attr.sig:
                fail("Cannot force module name if sig attr is cmi file")
        if debug: print("Forcing module name to %s" % ctx.attr.module)
        basename = ctx.attr.module
        return basename[:1].capitalize() + basename[1:]
        # return ctx.label.name[1:]

    if ctx.attr.sig:
        # name of cmi always determines modname
        if OcamlSignatureProvider in ctx.attr.sig:
            (from_name, module_name) = get_module_name(ctx, ctx.file.sig)
            return module_name

        (from_name, sig_modname) = get_module_name(ctx, ctx.file.sig)
        # print("sig modname: %s" % sig_modname)
        (from_name, struct_modname) = get_module_name(ctx, ctx.file.struct)
        # print("struct modname: %s" % struct_modname)

        if sig_modname == struct_modname:
            return sig_modname
        else:
            return module_name_from_label(ctx.label)

    else:
        (from_name, struct_modname) = get_module_name(ctx, ctx.file.struct)
        return struct_modname

#####################
def impl_module(ctx): ## , mode, tool, tool_args):

    debug        = False
    debug_ccdeps = False
    debug_deps   = False
    debug_ns     = False
    debug_ppx    = False
    debug_sig    = False
    debug_tc     = False
    debug_xmo    = False

    if debug:
        print("===============================")
        print("OCAML_MODULE: %s" % ctx.label)

    # print("host_platform frag: %s" % ctx.fragments.platform.host_platform)
    # print("platform frag: %s" % ctx.fragments.platform.platform)
    ## both: => @local_config_platform//:host
    ## which references @local_config_platform//:constraints.bzl:
    ## which contains


    ## OUTPUTS: in addition to the std .cmo/.cmx, .o outputs, some
    ## options entail additional outputs:
    ##  -bin-annot:  <src>.cmt, <src.cmti>
    ##  -annot:  <src>.annot (deprecated in favor or -bin-annot)
    ##  -dtype: same as -annot
    ##  -save-ir-after {scheduling}:  .cmir-linear files
    ##  -inlining-report: `.<round>.inlining` files
    ##  -S: keep intermediate assembly file <src>.s
    ##  -dump-into-file: "dump output like -dlambda into <target>.dump"
    ##  -args:  file containing cmd line args (newline-terminated)
    ##  -args0: file containing cmd line args (null-terminated)

    ## bytecode mode: -make-runtime: build runtime system (output?)

    if hasattr(ctx.attr, "ppx_tags"):
        if len(ctx.attr.ppx_tags) > 1:
            fail("Only one ppx_tag allowed currently.")

    # env = {"PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    ext  = ".cmo" if  tc.target == "vm" else ".cmx"

    # if tc.target == "vm":
    #     struct_extensions = ["cma", "cmo"]
    # else:
    #     struct_extensions = ["cmxa", "cmx"]

    ################
    includes   = []
    target_outputs    = [] # just the cmx/cmo files, for DefaultInfo
    action_outputs   = [] # .cmx, .cmi, .o
    # target outputs excludes .cmx if sig was compiled with -opaque
    # direct_linkargs = []
    old_cmi = None

    ## module name is derived from sigfile name, so start with sig
    # if we have an input cmi, we will pass it on as Provider output,
    # but it is not an output of this action- do NOT add incoming cmi
    # to action outputs.

    # WARNING: When both .mli and .ml are inputs, '-o' is unavailable:
    # ocaml will write the output to the directory containing the
    # source files. This will NOT be the directory for output files
    # made with declare_file. There is no way that I know of to tell
    # the compiler to write outputs to some other directory. So if
    # both .mli and .ml are inputs, we need to copy/move/link the
    # output files to the correct (Bazel) output dir. Sadly, the
    # compile action will fail before we can do that, since it's
    # outputs will be in the wrong place.

    # in_structfile = None
    module_name = None
    mlifile = None
    cmifile = None
    sig_src = None

    sig_inputs = None
    sig_linkargs = None
    sig_paths = None

    ## FIXME: unify mli/cmi names
    mli_workfile = None
    cmi_workfile = None

    ################################################################
    ## split modules: compile workdir must contain both sig and struct
    ## files.

    ## we put everything in work_* vars in case renaming is involved
    ## e.g. a.mli could be renamed to Foo__a.mli
    work_ml   = None
    out_struct = None
    # work_o    = None
    work_mli  = None
    work_cmi  = None
    cmi_precompiled = False ## is cmi already produced by sig dep?

    modname = _resolve_modname(ctx)
    if debug: print("resolved module name: %s" % modname)

    #### INDIRECT DEPS first ####
    # these are "indirect" from the perspective of the consumer
    sigs_primary       = []
    sigs_secondary     = []
    structs_primary    = []
    structs_secondary  = []
    ofiles_primary     = [] # never? ofiles only come from deps
    ofiles_secondary   = []
    astructs_primary   = []
    astructs_secondary = []
    afiles_primary     = []
    afiles_secondary   = []
    archives_primary   = []
    archives_secondary = []
    paths_primary   = []
    paths_secondary = []

    resolvers = []

    cc_deps_primary             = []  ## list of CcInfo
    cc_deps_secondary           = []  ## list of depsets (of CcInfo)

    sigs_ns  = []
    structs_ns  = []
    ofiles_ns   = []
    astructs_ns = []
    afiles_ns   = []
    archives_ns = []
    paths_ns = []

    cc_libs = [] # ccinfo dep libnames, so later we can emit -lfoo

    sig_is_xmo = True

    if ctx.attr.sig:
        ##FIXME: make this a fn
        if debug: print("dyadic module, with sig: %s" % ctx.attr.sig)

        ## handlers to deal with ns renaming and ppx

        if OcamlSignatureProvider in ctx.attr.sig:
            if debug:
                print("sigattr is precompiled .cmi")
                print("ctx.attr.sig: %s" % ctx.attr.sig)
            cmi_precompiled = True
            (work_ml, out_struct,
             work_mli,
             out_cmi,   ## precompiled, possibly symlinked to __obazl
             sig_is_xmo) = _handle_precompiled_sig(ctx, modname, ext)

        else: ################################################
            if debug:
                print("sigattr is source file")

            cmi_precompiled = False
            (work_ml, out_struct,
             work_mli,
             out_cmi,  ## declared output file
             # cmi_precompiled,
             sig_is_xmo) = _handle_source_sig(ctx, modname, ext)

        ## now handle sig deps:
        if OcamlSignatureProvider in ctx.attr.sig:
            if debug: print("sigdep: compiled")
            sig_attr = ctx.attr.sig

            sigs_secondary.append(sig_attr[OcamlProvider].sigs)
            structs_secondary.append(sig_attr[OcamlProvider].structs)
            ofiles_secondary.append(sig_attr[OcamlProvider].ofiles)
            archives_secondary.append(sig_attr[OcamlProvider].archives)
            afiles_secondary.append(sig_attr[OcamlProvider].afiles)
            astructs_secondary.append(sig_attr[OcamlProvider].astructs)
            paths_secondary.append(sig_attr[OcamlProvider].paths)

        else:
            if debug: print("sigdep: source")

        if debug:
            print("WORK ml: %s" % work_ml)
            print("WORK cmox: %s" % out_struct)
            print("WORK mli: %s" % work_mli)
            print("WORK cmi: %s" % out_cmi)
            print("cmi_precompiled: %s" % cmi_precompiled)
    else:
        if debug:
            print("SINGLETON: no sigfile")
            print("module name: %s" % modname)
        if ctx.attr.ppx: ## no sig, plus ppx
            if debug_ppx: print("ppxing module:")
            work_ml = impl_ppx_transform(
                ctx.attr._rule, ctx,
                ctx.file.struct, modname + ".ml"
            )
            ## tooling may set _ppx_only to stop processing after ppx:
            if ctx.attr._ppx_only[BuildSettingInfo].value:
                return [
                    DefaultInfo(files = depset(direct=[work_ml])),
                    OcamlModuleMarker()
                ]

            out_cmi = ctx.actions.declare_file(
                scope + modname + ".cmi"
            )
            out_struct = ctx.actions.declare_file(
                scope + modname + ext
            )
        else: ## no sig, no ppx
            work_ml   = ctx.file.struct
            out_cmi = ctx.actions.declare_file(
                scope + modname + ".cmi"
            )
            out_struct = ctx.actions.declare_file(
                scope + modname + ext
            )

    # path_depsets.append(
    #     depset(direct = [out_struct.dirname, out_cmi.dirname])
    # )
    paths_primary = [out_struct.dirname, out_cmi.dirname]

    if debug_sig:
        print("sig analysis result")
        print("sigs_primary: %s" % sigs_primary)
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_primary: %s" % structs_primary)
        print("structs_secondary: %s" % structs_secondary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        ## archives cannot be direct deps
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("astructs_secondary: %s" % astructs_secondary)
        print("paths_secondary: %s" % paths_secondary)

    if debug:
        print("scope: %s" % scope)
        print("work_ml: %s" % work_ml)

    #########################
    args = ctx.actions.args()

    # args.add_all(tool_args)

    _options = get_options(ctx.attr._rule, ctx)
    if "-opaque" in ctx.attr.opts:
        xmo = False
    # else:
    #     xmo = True
    elif "-no-opaque" in ctx.attr.opts:
        xmo = True
    else:
        xmo = ctx.attr._xmo[BuildSettingInfo].value
        if not xmo:
            _options.append("-opaque")

    if debug_xmo: print("XMO: %s" % xmo)

    # if "-for-pack" in _options:
    #     for_pack = True
    #     _options.remove("-for-pack")
    # else:
    #     for_pack = False

    # if ctx.attr.pack:
    #     args.add("-for-pack", ctx.attr.pack)

    args.add_all(_options)

    if debug:
        print("SIG_IS_XMO? %s" % sig_is_xmo)

    if (not sig_is_xmo) or "-opaque" in _options:
        module_xmo = False
    else:
        module_xmo = True

    if debug:
        print("MODULE XMO? %s" % module_xmo)

    #######################################################
    ################ ACTION INPUTS/OUTPUTS ################

    src_inputs = [work_ml]
    if debug: print("SRC_INPUTS 1: %s" % src_inputs)

    ## mli, if we have one, always goes in action inputs, even if it
    ## was compiled separately. the compiler will look for it before
    ## it looks for the cmi.
    if work_mli: src_inputs.append(work_mli)

    ## action_outputs may be a subset of target_outputs - the latter
    ## but not the former will include any precompiled .cmi file.

    ## precompiled .cmi not a compile action output, but it is a
    ## target action output.
    if out_cmi and not cmi_precompiled:
        # we're compiling mli, so cmi is action output
        action_outputs.append(out_cmi)
        sigs_primary.append(out_cmi)

    ## out_struct (.cmo or .cmx) must go in action_outputs; it will
    ## also be delivered as a target output, but via a custom
    ## provider, not directly in the DefaultInfo provider.
    action_outputs.append(out_struct)
    structs_primary.append(out_struct)

    if tc.target != "vm":
        out_ofile = ctx.actions.declare_file(
            scope + modname + ".o"
        )
        ofiles_primary.append(out_ofile)
        action_outputs.append(out_ofile)
    else: out_ofile = None

    ################################################################
                   ####    DEPENDENCIES    ####

    ################ PRIMARY DEPENDENCIES ################
    ## Primary deps: OCaml source files and cc_deps.

    # ## topdown (hidden) resolver
    # ns_resolver = ctx.attr._ns_resolver
    # ns_resolver_files = ctx.files._ns_resolver
    # ## DEBUG: dump ns resolver provider
    # if hasattr(ns_resolver, "ns_name"):
    #     if debug_ns:
    #         print("TOP DOWN ns resolver: %s" % ns_resolver)
    #         print("  resolver files: %s" % ns_resolver_files)
    #         print("  resolver ns name: %s" % ns_resolver[OcamlNsResolverProvider].ns_name)
    #         print("ctx.attr._ns_resolver: %s" % ns_resolver)

    #     print("RESOLVER PATH: %s" % ns_resolver_files)
    #     path_list.extend([f.dirname for f in ns_resolver_files])

    # # if ctx.label.name in ["Stdlib", "Stdlib_cmi"]:
    # #     print("lbl: %s" % ctx.label.name)
    # #     print(" ns_resolver: %s" % ns_resolver)
    # #     print(" ns_resolver_files: %s" % ns_resolver_files)

    # path_list = [out_struct.dirname] # d.dirname for d in direct_linkargs]

    # if ctx.attr._rule.startswith("bootstrap"):
    #         args.add(tc.ocamlc)

    ## FIXME: support -bin-annot
    # if "-bin-annot" in _options: ## Issue #17
    #     out_cmt = ctx.actions.declare_file(scope + paths.replace_extension(module_name, ".cmt"))
    #     action_outputs.append(out_cmt)

    ################ SECONDARY DEPENDENCIES ################
    # codep_sigs_primary       = []
    # codep_structs_primary    = []
    # codep_ofiles_primary     = []
    # codep_archives_primary   = []
    # codep_afiles_primary     = []
    # codep_astructs_primary   = []
    # codep_cc_deps_primary   = []
    # codep_paths_primary   = []

    codep_sigs_secondary     = []
    codep_structs_secondary  = []
    codep_ofiles_secondary   = []
    codep_archives_secondary = []
    codep_afiles_secondary   = []
    codep_astructs_secondary = []
    codep_paths_secondary    = []
    codep_cc_deps_secondary   = []

    the_deps = ctx.attr.deps + ctx.attr.open

    dep_is_xmo = True

    ns_enabled = False
    ns_name    = None
    resolver_cmi    = None
    resolver_struct = None
    resolvers_secondary = []
    resolver_ofile  = None
    ns_ofile  = None

    if ctx.attr.ns_resolver:
        ns_enabled = True

    elif ctx.attr._ns_resolver:
        nsrp = ctx.attr._ns_resolver[OcamlNsResolverProvider]
        if nsrp.ns_name:
            ns_enabled = True

    nspaths_secondary = []
    ns_submodules = []

    if ns_enabled:
        (ns_enabled, ns_name,
         # ns_cmi, ns_struct, ns_ofile,
         resolver_cmi, resolver_struct, resolver_ofile,
         nssigs_ns, nsstructs_ns, nsofiles_ns,
         nsarchives_ns, nsafiles_ns, nsastructs_ns,
         # nscclibs_ns,
         nspaths_ns,
         ns_submodules) = _handle_ns_deps(ctx)

        sigs_ns.extend(nssigs_ns)
        structs_ns.extend(nsstructs_ns)
        ofiles_ns.extend(nsofiles_ns)
        astructs_ns.extend(nsastructs_ns)
        afiles_ns.extend(nsafiles_ns)
        archives_ns.extend(nsarchives_ns)
        paths_ns.extend(nspaths_ns)

        sigs_secondary.extend(nssigs_ns)
        # structs_secondary.extend(nsstructs_ns)
        resolvers_secondary.extend(nsstructs_ns)
        ofiles_secondary.extend(nsofiles_ns)
        astructs_secondary.extend(nsastructs_ns)
        afiles_secondary.extend(nsafiles_ns)
        archives_secondary.extend(nsarchives_ns)
        paths_secondary.extend(nspaths_ns)

    if debug_ns:
        print("ns analysis result")
        print("resolver_cmi: %s" % resolver_cmi)
        print("resolver_struct: %s" % resolver_struct)
        print("resolver_ofile: %s" % resolver_ofile)

        print("sigs_ns: %s" % sigs_ns)
        print("structs_ns: %s" % structs_ns)
        print("ofiles_ns: %s" % ofiles_ns)
        print("archives_ns: %s" % archives_ns)
        print("afiles_ns: %s" % afiles_ns)
        print("astructs_ns: %s" % astructs_ns)
        print("paths_ns: %s" % paths_ns)
        # print("cc_deps_ns: %s" % cc_deps_ns)
        print("paths_ns: %s" % paths_ns)
        print("ns_submodules: %s" % ns_submodules)

        # print("sigs_secondary: %s" % sigs_secondary)
        # print("structs_secondary: %s" % structs_secondary)
        # print("ofiles_secondary: %s" % ofiles_secondary)
        # print("archives_secondary: %s" % archives_secondary)
        # print("afiles_secondary: %s" % afiles_secondary)
        # print("astructs_secondary: %s" % astructs_secondary)
        # print("paths_secondary: %s" % paths_secondary)
        # print("cc_deps_secondary: %s" % cc_deps_secondary)

    ################################################################
    if debug: print("iterating deps")

    for dep in the_deps:
        if debug_deps: print("DEP: %s" % dep)
        ## OCaml deps first

        ## module deps have xmo flag
        ## aggregates do not
        ## so when we find an aggregate we must iterate over it

        if OcamlProvider in dep:
            provider = dep[OcamlProvider]
            if debug_deps: print("OcamlProvider: %s" % dep)
            if hasattr(provider, "xmo"):
                if debug_xmo:
                    print("DEP XMO: %s" % provider)
                    # print("DEP.cmi: %s" % provider.cmi)
                    # print("DEP: %s" % provider)
                    print("")

                # depending on xmo means...
                if not provider.xmo:
                    if debug:
                        print("DEP is not xmo: %s" % provider.sigs)
                    dep_is_xmo = False
                    # sigs_secondary.append(provider.cmi)
                #     sigs_depsets.append(provider.sigs)
                #     structs_depsets.append(provider.structs)
                # else:
                #     sigs_depsets.append(provider.sigs)
                #     structs_depsets.append(provider.structs)

            else: # no xmo flag on provider, default is xmo-enabled
                if debug:
                    if OcamlImportMarker in dep:
                        print("dep[OcamlImportMarker] %s" % dep)
                    if OcamlNsResolverProvider in dep:
                        print("dep[OcamlNsResolverProvider] %s" % dep)
                    if OcamlNsMarker in dep:
                        print("dep[OcamlNsMarker]")
                    print("provider %s" % dep)
                    if OcamlArchiveMarker in dep:
                        print("  archive dep: %s" % provider)
                    if OcamlLibraryMarker in dep:
                        print("  libdep: %s" % provider)
                    # if not OcamlLibraryMarker in dep:
                    ##FIXME: also check for OcamlArchiveMarker?

            if debug: print("xmo-independent deps logic")
            ## xmo-independent logic
            # this puts entire deptree into secondaries
            sigs_secondary.append(provider.sigs)
            structs_secondary.append(provider.structs)
            ofiles_secondary.append(provider.ofiles)
            archives_secondary.append(provider.archives)

            if ns_enabled:
                if OcamlArchiveMarker in dep:
                    if str(dep.label) not in ns_submodules:
                        archives_secondary.append(provider.structs)

            afiles_secondary.append(provider.afiles)
            astructs_secondary.append(provider.astructs)
            paths_secondary.append(provider.paths)

            if hasattr(provider, "cc_libs"):
                cc_libs.extend(provider.cc_libs)

        ## Then ppx codeps

        # indirect_linkargs_depsets.append(dep[DefaultInfo].files)
        if PpxCodepsProvider in dep:
            codep = dep[PpxCodepsProvider]
            ## aggregates may provide an empty PpxCodepsProvider
            if hasattr(codep, "sigs"):

                if debug_ppx:
                    print("processing ppx_codeps from ppx executable")
                    print("ppx_codeps provider: %s" % codep)
                    print("  sigs: %s" % codep.sigs)
                    print("ppx_codeps provider: %s" % codep)
                    print("ppx_codeps provider: %s" % codep)
                    print("ppx_codeps provider: %s" % codep)
                    # print("codep.paths: %s" % codep.paths)
                    # print("codep.: %s" % codep.sigs)

                # print("ppx dep: %s" % dep)
                # for fld in dir(codep):
                #     print("codep fld: %s" % fld)

                codep_sigs_secondary.append(codep.sigs)
                codep_structs_secondary.append(codep.structs)
                codep_archives_secondary.append(codep.archives)
                codep_ofiles_secondary.append(codep.ofiles)
                #FIXME
                codep_afiles_secondary.append(codep.afiles)
                codep_astructs_secondary.append(codep.astructs)
                codep_paths_secondary.append(codep.paths)

        ## Finally CcInfo deps

        ## If this dep was produced by a cc_* rule, then we just want
        ## the DefaultInfo files, not everything in its CcInfo
        ## provider. In the case of an FFI adapter, that would include
        ## the OCaml C sdk libs (libcamlrun.a, etc.). We do not need
        ## to pass those libs along, they were just needed by the cc_*
        ## target.

        ## So how can we detect here that a dep was produced by such a
        ## target? For static libs, DefaultInfo would contain exactly
        ## one .a file.
        if CcInfo in dep:
            if debug_ccdeps: print("CcInfo dep: %s" % dep)
            if OcamlProvider in dep:
                if debug_ccdeps: print("OcamProvider dep: %s" % dep)
                ## this ccinfo is a carrier, not a direct cc_* dep
                cc_deps_secondary.append(dep[CcInfo])
            else:
                if debug_ccdeps: print("NOT OcamProvider dep: %s" % dep)
                ## must be provided by a cc_* target
                (libname, filtered_ccinfo) = filter_ccinfo(dep)
                print("LIBNAME: %s" % libname)
                print("FILTERED CCINFO: %s" % filtered_ccinfo)
                if filtered_ccinfo:
                    cc_deps_primary.append(filtered_ccinfo)
                    cc_libs.append(libname)
                else:
                    ## must be a shared lib
                    ## not yet supported
                    print("DefaultInfo: %s" % dep[DefaultInfo])

    if debug_deps:
        print("deps analysis result:")
        print("sigs_primary: %s" % sigs_primary)
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_primary: %s" % structs_primary)
        print("structs_secondary: %s" % structs_secondary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        ## archives cannot be direct deps
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("astructs_secondary: %s" % astructs_secondary)
        print("paths_secondary: %s" % paths_secondary)

        print("resolver_struct: %s" % resolver_struct)
        print("resolvers_secondary: %s" % resolvers_secondary)

    ################ Signature Dep ################
    ## FIXME: this logic does not work if we needed to
    ## symlink split sigfiles into working dir
    # if ctx.attr.sig:
    #     if cmi_inputs:
    #         sigs_depsets.append(cmi_inputs)
    #         indirect_linkargs_depsets.append(sig_linkargs)
    #         path_depsets.append(sig_paths)

    ############ PPX EXECUTABLE DEPENDENCIES ################
    ## ppx_codeps of the ppx executable are material deps of this
    ## module. They thus become elements in the depgraph of anything
    ## that depends on this module, so they are passed on just like
    ## regular deps.

    ## Can a ppx_executable also have deps listed in OcamlProvider?
    ## Don't think so.

    ## But it can carry CcInfo

    ## ppx_modules, that do ppx processing, may have a ppx_codeps
    ## attribute, for the deps they inject into the files they
    ## preprocess. They are _NOT_ material deps of the module itself.
    ## It follows that they are passed on in a PpxCodepsProvider, not
    ## in OcamlProvider.

    ppx_codeps_list = []

    if ctx.attr.ppx:
        ## to ppx a module:
        ## 1. ppx tranform src - done above
        ## 2. extract ppx_codeps from the ppx.exe
        ## 3. add them to the module's depsets
        ## 4. compile transformed src, with ppx_codeps
        if debug_ppx: print("processing deps of ppx: %s" % ctx.attr.ppx)

        if PpxCodepsProvider in ctx.attr.ppx:
            codep = ctx.attr.ppx[PpxCodepsProvider]

            if debug_ppx:
                print("processing ppx_codeps from ppx executable")
                print("ppx_codeps provider: %s" % codep)
                # print("codep.paths: %s" % codep.paths)
                # print("codep.: %s" % codep.sigs)

            sigs_secondary.append(codep.sigs)
            structs_secondary.append(codep.structs)
            archives_secondary.append(codep.archives)
            ofiles_secondary.append(codep.ofiles)
            afiles_secondary.append(codep.afiles)
            astructs_secondary.append(codep.astructs)
            paths_secondary.append(codep.paths)

        if CcInfo in ctx.attr.ppx:
            cc_deps_secondary.append(ctx.attr.ppx[CcInfo])

    ################ PRIMARY CCLIB DEPENDENCIES ################
    # FIXME: remove cc_deps attrib
    for ccdep in ctx.attr.cc_deps:
        if CcInfo in ccdep:
            cc_deps_primary.append(ccdep[CcInfo])

        ## stublibs is label_keyed_string_dict, whose keys are targets
        ## providing CcInfo


    # codep_sigs_secondary_depset=depset(transitive=codep_sigs_secondary)
    # codep_structs_secondary_depset=depset(transitive=codep_structs_secondary)
    # codep_archives_secondary_depset=depset(transitive=codep_archives_secondary)
    # codep_astructs_secondary_depset=depset(transitive=codep_astructs_secondary)

    # ppx_codep_structset = depset(transitive=ppx_codep_structs)
    # print("ppx_codep_structset: %s" % ppx_codep_structset)

    # archives = []
    # linkargs = depset(transitive=indirect_linkargs_depsets)
    # if debug: print("LINKARGS: %s" % linkargs)
    # for larg in linkargs.to_list():
    #     if larg.extension in struct_extensions:
    #         archives.append(larg)
    #         args.add(larg.path)
    #         includes.append(larg.dirname)

    sigs_depset = depset(order="postorder",
                         direct = sigs_primary,
                         transitive = sigs_secondary)
    if debug_deps: print("SIGS_depset: %s" % sigs_depset)
    structs_depset = depset(order="postorder",
                            direct = structs_primary,
                            transitive = structs_secondary)
    if debug_deps: print("STRUCTS_depset: %s" % structs_depset)
    ofiles_depset = depset(order="postorder",
                           direct = ofiles_primary,
                           transitive = ofiles_secondary)
    if debug_deps: print("OFILES_depset: %s" % ofiles_depset)
    archives_depset = depset(order="postorder",
                             direct = archives_primary,
                             transitive = archives_secondary)
    if debug_deps: print("ARCHIVES_depset: %s" % archives_depset)
    afiles_depset = depset(order="postorder",
                            direct = afiles_primary,
                            transitive = afiles_secondary)
    if debug_deps: print("ARFILES_depset: %s" % afiles_depset)
    astructs_depset = depset(order="postorder",
                         direct = astructs_primary,
                         transitive = astructs_secondary)
    if debug_deps: print("ARSTRUCTS_depset: %s" % astructs_depset)
    # for arch in archives_depset.to_list():
    #         args.add(arch.path)
    #         includes.append(arch.dirname)

    # for cdep in sigs_depsets:
    #     for cd in cdep.to_list():
    #         args.add("-I", cd.dirname)

    paths_depset  = depset(
        order = dsorder,
        direct = paths_primary,
        transitive = paths_secondary
        # + indirect_ppx_codep_path_depsets
    )

    includes.extend(paths_depset.to_list()) # , before_each="-I")
    # args.add("-absname")
    args.add_all(includes, before_each="-I", uniquify = True)

    if ns_enabled:
        args.add("-no-alias-deps")
        args.add("-open", ns_name)

    # attr '_ns_resolver' a label_flag that resolves to a (fixed)
    # ocaml_ns_resolver target whose params are set by transition fns.
    # by default the 'resolver' field is null.

    # if "-shared" in _options:
    #     args.add("-shared")
    # else:


    ## runtime deps must be added to the depgraph (so they get built),
    ## but not the command line (they are not build-time deps).

    #     print("SRC_INPUTS: %s" % src_inputs)

    # print("mli_out: %s" % mli_out)
    # print("sigs_depsets: %s" % sigs_depsets)

    # if debug_ppx:
    #     # for dep in action_inputs_depset.to_list():
    #     # for dset in indirect_ppx_codep_depsets:
    #     for dset in ppx_codep_structs:
    #         for d in dset.to_list():
    #             print("PPX IDEP: %s" % d)

    ## WARNING: inlined if else breaks something in the input depset
    if cmi_precompiled:
        maybe_cmi = [out_cmi]
    else:
        maybe_cmi = []

    if xmo:
        xmo_deps = structs_secondary + ofiles_secondary
    else:
        xmo_deps = []
    if debug_xmo: print("XMO DEPS: %s" % xmo_deps)

    action_inputs_depset = depset(
        order = dsorder,
        direct = src_inputs
        + maybe_cmi
        ## omit direct deps, they're outputs of this action
        # + sigs_primary + structs_primary + ofiles_primary
        + archives_primary

        ## NB: we don't need cmx/cmo deps to _compile_ a module
        ## at worst we'll get warning 58 about not using -opaque

        # + structs_primary
        # + afiles_primary
        # + astructs_primary
        # + ns_resolver_files
        + ctx.files.deps_runtime,
        transitive = # sigs_depsets
         # indirect_ppx_codep_depsets
        # + [ppx_codep_structset]
        # + [depset(direct=archives)]
         # ns_deps
        xmo_deps
        + archives_secondary
        ## including archived cmx/cmo prevents warning 58
        ## WARNING: only for module compilation; do not include for linking
        ## TODO: reconcile archive processing with xmo
        + astructs_secondary
        ## non-archived structs:
        + structs_secondary
        # + afiles_secondary

        + sigs_secondary

        ## module compilation never depends on cclibs
        # + cclibs_secondary
        # + bottomup_ns_inputs
    )
    # if ctx.label.name in ["Red"]:
    #     print("ACTION INPUTS: %s" % ctx.label)
    #     for dep in action_inputs_depset.to_list():
    #         print("IDEP: %s" % dep.path)
    # #         # args.add("-I", dep.short_path)
    #         args.add("-I", dep.dirname)

    # if ctx.label.name == "Misc":
    #     print("action_inputs_depset: %s" % action_inputs_depset)

    if ctx.attr.open:
        for dep in ctx.files.open:
            args.add("-open", normalize_module_name(dep.basename))

    # if ctx.attr.ns_resolver:
    #     args.add("-open", bottomup_ns_name)

    args.add("-c")

    # args.add("-FOO", work_ml)
    # args.add("-BAR", work_ml.short_path)

    if work_mli and not cmi_precompiled: # sig_src:
        args.add("-I", work_mli.dirname) # sig_src.dirname)
        # args.add("-intf", sig_src)
        args.add(work_mli) # sig_src)

        # args.add("-impl", structfile)
        # args.add(in_structfile) # structfile)
        args.add(work_ml) # structfile)
    else:
        args.add("-impl", work_ml) # in_structfile) # structfile)
        args.add("-o", out_struct)

    # if ctx.attr._rule.startswith("bootstrap"):
    #     toolset = [tc.ocamlrun, tc.ocamlc]
    # else:
    #     toolset = [tc.ocamlopt, tc.ocamlc]

    # if debug:
    #     print("COMPILE INPUTS: %s" % action_inputs_depset)

    if debug:
        print("COMPILE OUTPUTS: %s" % action_outputs)

    if hasattr(ctx.attr, "ppx_codeps"):
        mnemonic = "CompileOCamlPpxModule"
        rule     = "ppx_module"
    else:
        mnemonic = "CompileOCamlModule"
        rule     = "ocaml_module"

    ################
    ctx.actions.run(
        # env = env,
        executable = tc.compiler,
        arguments = [args],
        inputs    = action_inputs_depset,
        outputs   = action_outputs,
        tools = [tc.compiler], # + tool_args,
        mnemonic = mnemonic,
        progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
            mode = tc.host + ">" + tc.target,
            rule = rule,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )
    ################
    ## only the structfile is default output; that way consumers can
    ## put default output on cmd line
    default_depset = depset(
        order = dsorder,
        direct = [out_struct]  ## target_outputs,
        # transitive = bottomup_ns_files
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    outputGroup_all_depset = depset(
        order  = dsorder,
        direct = action_outputs + [out_cmi] #cmi_out ## + mli_out,
    )

    # if cmi_precompiled:
    #     cmi_depset = depset(
    #         direct=cmi_out,
    #         transitive = bottomup_ns_cmi
    #     )
    # else if out_cmi:
    #     cmi_depset = depset(
    #         direct = [out_cmi],
    #         transitive = bottomup_ns_cmi
    #     )
    cmi_depset = depset(
        direct = [out_cmi]
        # transitive = bottomup_ns_cmi
    )

    new_sigs_depset = depset(
        order = dsorder,
        direct = [out_cmi]
        # ns_resolver_files
        + ctx.files.deps_runtime,
        transitive = [sigs_depset]
        # + [cmi_depset] ## action_outputs
        # + indirect_ppx_codep_depsets
        # + ns_deps
        # + bottomup_ns_inputs
    )

    ## same as action_inputs_depset except structfile omitted
    # new_structs_depset = depset(
    #     order = dsorder,
    #     direct = src_inputs
    #     + action_outputs #FIXME: omit cmx?
    #     + ns_resolver_files
    #     + ctx.files.deps_runtime,
    #     transitive = structs_depsets ## sigs_depsets
    #     + indirect_ppx_codep_depsets
    #     + ns_deps
    #     + bottomup_ns_inputs
    # )
    new_structs_depset = depset(
        order = dsorder,
        direct = [out_struct],
        transitive = structs_secondary
    )

    # if debug:
    #     print("CLOSURE: %s" % new_structs_depset)

    # linkset    = depset(transitive = indirect_linkargs_depsets)

    # fileset_depset = depset(
    #     direct= action_outputs + [out_cmi]
    #     # transitive = bottomup_ns_fileset
    # )

    # cclibs_depset = depset(order=dsorder,
    #                          transitive=cclibs_secondary)

    ocamlProvider = OcamlProvider(
        # files = outputGroup_all_depset,
        # cmi      = depset(direct = [out_cmi]),
        cmi      = out_cmi,  ## no need for a depset for one file?
        xmo      = module_xmo,
        # fileset  = fileset_depset,
        # inputs   = new_structs_depset,

        sigs     = new_sigs_depset,
        structs  = new_structs_depset,
        ofiles   = depset(order=dsorder,
                          direct=[out_ofile] if out_ofile else [],
                          transitive=ofiles_secondary),
        archives = archives_depset,
        afiles   = depset(order=dsorder,
                           direct=afiles_primary,
                           transitive=afiles_secondary),
        astructs = astructs_depset,
        # cclibs = cclibs_depset,

        # linkargs = linkset,
        paths    = paths_depset,

        resolvers = depset(order=dsorder,
                           direct=[resolver_struct],
                           transitive=resolvers_secondary),

        cc_libs = cc_libs,

        srcs = depset(direct=[work_ml])
    )
    # print("MPRovider: %s" % ocamlProvider)

    ################################################################
    providers = [
        defaultInfo,
        OcamlModuleMarker(marker="OcamlModule"),
        ocamlProvider,
    ]

    ## FIXME: make this conditional:
    ## if this module is a submodule in a namespace:
    # if ns_resolver:
    #     print("MODULE NS_RESOLVER: %s" % ns_resolver)
    # else:
    #     print("NO MODULE NS_RESOLVER: %s" % ns_resolver)

    if ctx.attr.ns_resolver:  ## bottomup
        resolver = ctx.attr.ns_resolver
        if debug:
            print("attr.ns_resolver: %s" % resolver)
            print("resolver: %s" % resolver[OcamlNsResolverProvider])
        nsSubmoduleMarker = OcamlNsSubmoduleMarker(
            ns_name = resolver[OcamlNsResolverProvider].ns_name
        )
        providers.append(nsSubmoduleMarker)

    #     nsResolverProvider = OcamlNsResolverProvider(
    #         files = ctx.attr._ns_resolver.files,
    #         paths = depset([d.dirname for d in ctx.attr._ns_resolver.files.to_list()])
    #     )

    # print("RESOLVER PROVIDER: %s" % nsResolverProvider)

    ## if this is a ppx module, its ppx_codeps (direct or indirect)
    ## must be passed to any ppx_executable that depends on it.
    ## FIXME: make this conditional:
    ## if module has direct or indirect ppx_codeps:
    if ctx.attr.ppx:
        if debug_ppx:
            print("Constructing PpxCodepsProvider: %s" % ctx.label)

        codep_archives_depset = depset(
            order=dsorder,
            # direct=codep_archives_primary,
            transitive=codep_archives_secondary)
        codep_afiles_depset = depset(
            order=dsorder,
            # direct=codep_astructs_primary,
            transitive=codep_afiles_secondary)
        codep_astructs_depset = depset(
            order=dsorder,
            # direct=codep_astructs_primary,
            transitive=codep_astructs_secondary)

        ppxCodepsProvider = PpxCodepsProvider(
            # ppx_codeps = ppx_codeps_depset,
            sigs    = depset(order=dsorder,
                             # direct=codep_sigs_primary,
                             transitive=codep_sigs_secondary),
            structs    = depset(order=dsorder,
                                # direct=codep_structs_primary,
                                transitive=codep_structs_secondary),
            ofiles    = depset(order=dsorder,
                               # direct=codep_ofiles_primary,
                               transitive=codep_ofiles_secondary),
            archives  = codep_archives_depset,
            afiles    = codep_afiles_depset,
            astructs  = codep_astructs_depset,
            paths     = depset(order = dsorder,
                               # direct = codep_paths_primary,
                               transitive = codep_paths_secondary),
            # cclibs    = depset(order=dsorder,
            #                    # direct=codep_cclibs_primary,
            #                    transitive=codep_cclibs_secondary),
        )
        providers.append(ppxCodepsProvider)

    ## now merge ccInfo list
    if cc_deps_primary or cc_deps_secondary:
        ccInfo = cc_common.merge_cc_infos(
            cc_infos = cc_deps_primary + cc_deps_secondary
        )
        providers.append(ccInfo )
        if debug_ccdeps:
            print("Module provides: %s" % ccInfo)

    if hasattr(ctx.attr, "ppx_codeps"):
        providers.append(PpxModuleMarker())

    ################
    outputGroupInfo = OutputGroupInfo(
        # cc         = ccInfo.linking_context.linker_inputs.libraries,
        cmi       = cmi_depset,
        # fileset   = fileset_depset,
        sigs      = new_sigs_depset,
        structs   = new_structs_depset,
        ofiles    = ofiles_depset,
        archives  = archives_depset,
        afiles    = afiles_depset,
        astructs = astructs_depset,
        ## put these in PpxCodepsProvider?
        # ppx_codeps = ppx_codeps_depset,
        # cc = action_inputs_ccdep_filelist,
        closure = new_structs_depset,
        all = depset(
            order = dsorder,
            transitive=[
                default_depset,
                outputGroup_all_depset,
                # ppx_codeps_depset,
                # depset(action_inputs_ccdep_filelist)
            ]
        )
    )

    providers.append(outputGroupInfo)

    return providers
