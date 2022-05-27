load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "OcamlProvider",

     "OcamlModuleMarker",
     "OcamlNsResolverProvider",
     "OcamlNsSubmoduleMarker",
     "OcamlSignatureProvider")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",

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

load(":impl_ccdeps.bzl", "link_ccdeps", "dump_CcInfo")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir"
     )

scope = tmpdir

########################
def _sig_make_work_symlinks(ctx, modname, mode):
    # we always link ml/mli/cmi under modname to workdir
    # so we return (work_ml, work_mli, work_cmi)
    # all are symlinked, to be listed as compile action inputs,
    # none as compile action outputs

    debug = False
    if debug: print("_sig_make_work_symlinks")

    ext  = ".cmx" if  mode == "native" else ".cmo"

    if OcamlSignatureProvider in ctx.attr.sig:
        if debug:
            print("sigattr is compiled .cmi")
            print("ctx.attr.sig: %s" % ctx.attr.sig)

        sigProvider = ctx.attr.sig[OcamlSignatureProvider]
        # cmifile = sigProvider.cmi
        # cmi_workfile = cmifile
        # old_cmi = [cmifile]
        # mlifile = sigProvider.mli
        # mli_workfile = mlifile

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

        if tgt_pkgdir == sig_pkgdir:
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
            if debug: print("ppx xforming:")
            work_ml = impl_ppx_transform(
                ctx.attr._rule, ctx,
                ctx.file.struct, modname + ".ml"
            )

        else:
            if debug: print("no ppx")
            work_ml = ctx.actions.declare_file(
                # scope + ctx.file.struct.basename
                scope + modname + ".ml"
            )
            ctx.actions.symlink(output = work_ml, target_file = ctx.file.struct)

        work_cmox = ctx.actions.declare_file(
            scope + modname + ext
        )
            ## no symlink, cmox output by compile action

        if mode == "native":
            work_o = ctx.actions.declare_file(
                scope + modname + ".o"
            )
        else:
            work_o = None
        ## no symlink, .o output by compile action

        return(work_ml, work_cmox, work_o,
               work_mli, work_cmi, True) # cmi_isbound = True

    else: ################################################
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

        work_cmox = ctx.actions.declare_file(
            scope + modname + ext
        )
        ## no symlink, cmox output by compile action

        if mode == "native":
            work_o = ctx.actions.declare_file(
                scope + modname + ".o"
            )
        else: work_o = None
        ## no symlink, .o output by compile action

        return(work_ml, work_cmox, work_o,
               work_mli, work_cmi, False) # cmi_isbound = False

########################
def _resolve_modname(ctx):
    # print("_resolve_modname")

    debug = False

    # if ctx.label.name[:1] == "@":
    # if ctx.attr.forcename: ## FIXME: ctx.attr.module, name string
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
def impl_module(ctx, mode, tool, tool_args):

    # print("host_platform frag: %s" % ctx.fragments.platform.host_platform)
    # print("platform frag: %s" % ctx.fragments.platform.platform)
    ## both: => @local_config_platform//:host
    ## which references @local_config_platform//:constraints.bzl:
    ## which contains

