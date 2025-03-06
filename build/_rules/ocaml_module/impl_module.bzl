load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("@rules_ocaml//build:providers.bzl",
     "OCamlCodepsProvider",
     "OCamlDepsProvider",
     "OCamlModuleProvider",

     "OcamlArchiveMarker",
     "OCamlImportProvider",
     "OCamlLibraryProvider",
     "OcamlNsMarker",
     "OCamlNsResolverProvider",
     "OcamlNsSubmoduleMarker",
     "OCamlSignatureProvider")

load("@rules_ocaml//lib:merge.bzl",
     "merge_deps",
     "aggregate_codeps",
     "DepsAggregator",
     "COMPILE", "LINK", "COMPILE_LINK")

load("//build:actions.bzl", "ppx_transformation")

load("//build/_lib:module_naming.bzl",
     "derive_module_name_from_file_name")

load("//build/_lib:utils.bzl",
     "get_options", "dsorder", "tmpdir")

# load("//build/_lib:utils.bzl",
#      "capitalize_initial_char",
#      # "get_sdkpath",
# )

load("//build/_lib:module_naming.bzl",
     "file_to_lib_name",
     "module_name_from_label",
     "normalize_module_name")

load("@rules_ocaml//build/_lib:ccdeps.bzl",
     "cc_shared_lib_to_ccinfo",
     "filter_ccinfo",
     # "extract_cclibs",
     "dump_CcInfo",
     "ccinfo_to_string"
     )

load("@rules_ocaml//lib:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCBLUBG", "CCMAG", "CCCYN", "CCRESET")

scope = tmpdir

##########################
def _handle_ns_stuff(ctx):
    debug_ns = False

    ## Bottomup: resolver in 'ns' attribute
    ## Topdown: resolver in '_ns_resolver' attr

    if not hasattr(ctx.attr, "ns"):
        ## this is a plain ocaml_module w/o namespacing
        return  (False, # ns_enabled
                 None,  # nsr_provider = NsResolverProvider
                 None)  # nsr_target module
        # return  (False, # ns_enabled
        #          None,  # ns_name
        #          None,  # nsrp
        #          None,  # ns
        #          # []    # nsr_target_files
        #          )

    ns_enabled = False
    nsr_provider = None
    nsr_target = None

    ## bottom-up namespacing
    if ctx.attr.ns:
        ns_enabled = True
        nsr_target = ctx.attr.ns
        nsr_provider = ctx.attr.ns[OCamlNsResolverProvider]
        if hasattr(nsr_provider, "modname"):
            # e.g. Foo__, not Foo (ns name)
            ns_enabled = True

    ## top-down namespacing
    elif ctx.attr._ns_resolver:
        nsr_provider = ctx.attr._ns_resolver[OCamlNsResolverProvider]
        if debug_ns:
            print("_ns_resolver: %s" % ctx.attr._ns_resolver)
            print("nsr_provider: %s" % nsr_provider)
        if not nsr_provider.tag == "NULL":
            ns_enabled = True
            nsr_target = ctx.attr._ns_resolver ## [0] # index by int?
    else:
        if debug_ns: print("m: no resolver for %s" % ctx.label)
        nsr_target = None
        # ns_resolver_files = []

    return  (ns_enabled,
             nsr_provider,
             nsr_target)

################
## incoming cmi may have been ppx transformed,
## which puts it in __obazl workdir?
def _handle_precompiled_sig(ctx, modname, ext):

    debug      = False
    debug_deps = False
    debug_ppx  = False
    debug_ns   = False

    sigProvider = ctx.attr.sig[OCamlSignatureProvider]
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
    # if tgt_pkgdir == sig_pkgdir:
    # if sig_pkgdir.find(scope): # already in __obazl workdir
    #     ## already in same dir
    #     if debug: print("NOT SYMLINKING mli/cmi")
    #     work_mli = sigProvider.mli
    #     work_cmi = sigProvider.cmi
    # else:
    #     if debug: print("SYMLINKING mli/cmi")
    #     work_mli = ctx.actions.declare_file(
    #         scope + sigProvider.mli.basename
    #     )
    #     ctx.actions.symlink(
    #         output = work_mli, target_file = sigProvider.mli,
    #         progress_message = "symlinking {src} to {dst}".format(
    #             src = sigProvider.mli.basename, dst = work_mli.basename
    #         )
    #     )
    #     work_cmi = ctx.actions.declare_file(
    #         scope + sigProvider.cmi.basename
    #     )
    #     ctx.actions.symlink(
    #         output = work_cmi, target_file = sigProvider.cmi,
    #         progress_message = "symlinking {src} to {dst}".format(
    #             src = sigProvider.cmi.basename, dst = work_cmi.basename
    #         )
    #     )

    work_mli = sigProvider.mli
    work_cmi = sigProvider.cmi

    # we need to keep track of the original file when we ppx, because
    # some ppxes may write its path into the transformed outputs, and
    # tools may want to access it.

    # The transform of x/foo.ml generates x/__ppx/foo.ml, which
    # compiles to x/__obazl/foo.cmo. Maybe it would be better to
    # generate x/__obazl/foo.ml.ppx or the like.

    ppx_src_ml = False
    # FIXME: pass the ppx to the compiler using -ppx
    if ctx.attr.ppx:
        if debug_ppx: print("ppxing sig:")
        ppx_src_ml, work_ml = ppx_transformation(
            ctx.attr._rule, ctx,
            ctx.file.struct, modname + ".ml"
        )
    else:
        if debug_ppx: print("no ppx")
        # work_ml = ctx.actions.declare_file(
        #     # scope + ctx.file.struct.basename
        #     scope + modname + ".ml"
        # )
        # ctx.actions.symlink(
        #     output = work_ml, target_file = ctx.file.struct,
        #     progress_message = "symlinking %{input} to %{output}"
        # )
        work_ml = ctx.file.struct

    work_struct = ctx.actions.declare_file(
        scope + modname + ext
    )
    ## no symlink, cmox output by compile action

    return(ppx_src_ml, work_ml,
           work_struct,
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

    ppx_src_ml = None
    if ctx.attr.ppx:
        ## ppx sigfile
        ppx_src_ml, work_mli = ppx_transformation(
            ctx.attr._rule, ctx,
            ctx.file.sig, modname + ".mli"
        )
    else:
        work_mli = ctx.actions.declare_file(
            scope + modname + ".mli"
        )
        ctx.actions.symlink(output = work_mli, target_file = ctx.file.sig)

    work_cmi = ctx.actions.declare_file(
        scope + modname + ".cmi"
    )
    # no symlink, will be output of compile action

    if ctx.attr.ppx: ## no sig, plus ppx
        if debug: print("ppxing module:")
        ppx_src_ml, work_ml = ppx_transformation(
            ctx.attr._rule, ctx,
            ctx.file.struct, modname + ".ml"
        )
    else:
        work_ml = ctx.actions.declare_file(
            scope + modname + ".ml"
        )
        ctx.actions.symlink(output = work_ml, target_file = ctx.file.struct)

    out_struct = ctx.actions.declare_file(
        scope + modname + ext
    )
    ## no symlink, cmox output by compile action

    return(ppx_src_ml, work_ml,
           out_struct,
           work_mli, work_cmi,
           False) # xmo determined by opt

########################
def _resolve_modname(ctx, nsr_provider):
    debug = False

    # If ctx.attr.sig is precompiled
    #     derive module name from it
    # Elif ctx.attr.module_name not null
    #     derive modname from it
    # Else derive module name from ctx.attr.struct

    if debug: print("_resolve_modname")

    if ctx.attr.sig:
        if debug: print("ctx.attr.sig: %s" % ctx.attr.sig)
        if ctx.file.sig.is_source:
            if debug: print("sig arg is src file")
            ## sigfile is srcfile; derive mod name from module attrib
            ## or structfile

            # derive_module_name_from_file_name (unless sig attr is a
            # cmi), handles ns prefixing, even with 'module' attr
            if ctx.attr.module_name:
                (from_name,
                 modname) = derive_module_name_from_file_name(
                     ctx, ctx.attr.module_name, nsr_provider
                 )
                return modname
            else:
                (from_name,
                 modname) = derive_module_name_from_file_name(
                     ctx, ctx.label.name, nsr_provider
                 )
                return modname

        elif OCamlSignatureProvider in ctx.attr.sig:
            # name of cmi always determines modname
            if debug: print("sig arg is cmi")
            if ctx.attr.module_name:
                fail("Cannot force module name if sig attr is cmi file")

            (module_name, extension) = paths.split_extension(
                ctx.file.sig.basename)
            # cmi name should already be normalized and namespaced
            return module_name
        else: # generated src, e.g. by ocamlyacc
            if ctx.attr.module_name:
                (from_name,
                 modname) = derive_module_name_from_file_name(
                    ctx, ctx.attr.module_name, nsr_provider
                 )
                return modname
            else:
                (from_name,
                 modname) = derive_module_name_from_file_name(
                     ctx, ctx.label.name, nsr_provider
                 )
                return modname

    else:
        if debug: print("singleton module, no sig arg")
        ## singleton, no sig attribute
        if ctx.attr.module_name:
            if debug: print("ctx.attr.module_name override: %s" % ctx.attr.module_name)
            (from_name,
             modname) = derive_module_name_from_file_name(
                 ctx, ctx.attr.module_name, nsr_provider
             )
            if debug: print("derived module name: %s" % modname)
            return modname
            # basename = ctx.attr.module_name
            # return basename[:1].capitalize() + basename[1:]
        else:
            if ctx.attr.struct:
                if debug: print("deriving module name from structfile: %s" % ctx.file.struct.basename)
                (mname, extension) = paths.split_extension(ctx.file.struct.basename)
                (from_name,
                 modname) = derive_module_name_from_file_name(
                     ctx, mname, nsr_provider
                 )
                if debug: print("derived module name: %s" % modname)
            else:
                modname = "FIXME:NSRESOLVERMODNAMEe"

            return modname

def _resolve_fname(ctx, nsr_provider):
    debug = False

    # If ctx.attr.sig is precompiled
    #     derive module name from it
    # Elif ctx.attr.module_name not null
    #     derive modname from it
    # Else derive module name from ctx.attr.struct

    if debug: print("_resolve_modname")

    if ctx.attr.sig:
        if debug: print("ctx.attr.sig: %s" % ctx.attr.sig)
        if ctx.file.sig.is_source:
            if debug: print("sig arg is src file")
            ## sigfile is srcfile; derive mod name from module attrib
            ## or structfile

            # derive_module_name_from_file_name (unless sig attr is a
            # cmi), handles ns prefixing, even with 'module' attr
            if ctx.attr.module_name:
                (from_name,
                 modname) = derive_module_name_from_file_name(
                     ctx, ctx.attr.module_name, nsr_provider
                 )
                return modname
            else:
                (from_name,
                 modname) = derive_module_name_from_file_name(
                     ctx, ctx.label.name, nsr_provider
                 )
                return modname

        elif OCamlSignatureProvider in ctx.attr.sig:
            # name of cmi always determines modname
            if debug: print("sig arg is cmi")
            if ctx.attr.module_name:
                fail("Cannot force module name if sig attr is cmi file")

            (module_name, extension) = paths.split_extension(
                ctx.file.sig.basename)
            # cmi name should already be normalized and namespaced
            return module_name
        else: # generated src, e.g. by ocamlyacc
            if ctx.attr.module_name:
                (from_name,
                 modname) = derive_module_name_from_file_name(
                    ctx, ctx.attr.module_name, nsr_provider
                 )
                return modname
            else:
                (from_name,
                 modname) = derive_module_name_from_file_name(
                     ctx, ctx.label.name, nsr_provider
                 )
                return modname

    else:
        if debug: print("singleton module, no sig arg")
        ## singleton, no sig attribute
        if ctx.attr.module_name:
            if debug: print("ctx.attr.module_name override: %s" % ctx.attr.module_name)
            (from_name,
             modname) = derive_module_name_from_file_name(
                 ctx, ctx.attr.module_name, nsr_provider
             )
            if debug: print("derived module name: %s" % modname)
            return modname
            # basename = ctx.attr.module_name
            # return basename[:1].capitalize() + basename[1:]
        else:
            if ctx.attr.ns         :
                if debug: print("BOTTOMUP renaming")
                bottomup = True
                ns_resolver = ctx.attr.ns
                if hasattr(ns_resolver[OCamlNsResolverProvider],
                           "fs_prefix"):
                    prefix = ns_resolver[OCamlNsResolverProvider].fs_prefix
                else:
                    (prefix, extension) = paths.split_extension(
                        ctx.file.ns.basename)

                    ## Derive module name from src file name
                (mname, extension) = paths.split_extension(
                    ctx.file.struct.basename)
                return prefix + mname[:1].capitalize() + mname[1:]
            else:
                if debug: print("TOPDOWN renaming")
                (from_name,
                 modname) = derive_module_name_from_file_name(
                     ctx, ctx.label.name, nsr_provider
                 )
                # (mname, extension) = paths.split_extension(
                #     ctx.file.struct.basename)
                return modname

            # if ctx.attr.struct:
            #     if debug: print("deriving module name from structfile: %s" % ctx.file.struct.basename)
            #     (mname, extension) = paths.split_extension(ctx.file.struct.basename)
            #     (from_name,
            #      modname) = derive_module_name_from_file_name(
            #          ctx, mname, nsr_provider
            #      )
            #     if debug: print("derived module name: %s" % modname)
            # else:
            #     modname = "FIXME:NSRESOLVERMODNAMEe"


#####################
def impl_module(ctx): ## , mode, tool, tool_args):

    # tasks:
    # * manage namespacing
    #   * obtain ns resolver, ns name, submodules list
    # * construct module name
    #   * optional: add ns prefix
    # * merge deps
    #   * std deps
    #   * ppx codeps
    #   * cc deps
    #   * ?
    # * optional: ppx transformation of srcs
    #   * structfile
    #   * optional: sigfile
    # * construct inputs depset - everything
    # * construct outputs depset
    # * construct cmd line
    #   * flags and options
    #   * link args
    #   * include paths
    # * execute compile action
    # * construct providers
    #   * if structfile in manifest > astructs
    #   * else > structs


    # True if ctx.label.name == "Hello" else False

    debug        = False
    debug_modname = False
    debug_ccdeps = False
    debug_deps   = False
    debug_codeps = False
    debug_ns     = False
    debug_ppx    = False
    debug_sig    = False
    debug_tc     = False
    debug_xmo    = False

    debug_manifest = False

    # Q: why would a module have a manifest?
    # A: top-down ns submodules inherit (ns) manifest from resolver
    ## BUT: only used for ns processing (i.e. this module is in manifest)
    ## ignore otherwise
    manifest = []
    # if debug_manifest:
    #     if hasattr(ctx.attr, "_manifest"):
    #         if ctx.attr._manifest:
    #             manifest = ctx.attr._manifest[BuildSettingInfo].value
    #             print("_manifest: %s" % manifest)
                # fail("XX %s" % manifest)

    if debug:
        print("===============================")

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

    # tc = ctx.toolchains["@ocaml_toolchains//type:std"]
    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    # print("target platform: {p} (lbl: {l})".format(
    #     p= tc.target, l=ctx.label))

    tc_options = ctx.toolchains["@rules_ocaml//toolchain/type:profile"]
    # print("tc_options: %s" % tc_options)

    ext  = ".cmo" if  tc.target == "vm" else ".cmx"

    # if tc.target == "vm":
    #     struct_extensions = ["cma", "cmo"]
    # else:
    #     struct_extensions = ["cmxa", "cmx"]

    ns_enabled = False
    (ns_enabled,
     nsr_provider, nsr_target) = _handle_ns_stuff(ctx)

    # resolvers = []

    ##########################
    depsets = DepsAggregator()

    if ctx.attr.sig:
        depsets = merge_deps(ctx, ctx.attr.sig, depsets, manifest)

    for dep in ctx.attr.deps:
        depsets = merge_deps(ctx, dep, depsets, manifest)
    # print("MDEPS DSOS %s" % depsets.deps.cc_dsos)

    for dep in ctx.attr.open:
        depsets = merge_deps(ctx, dep, depsets, manifest)

    if ns_enabled:
        depsets = merge_deps(ctx, nsr_target, depsets, manifest)

    if ctx.attr.ppx:
        depsets = merge_deps(ctx, ctx.attr.ppx, depsets, manifest)
    # input files produced by preprocessor, with codeps
    # (e.g. result of ppx transform)
    if OCamlCodepsProvider in ctx.attr.struct:
        depsets = merge_deps(ctx, ctx.attr.struct, depsets, manifest)

    for ccdep in ctx.attr.cc_deps:
        depsets = merge_deps(ctx, ccdep, depsets, manifest)

    if debug_ccdeps:
        print("CCINFOS")
        for cc in depsets.ccinfos:
            dump_CcInfo(ctx, cc)
            print("x: %s" % ccinfo_to_string(ctx, cc))
            print("Module provides: %s" % cc)

    ############ PPX EXECUTABLE DEPENDENCIES ################
    # ppx_codeps are material deps of this module. They thus become
    # elements in the depgraph of anything that depends on this
    # module, so they are passed on just like regular deps.

    # ppx_codeps are provided either by ctx.attr.ppx or by
    # ctx.attr.struct (or ctx.attr.sig) if those are ppx_transform
    # targets.

    ## Can a ppx_executable also have ordinary deps listed in OCamlDepsProvider?
    ## Don't think so.

    ## But it can carry CcInfo

    ## ppx_modules, that do ppx processing, may have a ppx_codeps
    ## attribute, for the deps they inject into the files they
    ## preprocess. They are _NOT_ material deps of the module itself.
    ## It follows that they are passed on in a OCamlCodepsProvider, not
    ## in OCamlDepsProvider.

    #     ## to ppx a module:
    #     ## 1. ppx tranform src - done above
    #     ## 2. extract ppx_codeps from the ppx.exe
    #     ## 3. add them to the module's dependencies
    #     ## 4. compile transformed src, with ppx_codeps
    #     ## 5. provide them, for later linking (e.g. ppx_expect)

    ## ppx_codeps only for ppx executables?
    ## no, for any module included in a ppx_executable
    # if hasattr(ctx.attr, "ppx_codeps"):
    #     for codep in ctx.attr.ppx_codeps:
    #         depsets = aggregate_codeps(ctx, COMPILE_LINK, codep, depsets, manifest)

    # if hasattr(ctx.attr, "ppx_compile_codeps"):
    #     for codep in ctx.attr.ppx_compile_codeps:
    #         depsets = aggregate_codeps(ctx, COMPILE, codep, depsets, manifest)

    # if hasattr(ctx.attr, "ppx_link_codeps"):
    #     for codep in ctx.attr.ppx_link_codeps:
    #         depsets = aggregate_codeps(ctx, LINK, codep, depsets, manifest)

    ################
    includes   = []
    # target_outputs    = [] # just the cmx/cmo files, for DefaultInfo
    action_outputs   = [] # .cmx, .cmi, .o
    default_outputs  = []

    # target outputs excludes .cmx if sig was compiled with -opaque
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
    # module_name = None
    # mlifile = None
    # cmifile = None
    # sig_src = None

    # sig_inputs = None
    # sig_linkargs = None
    # sig_paths = None

    ## FIXME: unify mli/cmi names
    # mli_workfile = None
    # cmi_workfile = None

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

    #FIXME: one way to derive modname
    modname = _resolve_modname(ctx, nsr_provider)
    fname = _resolve_fname(ctx, nsr_provider)

    if debug_modname: print("resolved modname: %s" % modname)

    sig_is_xmo = True

    ppx_src_ml = False

    if ctx.attr.sig:
        ##FIXME: make this a fn
        if debug: print("dyadic module, with sig: %s" % ctx.attr.sig)
        # if debug: print("sig default: %s" % ctx.attr.sig[DefaultInfo])
        # if debug: print("sig in attr? %s" % (OCamlSignatureProvider in ctx.attr.sig))
        # if debug: print("sig ocamlsig: %s" % ctx.attr.sig[OCamlSignatureProvider])
        # if debug: print("sigfile: %s" % ctx.file.sig)

        ## Handlers to deal with ns renaming and ppx
        if OCamlSignatureProvider in ctx.attr.sig:
            ## _handle_source_sig does ppx transform
            cmi_precompiled = True
            (ppx_src_ml, work_ml,
             out_struct,
             work_mli,
             out_cmi,   ## precompiled, possibly symlinked to __obazl
             sig_is_xmo) = _handle_precompiled_sig(ctx, modname, ext)

        else: ################################################
            if debug: print("sigattr is source file")
            ## _handle_source_sig does ppx transform
            cmi_precompiled = False
            (ppx_src_ml, work_ml,
             out_struct,
             work_mli,
             out_cmi,  ## declared output file
             # cmi_precompiled,
             sig_is_xmo) = _handle_source_sig(ctx, modname, ext)

        if debug:
            print("WORK ml: %s" % work_ml)
            print("WORK cmox: %s" % out_struct)
            print("WORK mli: %s" % work_mli)
            print("WORK cmi: %s" % out_cmi)
            print("cmi_precompiled: %s" % cmi_precompiled)
    else: # no sig attr
        if debug:
            print("SINGLETON: no sigfile")
            print("module name: %s" % modname)
        if ctx.attr.ppx: ## no sig, plus ppx
            if debug_ppx: print("ppxing module:")
            ppx_src_ml, work_ml = ppx_transformation(
                ctx.attr._rule, ctx,
                ctx.file.struct, modname + ".ml"
            )
            ## tooling may set _ppx_only to stop processing after ppx:
            # if ctx.attr._ppx_only[BuildSettingInfo].value == True:
            #     return [
            #         DefaultInfo(files = depset(direct=[work_ml])),
            #         OCamlModuleProvider()
            #     ]

            out_cmi = ctx.actions.declare_file(
                scope + fname + ".cmi"
            )
            out_struct = ctx.actions.declare_file(
                scope + fname + ext
            )
        else: ## no sig, no ppx
            work_ml   = ctx.file.struct
            out_cmi = ctx.actions.declare_file(
                scope + fname + ".cmi"
            )
            out_struct = ctx.actions.declare_file(
                scope + fname + ext
            )

    if debug:
        print("scope: %s" % scope)
        print("work_ml: %s" % work_ml)

    #########################
    args = ctx.actions.args()

    _options = get_options(ctx.attr._rule, ctx)

    if "-opaque" in _options:  # ctx.attr.opts:
        xmo = False
    else:
        xmo = True

    if "-bin-annot" in _options:
        f = fname + ".cmt"
        out_cmt = ctx.actions.declare_file(f, sibling = out_struct)
        action_outputs.append(out_cmt)

    # if "-for-pack" in _options:
    #     for_pack = True
    #     _options.remove("-for-pack")
    # else:
    #     for_pack = False

    # if ctx.attr.pack:
    #     args.add("-for-pack", ctx.attr.pack)

    args.add_all(_options)

    # args.add_all(tc_options.compile_opts)

    if (not sig_is_xmo) or "-opaque" in _options:
        module_xmo = False
    else:
        module_xmo = True

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
        if "exec" not in ctx.attr._tags: ##FIXME ???
            default_outputs.append(out_cmi)

    ## out_struct (.cmo or .cmx) must go in action_outputs;
    ## it will also be delivered as a target output,
    ## both in DefaultInfo provider and in
    ## OCamlModuleProvider and OCamlDepsProvider
    action_outputs.append(out_struct)
    default_outputs.append(out_struct)

    if tc.target != "vm":
        out_ofile = ctx.actions.declare_file(
            scope + fname + ".o"
        )
        action_outputs.append(out_ofile)
        if "exec" not in ctx.attr._tags:
            default_outputs.append(out_ofile)
    else: out_ofile = []

    paths_depset  = depset(
        order = dsorder,
        direct = [out_struct.dirname, out_cmi.dirname],
        transitive = depsets.deps.paths
    )
    includes.extend(paths_depset.to_list()) # , before_each="-I")

    codep_paths_depset = depset(
        order = dsorder,
        transitive = depsets.codeps.paths
    )
    includes.extend(codep_paths_depset.to_list())

    # args.add("-absname")

    # for a in archives_depset.to_list():
    #     includes.append(a.dirname)

    # FIXME: -no-alias-deps and -open only required for sibling deps.
    # in case of udr, they break the build?
    # For udrs, open the Foo__ form, not Foo
    if ns_enabled:
        if debug_ns:
            print("NSR_PROVIDER: %s" % nsr_provider)
        args.add("-no-alias-deps")
        args.add("-open", nsr_provider.modname)

    if cmi_precompiled:
        maybe_cmi = [out_cmi]
    else:
        maybe_cmi = []

    if xmo:
        xmo_deps = depsets.deps.astructs
    else:
        xmo_deps = []
    if debug_xmo: print("XMO DEPS: %s" % xmo_deps)

    ## WARNING: pre-5.0.0, cmi file must be in same dir as source
    ## file. >=5 has -cmi-file option.
    if cmi_precompiled:
        # print("VERSION: %s" % tc.version.version)
        # print("MAJOR version: %s" % tc.version.major)

        ## FIXME: version removed from toolchain adapter
        # print("TC.V %s" % tc.version.major)
        if (tc.version.major < 5):
            None # print("TODO")
        else:
            args.add("-cmi-file", out_cmi.path)

    ## NB: for compilation, only cmis are required,
    ## must be in search path and inputs depset
    ## cm structs only needed for xmo.
    ## for linking cm structs on cmd line
    ## so we pass them along in Provider.

    # for t in ctx.attr.open:
    #     print("OPENS: %s" % t[OCamlModuleProvider].modname)

    open_inputs = []
    if ctx.attr.open:
        for dep in ctx.attr.open:
            if OCamlModuleProvider in dep:
                open_inputs.append(dep[OCamlModuleProvider].cmi)
            elif OCamlNsResolverProvider in dep:
                open_inputs.append(dep[OCamlNsResolverProvider].cmi)
            # open_inputs.append(dep[OCamlModuleProvider].struct)

    # fail(depsets.deps.link_archives_deps)

    action_inputs_depset = depset(
        order = dsorder,
        direct = src_inputs
        + maybe_cmi
        + open_inputs
        ## omit direct deps, they're outputs of this action

        ## NB: we don't need cmx/cmo deps to _compile_ a module
        ## at worst we'll get warning 58 about not using -opaque(???)

        # + ns_resolver_files
        + ctx.files.deps_runtime
        ,
        transitive = # sigs_depsets
         # indirect_ppx_codep_depsets
        # + [ppx_codep_structset]
        # + [depset(direct=archives)]
         # ns_deps
        xmo_deps
        ## including archived cmx prevents warning 58
        ## do NOT include cmx if target == vm
        ## WARNING: only for module compilation; do not include for linking
        ## TODO: reconcile archive processing with xmo

        + depsets.deps.sigs
        + depsets.deps.cli_link_deps
        # + depsets.deps.link_archives_deps
        # + depsets.deps.structs
        # + depsets.deps.ofiles
        + depsets.deps.astructs
        + depsets.deps.archives ## FIXME: redundant (cli_link_deps)
        + depsets.deps.afiles
        ## module compilation never depends on cclibs
        # + bottomup_ns_inputs
        + depsets.codeps.sigs
        + depsets.codeps.cli_link_deps
        + depsets.codeps.link_archives_deps
        + depsets.codeps.structs
        + depsets.codeps.ofiles
        + depsets.codeps.astructs
        + depsets.codeps.archives ## FIXME: redundant (cli_link_deps)
        + depsets.codeps.afiles
    )

    # isnt't this already done using paths depsets?
    # for dep in action_inputs_depset.to_list():
    #     includes.append(dep.dirname)

    args.add_all(includes, before_each="-I", uniquify = True)

    if ctx.attr.open:
        for dep in ctx.attr.open:
            if OCamlModuleProvider in dep:
                args.add("-open", dep[OCamlModuleProvider].modname)
            elif OCamlNsResolverProvider in dep:
                args.add("-open", dep[OCamlNsResolverProvider].modname)

    if work_mli and not cmi_precompiled: # sig_src:
        args.add("-I", work_mli.dirname) # sig_src.dirname)

        args.add("-c")
        ## WARNING: cannot use both -c and -o with multiple input files
        # args.add("-o", out_struct)
        # args.add("-intf", sig_src)

        args.add(work_mli) # sig_src)

        # args.add("-impl", structfile)
        # args.add(in_structfile) # structfile)
        args.add(work_ml) # structfile)
    else:
        args.add("-c")
        args.add("-impl", work_ml) # in_structfile) # structfile)
        args.add("-o", out_struct)

    if debug:
        print("COMPILE OUTPUTS: %s" % action_outputs)

    # strings for progress msg
    if hasattr(ctx.attr, "ppx_codeps"):
        mnemonic = "CompileOCamlPpxModule"
        rule     = "ppx_module"
    elif ctx.attr._rule == "ocaml_module":
        mnemonic = "CompileOCamlModule"
        rule     = "ocaml_module"
    else:
        mnemonic = "CompileOCamlExecModule"
        rule     = "ocaml_exec_module"

    if ctx.label.workspace_name == ctx.workspace_name:
        ws_name = ""
    else:
        ws_name = "@" + ctx.label.workspace_name if ctx.label.workspace_name else "" # "@" + ctx.workspace_name


    # if ctx.attr.dflag == "dlambda":
    #     # run ocaml<> -dlambba
    # elif:  ctx.attr.dflag == "dcmm":
    #     # ocamlopt -dcmm
    # elif:  ...
    # else:
    #     # compile

    ################
    ctx.actions.run(
        # env = {"MACOSX_DEPLOYMENT_TARGET": "13.1"},
        executable = tc.compiler,
        arguments = [args],
        inputs    = action_inputs_depset,
        outputs   = action_outputs,
        tools = [tc.compiler], # + tool_args,
        mnemonic = mnemonic,
        progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
            mode = tc.host + ">" + tc.target,
            rule = rule,
            ws = ws_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )

    #########################
    ##  construct providers
    #########################

    ## RUNFILES

    ## PPX: if this module transformed by ppx_expect or ppx_inline:
    if "-inline-test-lib" in ctx.attr.ppx_args:
        # fail("work_ml: %s" % work_ml)
        ppx_runfiles = ctx.runfiles(
            files = [ppx_src_ml] if ppx_src_ml else [],
            # for ppx_expect, which embeds the path in srcs:
            symlinks = {ppx_src_ml.path: ppx_src_ml},
            # just in case?
            root_symlinks = {ppx_src_ml.path: ppx_src_ml}
        )
    else:
        ppx_runfiles = ctx.runfiles()

    ## FIXME: also handle ctx.attr.data, ctx.attr.ppx_data runfiles

    default_depset = depset(
        order = dsorder,
        direct = [out_struct]
        # direct = [out_cmi, out_struct, out_ofile]
        # direct = default_outputs
    )

    defaultInfo = DefaultInfo(
        files = default_depset,
        runfiles = ppx_runfiles.merge_all(depsets.deps.runfiles)
    )

    outputGroup_all_depset = depset(
        order  = dsorder,
        direct = action_outputs + [out_cmi] #cmi_out ## + mli_out,
    )

    sigs_depset = depset(order=dsorder,
                         direct = [out_cmi],
                         transitive = depsets.deps.sigs)
    if debug_deps: print("SIGS_depset: %s" % sigs_depset)

    new_sigs_depset = depset(
        order = dsorder,
        direct = [out_cmi]
        # ns_resolver_files
        + ctx.files.deps_runtime,
        transitive = [sigs_depset]
        # + [sig_depset] ## action_outputs
        # + indirect_ppx_codep_depsets
        # + ns_deps
        # + bottomup_ns_inputs
    )

    astructs_depset = depset(
        order  = dsorder,
        # direct = direct_astruct,
        transitive = depsets.deps.astructs
    )

    #   if this module in manifest (i.e. will be archived):
    #     do NOT add this module to cli_link_deps
    #     DO add merged link_deps of this module's deps
    this_link_dep = []
    if len(manifest) > 0: #NB: only if namespaced, not for std libs/archives
        print("MANIFEST: %s" % manifest)
        print("LABEL: %s" % ctx.label)
        # if ctx.label.name == "Red":
        #     fail()
        ##FIXME: only for archives, not for libs
        #FIXME: won't work if module name not derived from label
        if not str(ctx.label) in manifest:
            #FIXME: if not archived
            this_link_dep.append(out_struct)
        else:
            this_link_dep.append(out_struct)
    else:
        this_link_dep.append(out_struct)

    cli_link_depset = depset(
        order=dsorder,
        direct = this_link_dep,
        transitive = depsets.deps.cli_link_deps
    )

    link_archives_depset = depset(
        order=dsorder,
        # direct = this_link_dep,
        transitive = depsets.deps.link_archives_deps
    )

    structs_depset = depset(
        order=dsorder,
        # FIXME: out_struct only if not archived
        direct = [out_struct],
        transitive = depsets.deps.structs
    )
    # if debug_deps: print("STRUCTS_depset: %s" % structs_depset)

    ofiles_depset = depset(
        order = dsorder,
        direct=[out_ofile] if out_ofile else [],
        transitive = depsets.deps.ofiles
    )
    if debug_deps: print("OFILES_depset: %s" % ofiles_depset)

    archives_depset = depset(
        order=dsorder, transitive = depsets.deps.archives
    )
    if debug_deps: print("ARCHIVES_depset: %s" % archives_depset)

    afiles_depset = depset(
        order=dsorder, transitive = depsets.deps.afiles
    )
    if debug_deps: print("ARFILES_depset: %s" % afiles_depset)

    srcs_depset = depset(
        order=dsorder,
        direct = [ctx.file.struct],
        transitive = depsets.deps.srcs
    )

    if len(depsets.deps.cmxs) == 0:
        # print(ctx.label)
        # fail(depsets.deps.cmxs)
        cmxs_depset = depset()
    else:
        # print(ctx.label)
        # print(depsets.deps.cmxs)
        cmxs_depset = depset(
            order=dsorder,
            # direct = [ctx.file.struct],
            transitive = depsets.deps.cmxs
        )

    if len(depsets.deps.cmts) == 0:
        # print(ctx.label)
        # fail(depsets.deps.cmts)
        cmts_depset = depset()
    else:
        # print(ctx.label)
        # print(depsets.deps.cmts)
        cmts_depset = depset(
            order=dsorder,
            # direct = [ctx.file.struct],
            transitive = depsets.deps.cmts
        )

    if len(depsets.deps.cmtis) == 0:
        cmtis_depset = depset()
    else:
        cmtis_depset = depset(
            order=dsorder,
            transitive = depsets.deps.cmtis
        )

    if depsets.deps.cc_dsos != None:
        # print("CCDSOS %s" % depsets.deps.cc_dsos)
        cc_dsos_depset = depset(
            transitive = depsets.deps.cc_dsos
        )
    else:
        cc_dsos_depset = []

    ocamlModuleProvider = OCamlModuleProvider(
        modname = modname,
        cmi      = out_cmi,  ## no need for a depset for one file?
        struct   = out_struct,
        xmo      = module_xmo,
        label_name = ctx.label.name,
        namespaced = ns_enabled,
        ns_resolver = nsr_target if ns_enabled else None,
    )

    ocamlDepsProvider = OCamlDepsProvider(
        modname = modname,
        # cmi      = out_cmi,  ## no need for a depset for one file?
        # sig      = out_cmi,
        # struct   = out_struct,
        xmo      = module_xmo,
        sigs     = new_sigs_depset,
        cli_link_deps = cli_link_depset,
        link_archives_deps = link_archives_depset,
        archives = archives_depset,
        afiles   = depset(
            order=dsorder,
            transitive = depsets.deps.afiles
        ),
        astructs = astructs_depset,
        # unarchived structs
        structs  = structs_depset, # new_structs_depset,
        ofiles   = ofiles_depset,
        srcs = srcs_depset,
        cmxs = cmxs_depset,
        cmts = cmts_depset,
        cmtis = cmtis_depset,

        jsoo_runtimes = None if (len(depsets.deps.jsoo_runtimes) == 0) else depsets.deps.jsoo_runtimes,
        # jsoo_runtimes = depset(
        #     order=dsorder,
        #     direct = None if (len(depsets.deps.jsoo_runtimes) == 0) else depsets.deps.jsoo_runtimes
        # ),

        # linkargs = linkset,
        paths    = paths_depset,

        cc_dsos  = cc_dsos_depset,
    )
    # print("MPRovider: %s" % ocamlDepsProvider)

    ########################################################
    providers = [
        defaultInfo,
        ocamlModuleProvider,
        ocamlDepsProvider,
    ]

    ## FIXME: make this conditional:
    ## if this module is a submodule in a namespace:
    # if nsr_target:
    #     print("MODULE NS_RESOLVER: %s" % nsr_target)
    # else:
    #     print("NO MODULE NS_RESOLVER: %s" % nsr_target)

    if ctx.attr.ns:  ## bottomup
        resolver = ctx.attr.ns
        if debug:
            print("attr.ns: %s" % resolver)
            print("resolver: %s" % resolver[OCamlNsResolverProvider])
        nsresolver_depset = depset(
            transitive = [resolver[DefaultInfo].files]
        )

        nsSubmoduleMarker = OcamlNsSubmoduleMarker(
            ns_fqn = resolver[OCamlNsResolverProvider].ns_fqn
        )
        providers.append(nsSubmoduleMarker)
        # fail("XXXXXXXXXXXXXXXX")

        nsResolverProvider = OCamlNsResolverProvider(
            files = ctx.attr._ns_resolver.files,
            paths = depset([d.dirname for d in ctx.attr._ns_resolver.files.to_list()])
        )
    else:
        nsresolver_depset = depset()

    # print("RESOLVER PROVIDER: %s" % nsResolverProvider)

    ## if this is a ppx module, its ppx_codeps (direct or indirect)
    ## must be passed to any ppx_executable that depends on it.
    ## FIXME: make this conditional:
    ## if module has direct or indirect ppx_codeps:

    if (ctx.attr.ppx or
        (hasattr(ctx.attr,"ppx_codeps") and ctx.attr.ppx_codeps)):
        ## ppx_module may have attr ppx_codeps

        if debug_ppx:
            print("Constructing OCamlCodepsProvider: %s" % ctx.label)

        # if ctx.attr.ppx:
        #     if OCamlCodepsProvider in ctx.attr.ppx:
        #         depsets = aggregate_codeps(ctx, COMPILE_LINK, ctx.attr.ppx, depsets, manifest)

        ppxCodepsProvider = OCamlCodepsProvider(
            # ppx_codeps = ppx_codeps_depset,
            sigs    = depset(order=dsorder,
                             transitive=depsets.codeps.sigs),
            cli_link_deps = depset(
                order=dsorder,
                transitive = depsets.codeps.cli_link_deps),
            link_archives_deps = depset(
                order=dsorder,
                transitive = depsets.codeps.link_archives_deps),
            structs    = depset(order=dsorder,
                                transitive=depsets.codeps.structs),
            ofiles    = depset(order=dsorder,
                               transitive=depsets.codeps.ofiles),
            archives    = depset(order=dsorder,
                                 transitive=depsets.codeps.archives),
            afiles    = depset(order=dsorder,
                               transitive=depsets.codeps.afiles),
            astructs    = depset(order=dsorder,
                                 transitive=depsets.codeps.astructs),
            paths    = depset(order=dsorder,
                                 transitive=depsets.codeps.paths),
        )
        if debug_ppx:
            print("appending OCamlCodepsProvider: %s" % ppxCodepsProvider)
        providers.append(ppxCodepsProvider)

    ccInfo = cc_common.merge_cc_infos(
        cc_infos = depsets.ccinfos
    )
    providers.append(ccInfo)

    # ccSharedLibInfo = cc_common.merge_cc_sharedlibinfos(
    #     cc_infos = depsets.ccsharedlibinfos
    # )
    # providers.append(ccSharedLibInfo)

    ################
    outputGroupInfo = OutputGroupInfo(
        # cc         = ccInfo.linking_context.linker_inputs.libraries,
        # cmi       = sig_depset,
        sig       = depset(direct = [out_cmi]),
        struct    = depset(direct = [out_struct]),

        # ml = depset(direct = [work_ml]),

        sigs      = new_sigs_depset,
        structs   = structs_depset,  #new_structs_depset,
        ofiles    = ofiles_depset,
        archives  = archives_depset,
        afiles    = afiles_depset,
        astructs = astructs_depset,
        ns = nsresolver_depset,
        srcs = srcs_depset,
        cli_links = cli_link_depset,
        link_archives = link_archives_depset,
        ## put these in OCamlCodepsProvider?
        # ppx_codeps = ppx_codeps_depset,
        # cc = action_inputs_ccdep_filelist,
        closure = structs_depset,  #new_structs_depset,
        all = depset(
            order = dsorder,
            transitive=[
                nsresolver_depset,
                default_depset,
                outputGroup_all_depset,
                # ppx_codeps_depset,
                # depset(action_inputs_ccdep_filelist)
            ]
        )
    )

    providers.append(outputGroupInfo)

    return providers