# # DO NOT EDIT: automatically generated constraints list for local_config_platform
# # Auto-detected host platform constraints.
# HOST_CONSTRAINTS = [
#   '@platforms//cpu:x86_64',
#   '@platforms//os:osx',
# ]


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

    debug = False

    if debug:
        print("===============================")
        print("MODULE %s" % ctx.label)

    if hasattr(ctx.attr, "ppx_tags"):
        if len(ctx.attr.ppx_tags) > 1:
            fail("Only one ppx_tag allowed currently.")

    # env = {"PATH": get_sdkpath(ctx)}

    # mode = ctx.attr._mode[CompilationModeSettingProvider].value

    # if ctx.attr._rule.startswith("bootstrap"):
    #     tc = ctx.toolchains["@rules_ocaml//ocaml/bootstrap:toolchain"]
    #     if mode == "native":
    #         exe = tc.ocamlrun
    #     else:
    #         ext = ".cmo"
    # else:
    #     tc = ctx.toolchains["@rules_ocaml//ocaml:toolchain"]
    #     if mode == "native":
    #         exe = tc.ocamlopt.basename
    #     else:
    #         exe = tc.ocamlc.basename

    ext  = ".cmx" if  mode == "native" else ".cmo"

    ################
    includes   = []
    default_outputs    = [] # just the cmx/cmo files, for efaultInfo
    action_outputs   = [] # .cmx, .cmi, .o
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

    work_ml   = None
    work_cmox = None
    work_o    = None
    work_mli  = None
    work_cmi  = None
    cmi_isbound = False ## cmi already produced by sig dep

    modname = _resolve_modname(ctx)
    if debug: print("resolved module name: %s" % modname)

    #### INDIRECT DEPS first ####
    # these are "indirect" from the perspective of the consumer
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    if ctx.attr.sig:
        ##FIXME: make this a fn
        if debug: print("dyadic module, with sig: %s" % ctx.attr.sig)

        ## NB: should handle ppx:
        (work_ml, work_cmox, work_o,
         work_mli, work_cmi,
         cmi_isbound) = _sig_make_work_symlinks(
            ctx, modname, mode
        )

        ## now sig deps:
        if OcamlSignatureProvider in ctx.attr.sig:
            if debug: print("sigdep: compiled")
            sig_attr = ctx.attr.sig
            sig_inputs = sig_attr[OcamlProvider].inputs
            sig_linkargs = sig_attr[OcamlProvider].linkargs
            sig_paths = sig_attr[OcamlProvider].paths

            indirect_inputs_depsets.append(sig_inputs)
            indirect_linkargs_depsets.append(sig_linkargs)
            indirect_paths_depsets.append(sig_paths)
            indirect_paths_depsets.append(
                depset(direct = [work_cmox.dirname, work_cmi.dirname])
            )
        else:
            if debug: print("sigdep: source")

        if debug:
            print("WORK ml: %s" % work_ml)
            print("WORK cmox: %s" % work_cmox)
            print("WORK o: %s" % work_o)
            print("WORK mli: %s" % work_mli)
            print("WORK cmi: %s" % work_cmi)
            print("cmi_isbound: %s" % cmi_isbound)
    else:
        if debug: print("orphaned module: no sigfile")
        if ctx.attr.ppx: ## no sig, plus ppx
            if debug: print("ppx xforming:")
            work_ml = impl_ppx_transform(
                ctx.attr._rule, ctx,
                ctx.file.struct, modname + ".ml"
            )
            work_cmi = ctx.actions.declare_file(
                scope + modname + ".cmi"
            )
            work_cmox = ctx.actions.declare_file(
                scope + modname + ext
            )
            if mode == "native":
                work_o = ctx.actions.declare_file(
                    scope + modname + ".o"
                )
            else: work_o = None

        else: ## no sig, neg ppx
            work_ml   = ctx.file.struct
            work_cmi = ctx.actions.declare_file(
                scope + modname + ".cmi"
            )
            work_cmox = ctx.actions.declare_file(
                scope + modname + ext
            )
            if mode == "native":
                work_o = ctx.actions.declare_file(
                    scope + modname + ".o"
                )
            else: work_o = None


    # work_cmox = None
    # work_o    = None
    # # work_mli  = None
    # # work_cmi  = None
    # cmi_isbound = False



    src_inputs = [work_ml]
    if work_mli: src_inputs.append(work_mli)
    if cmi_isbound: src_inputs.append(work_cmi)

    ################################################################
    if debug:
        print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
        print("%%%% finished ctx.sig handling %%%%")
        # print("in_structfile: %s" % in_structfile)
        # print("src_inputs: %s" % src_inputs)

    if debug:
        if work_cmi:
            print("OUT_CMI: %s" % work_cmi)
            print("cmi_isbound? %s" % cmi_isbound)

    # out_cm_ = ctx.actions.declare_file(scope + module_name + ext)
    #                                    # sibling = new_cmi) # fname)
    # if work_ml:
    out_cm_ = work_cmox
    if debug:
        print("OUT_CM_: %s" % out_cm_)

    if work_cmi and not cmi_isbound:
        action_outputs.append(work_cmi)

    action_outputs.append(out_cm_)
    # direct_linkargs.append(out_cm_)
    default_outputs.append(out_cm_)

    if mode == "native":
        # if not ctx.attr._rule.startswith("bootstrap"):
        # out_o = ctx.actions.declare_file(module_name + ".o",
        #                                  sibling = out_cm_)
        out_o = work_o
        action_outputs.append(out_o)
        # direct_linkargs.append(out_o)

        if debug:
            print("OUT_O: %s" % out_o.path)

    ################
    indirect_ppx_codep_depsets      = []
    indirect_ppx_codep_path_depsets = []
    indirect_cc_deps  = {}

    ## topdown resolver
    ns_resolver = ctx.attr._ns_resolver
    ns_resolver_files = ctx.files._ns_resolver

    ## DEBUG: dump ns resolver provider
    if hasattr(ns_resolver, "ns_name"):
        print("NsResolverProvider:  XXXXXXXXXXXXXXXX")
        print("  ns_name: %s" % ns_resolver.ns_name)
        print("ctx.attr._ns_resolver: %s" % ns_resolver)


    # if ctx.label.name in ["Stdlib", "Stdlib_cmi"]:
    #     print("lbl: %s" % ctx.label.name)
    #     print(" ns_resolver: %s" % ns_resolver)
    #     print(" ns_resolver_files: %s" % ns_resolver_files)

    paths_direct = [out_cm_.dirname] # d.dirname for d in direct_linkargs]
    if ns_resolver:
        # print("RESOLVER PATH: %s" % ns_resolver_files)
        paths_direct.extend([f.dirname for f in ns_resolver_files])

    #########################
    args = ctx.actions.args()

    args.add_all(tool_args)

    # if ctx.attr._rule.startswith("bootstrap"):
    #         args.add(tc.ocamlc)

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

    ################ Direct Deps ################
    the_deps = ctx.attr.deps + ctx.attr.open
    # the_deps = []
    # the_deps.extend(ctx.attr.deps) # + [ctx.attr._ns_resolver]

    ccInfo_list = []

    for dep in the_deps:
        if CcInfo in dep:
            # if ctx.label.name == "Main":
            #     dump_CcInfo(ctx, dep)
            ccInfo_list.append(dep[CcInfo])

        ## dep's DefaultInfo.files depend on OcamlProvider.linkargs,
        ## so add the latter before the former

        if OcamlProvider in dep:

            # if ctx.label.name == "Mempool":
            #     print("DEP: %s" % dep[DefaultInfo].files)
            #     for ds in dep[OcamlProvider].linkargs.to_list():
            #         print("DS: %s" % ds)

            indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
            indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
            indirect_paths_depsets.append(dep[OcamlProvider].paths)

        indirect_linkargs_depsets.append(dep[DefaultInfo].files)

    ################ Signature Dep ################
    ## FIXME: this logic does not work if we needed to
    ## symlink split sigfiles into working dir
    # if ctx.attr.sig:
    #     if sig_inputs:
    #         indirect_inputs_depsets.append(sig_inputs)
    #         indirect_linkargs_depsets.append(sig_linkargs)
    #         indirect_paths_depsets.append(sig_paths)

    ################ PPX Co-Deps ################
    ## ppx_codeps of the ppx executable are structural deps of this
    ## module. They thus become elements in the depgraph of anything
    ## that depends on this module, so they are passed on just like
    ## regular deps.

    ## Modules that do ppx processing may have a ppx_codeps attribute,
    ## for the deps they inject into the files they preprocess. They
    ## are _NOT_ structural deps of the module itself. It follow that
    ## they are passed on in a PpxCodepsProvider, not in
    ## OcamlProvider.

    ppx_codeps_list = []

    if ctx.attr.ppx:
        if PpxCodepsProvider in ctx.attr.ppx:
            ppx_codeps_info = ctx.attr.ppx[PpxCodepsProvider]

            ## 1. put ppx_codeps in search path with -I
            ## 2. add ppx_codeps.linkset to linkset of module,
            ## otherwise linking an executable will fail with: "No
            ## implementations provided for the following modules:..."
            indirect_linkargs_depsets.append(ppx_codeps_info.linkset)

            indirect_ppx_codep_depsets.append(ppx_codeps_info.ppx_codeps)
            indirect_ppx_codep_path_depsets.append(ppx_codeps_info.paths)


        # dlist = ppx_codeps_info.ppx_codeps.to_list()
        # args.add("-ccopt", "-DPPX_ADJUNCTS_START")
        # for f in dlist: ## ppx_codeps_info.files.to_list():
        #     ppx_codeps_list.append(f)
        #     if f.extension in ["cmxa", "a"]:
        #         # if (f.path.startswith(opam_lib_prefix)):
        #         #     dir = paths.relativize(f.dirname, opam_lib_prefix)
        #         #     includes.append( "+../" + dir )
        #         # else:
        #         includes.append(f.dirname)
        # args.add("-ccopt", "-DPPX_ADJUNCTS_END")

        # for path in ppx_codeps_info.paths.to_list():
        #     includes.append(path)

    # if ctx.label.name == "_Hello":
    #     print("PPX_CODEPS depsets:")
    #     print(indirect_ppx_codep_depsets)

    # args.add("-I", "/Users/gar/.opam/4.10/lib/ounit2")
    # args.add("-I", "demos/external/ounit2")

    linkargs = depset(transitive=indirect_linkargs_depsets)
    for larg in linkargs.to_list():
        if larg.extension in ["cmxa", "cmx"]:
            args.add("-I", larg.dirname)

    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = indirect_paths_depsets + indirect_ppx_codep_path_depsets
    )

    args.add_all(paths_depset.to_list(), before_each="-I")
    # args.add("-absname")
    args.add_all(includes, before_each="-I", uniquify = True)

    # if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
    if hasattr(ns_resolver[OcamlNsResolverProvider], "resolver"):

        ## this will only be the case if this is a submodule in an ns
        # print("NS RESOLVER FILES: %s" % ns_resolver_files)
        # args.add(ns_resolver_files[0])

        args.add("-no-alias-deps")
        args.add("-open", ns_resolver[OcamlNsResolverProvider].resolver)

    # attr '_ns_resolver' a label_flag that resolves to a (fixed)
    # ocaml_ns_resolver target whose params are set by transition fns.
    # by default the 'resolver' field is null.

    # if "-shared" in _options:
    #     args.add("-shared")
    # else:

    ## if we rec'd a .cmi sigfile, we must add its SOURCE file to the
    ## inputs dep graph! otherwise the ocaml compiler will not use the cmx
    ## file, it will generate one from the module source.

    # sig_in = [sig_src] if sig_src else []
    # mli_out = [mlifile] if mlifile else []
    if cmi_isbound:
        mli_out = [work_mli] if work_mli else []
        # cmi_out = [cmifile] if cmifile else [] # new_cmi]
        cmi_out = [work_cmi] if work_cmi else [] # new_cmi]
    else:
        mli_out = []
        cmi_out = []

    ## runtime deps must be added to the depgraph (so they get built),
    ## but not the command line (they are not build-time deps).

    if OcamlProvider in ns_resolver:
        # print("LBL: %s" % ctx.label)
        # print("NS RESOLVER: %s" % ns_resolver)
        # print("NS RESOLVER DefaultInfo: %s" % ns_resolver[DefaultInfo])
        # print("NS RESOLVER OcamlProvider: %s" % ns_resolver[OcamlProvider])
        ns_deps = [ns_resolver[OcamlProvider].inputs]
    else:
        ns_deps = []

    ## bottomup ns:
    # if hasattr(ctx.attr, "ns_resolver"):
    if ctx.attr.ns_resolver:
        if debug:
            print("NS lbl: %s" % ctx.label)
            print("ns: %s" % ctx.file.ns_resolver)
        bottomup_ns_resolver = ctx.attr.ns_resolver
        resolver = bottomup_ns_resolver[OcamlNsResolverProvider]
        if debug: print("resolver: %s" % resolver)
        bottomup_ns_files   = [bottomup_ns_resolver[DefaultInfo].files]
        bottomup_ns_inputs  = [bottomup_ns_resolver[OcamlProvider].inputs]
        bottomup_ns_fileset = [bottomup_ns_resolver[OcamlProvider].fileset]
        bottomup_ns_cmi     = [bottomup_ns_resolver[OcamlProvider].cmi]
        bottomup_ns_name    = resolver.ns_name
    else:
        bottomup_ns_resolver = []
        bottomup_ns_files    = []
        bottomup_ns_fileset  = []
        bottomup_ns_inputs   = []
        bottomup_ns_cmi      = []

    # if debug:
    #     print("SRC_INPUTS: %s" % src_inputs)

    # print("SRC_INPUTS: %s" % src_inputs)
    # print("mli_out: %s" % mli_out)
    # print("indirect_inputs_depsets: %s" % indirect_inputs_depsets)
    inputs_depset = depset(
        order = dsorder,
        direct = src_inputs
        # + [in_structfile]
        + mli_out
        + [work_ml]
        + ns_resolver_files
        # + [work_mli]

        # + [sig_src, in_structfile]
        # + mli_out ##
        # + cmi_out
        # + (old_cmi if old_cmi else [])
        + ctx.files.deps_runtime,

        transitive = indirect_inputs_depsets
        + indirect_ppx_codep_depsets
        + ns_deps
        + bottomup_ns_inputs
    )
    # if ctx.label.name == "Misc":
    #     print("inputs_depset: %s" % inputs_depset)

    if ctx.attr.open:
        for dep in ctx.files.open:
            args.add("-open", normalize_module_name(dep.basename))

    if ctx.attr.ns_resolver:
        args.add("-open", bottomup_ns_name)

    args.add("-c")

    if work_mli and not cmi_isbound: # sig_src:
        args.add("-I", work_mli.dirname) # sig_src.dirname)
        # args.add("-intf", sig_src)
        args.add(work_mli) # sig_src)

        # args.add("-impl", structfile)
        # args.add(in_structfile) # structfile)
        args.add(work_ml) # structfile)
    else:
        args.add("-impl", work_ml) # in_structfile) # structfile)
        args.add("-o", out_cm_)

    # if ctx.attr._rule.startswith("bootstrap"):
    #     toolset = [tc.ocamlrun, tc.ocamlc]
    # else:
    #     toolset = [tc.ocamlopt, tc.ocamlc]

    # if debug:
    #     print("COMPILE INPUTS: %s" % inputs_depset)

    if debug:
        print("COMPILE OUTPUTS: %s" % action_outputs)

    ################
    ctx.actions.run(
        # env = env,
        executable = tool,
        arguments = [args],
        inputs    = inputs_depset,
        outputs   = action_outputs,
        tools = [tool] + tool_args,
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

    default_depset = depset(
        order = dsorder,
        direct = default_outputs,
        transitive = bottomup_ns_files
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    ocamlProvider_files_depset = depset(
        order  = dsorder,
        direct = action_outputs + cmi_out + mli_out,
    )

    # new_inputs_depset = depset(
    #     direct = action_outputs,
    #     transitive = [inputs_depset] ## indirect_inputs_depsets
    # )
    ## same as inputs_depset except structfile omitted
    new_inputs_depset = depset(
        order = dsorder,
        direct = src_inputs + action_outputs + ns_resolver_files
        + ctx.files.deps_runtime,
        transitive = indirect_inputs_depsets
        + indirect_ppx_codep_depsets
        + ns_deps
        + bottomup_ns_inputs
    )

    # if debug:
    #     print("CLOSURE: %s" % new_inputs_depset)

    linkset    = depset(transitive = indirect_linkargs_depsets)

    fileset_depset = depset(
        direct= action_outputs + cmi_out + mli_out,
        transitive = bottomup_ns_fileset
    )

    ocamlProvider = OcamlProvider(
        # files = ocamlProvider_files_depset,
        cmi      = depset(direct = [work_cmi]), # [cmifile]),
        fileset  = fileset_depset,
        inputs   = new_inputs_depset,
        linkargs = linkset,
        paths    = paths_depset,
    )

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
    ppx_codeps_depset = depset(
        order = dsorder,
        direct = ppx_codeps_list,
        transitive = indirect_ppx_codep_depsets
    )
    ppxCodepsProvider = PpxCodepsProvider(
        ppx_codeps = ppx_codeps_depset,
        paths = depset(order = dsorder,
                       transitive = indirect_ppx_codep_path_depsets)
    )
    providers.append(ppxCodepsProvider)

    ## now merge ccInfo list
    if ccInfo_list:
        ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        providers.append(ccInfo )

    if work_cmi and not cmi_isbound:
        cmi_depset = depset(
            direct = [work_cmi],
            transitive = bottomup_ns_cmi
        )
    else:
        cmi_depset = depset(
            direct=cmi_out,
            transitive = bottomup_ns_cmi
        )

    ################
    outputGroupInfo = OutputGroupInfo(
        # cc         = ccInfo.linking_context.linker_inputs.libraries,
        cmi        = cmi_depset,
        fileset    = fileset_depset,
        linkset    = linkset,
        # thedeps    = ctx.files.deps,
        ppx_codeps = ppx_codeps_depset,
        # cc = action_inputs_ccdep_filelist,
        closure = new_inputs_depset,
        all = depset(
            order = dsorder,
            transitive=[
                default_depset,
                ocamlProvider_files_depset,
                ppx_codeps_depset,
                # depset(action_inputs_ccdep_filelist)
            ]
        )
    )
    providers.append(outputGroupInfo)

    return providers
