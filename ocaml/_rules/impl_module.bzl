load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
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

    opaque = False

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

        opaque = sigProvider.opaque

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
               work_mli, work_cmi, True, # cmi_isbound = True
               opaque)

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
               work_mli, work_cmi, False, # cmi_isbound = False
               False) # opaque determined by opt

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
    debug_ppx= False

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
    #     tc = ctx.toolchains["@rules_ocaml//toolchain:type"]
    #     if mode == "native":
    #         exe = tc.ocamlopt.basename
    #     else:
    #         exe = tc.ocamlc.basename

    ext  = ".cmx" if  mode == "native" else ".cmo"

    if mode == "native":
        struct_extensions = ["cmxa", "cmx"]
    else:
        struct_extensions = ["cma", "cmo"]

    ################
    includes   = []
    default_outputs    = [] # just the cmx/cmo files, for efaultInfo
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

    work_ml   = None
    work_cmox = None
    work_o    = None
    work_mli  = None
    work_cmi  = None
    cmi_isbound = False ## is cmi already produced by sig dep?

    modname = _resolve_modname(ctx)
    if debug: print("resolved module name: %s" % modname)

    #### INDIRECT DEPS first ####
    # these are "indirect" from the perspective of the consumer
    cdeps_depsets = []
    ldeps_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    sig_is_opaque = False

    if ctx.attr.sig:
        ##FIXME: make this a fn
        if debug: print("dyadic module, with sig: %s" % ctx.attr.sig)

        ## NB: should handle ppx:
        (work_ml, work_cmox, work_o,
         work_mli, work_cmi,
         cmi_isbound, sig_is_opaque) = _sig_make_work_symlinks(
            ctx, modname, mode
        )

        ## now sig deps:
        if OcamlSignatureProvider in ctx.attr.sig:
            if debug: print("sigdep: compiled")
            sig_attr = ctx.attr.sig
            sig_inputs = sig_attr[OcamlProvider].inputs
            sig_linkargs = sig_attr[OcamlProvider].linkargs
            sig_paths = sig_attr[OcamlProvider].paths

            cdeps_depsets.append(sig_inputs)
            ldeps_depsets.append(sig_inputs)
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

    #########################
    args = ctx.actions.args()

    args.add_all(tool_args)

    _options = get_options(ctx.attr._rule, ctx)
    # if "-for-pack" in _options:
    #     for_pack = True
    #     _options.remove("-for-pack")
    # else:
    #     for_pack = False

    # if ctx.attr.pack:
    #     args.add("-for-pack", ctx.attr.pack)

    args.add_all(_options)

    if debug:
        print("SIG_IS_OPAQUE? %s" % sig_is_opaque)

    if sig_is_opaque or "-opaque" in _options:
        module_opaque = True
    else:
        module_opaque = False

    if debug:
        print("MODULE OPAQUE? %s" % module_opaque)

    # work_cmox = None
    # work_o    = None
    # # work_mli  = None
    # # work_cmi  = None
    # cmi_isbound = False

    ## src_inputs: struct file plus cmi if we got it plus mli

    src_inputs = [work_ml]
    if work_mli: src_inputs.append(work_mli)
    if cmi_isbound:
        ## we got cmi from sig dependency
        src_inputs.append(work_cmi)

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
    ppx_codep_cdeps      = []
    ppx_codep_ldeps      = []
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

    # if ctx.attr._rule.startswith("bootstrap"):
    #         args.add(tc.ocamlc)

    ## FIXME: support -bin-annot
    # if "-bin-annot" in _options: ## Issue #17
    #     out_cmt = ctx.actions.declare_file(scope + paths.replace_extension(module_name, ".cmt"))
    #     action_outputs.append(out_cmt)

    ################ Direct Deps ################
    the_deps = ctx.attr.deps + ctx.attr.open
    # the_deps = []
    # the_deps.extend(ctx.attr.deps) # + [ctx.attr._ns_resolver]

    ccInfo_list = []

    dep_is_opaque = False

    if debug:
        print("iterating deps")

    for dep in the_deps:
        if CcInfo in dep:
            # if ctx.label.name == "Main":
            #     dump_CcInfo(ctx, dep)
            ccInfo_list.append(dep[CcInfo])

        ## dep's DefaultInfo.files depend on OcamlProvider.linkargs,
        ## so add the latter before the former

        ## module deps have opaque flag
        ## aggregates do not
        ## so when we find an aggregate we must iterate over it

        if OcamlProvider in dep:

            if hasattr(dep[OcamlProvider], "opaque"):
                if debug:
                    print("THIS: %s" % ctx.label)
                    # print("DEP CMI_OPAQUE: %s" % dep[OcamlProvider].cmi_opaque)
                    # print("DEP.cmi: %s" % dep[OcamlProvider].cmi)
                    # print("DEP: %s" % dep[OcamlProvider])
                    print("")

                # depending on opaque means...
                if dep[OcamlProvider].opaque:
                    if debug:
                        print("DEP is opaque: %s" % dep[OcamlProvider].cdeps)
                    dep_is_opaque = True
                    cdeps_depsets.append(dep[OcamlProvider].cmi)
                    cdeps_depsets.append(dep[OcamlProvider].cdeps)
                    ldeps_depsets.append(dep[OcamlProvider].ldeps)
                else:
                    cdeps_depsets.append(dep[OcamlProvider].cdeps)
                    ldeps_depsets.append(dep[OcamlProvider].ldeps)
            else:
                if debug:
                    if OcamlImportMarker in dep:
                        print("dep[OcamlImportMarker] %s" % dep)
                    if OcamlNsResolverProvider in dep:
                        print("dep[OcamlNsResolverProvider] %s" % dep)
                    if OcamlNsMarker in dep:
                        print("dep[OcamlNsMarker]")
                    print("dep[OcamlProvider] %s" % dep)
                    if OcamlArchiveMarker in dep:
                        print("dep[OcamlArchiveMarker] %s" % dep)
                        print("  dep: %s" % dep[OcamlProvider])
                    if OcamlLibraryMarker in dep:
                        print("dep[OcamlLibraryMarker] %s" % dep)
                        print("  dep: %s" % dep[OcamlProvider])
                    # if not OcamlLibraryMarker in dep:
                    ##FIXME: also check for OcamlArchiveMarker?

                cdeps_depsets.append(dep[OcamlProvider].cdeps)
                ldeps_depsets.append(dep[OcamlProvider].ldeps)

            indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
            indirect_paths_depsets.append(dep[OcamlProvider].paths)

        indirect_linkargs_depsets.append(dep[DefaultInfo].files)

    if debug:
        print("finished deps iteration")
        print("indirect_linkargs_depsets: %s" % indirect_linkargs_depsets)

    ################ Signature Dep ################
    ## FIXME: this logic does not work if we needed to
    ## symlink split sigfiles into working dir
    # if ctx.attr.sig:
    #     if sig_inputs:
    #         cdeps_depsets.append(sig_inputs)
    #         indirect_linkargs_depsets.append(sig_linkargs)
    #         indirect_paths_depsets.append(sig_paths)

    ################ PPX Co-Deps ################
    ## ppx_codeps of the ppx executable are material deps of this
    ## module. They thus become elements in the depgraph of anything
    ## that depends on this module, so they are passed on just like
    ## regular deps.

    ## Modules that do ppx processing may have a ppx_codeps attribute,
    ## for the deps they inject into the files they preprocess. They
    ## are _NOT_ material deps of the module itself. It follows that
    ## they are passed on in a PpxCodepsProvider, not in
    ## OcamlProvider.

    ppx_codeps_list = []

    if ctx.attr.ppx:
        if debug_ppx:
            print("attr.ppx: %s" % ctx.attr.ppx)

        if PpxCodepsProvider in ctx.attr.ppx:
            if debug_ppx:
                # print("ctx.attr.ppx[PpxCodepsProvider] %s"
                #       % ctx.attr.ppx[PpxCodepsProvider])
                print("ctx.attr.ppx[PpxCodepsProvider].linkset: %s"
                      % ctx.attr.ppx[PpxCodepsProvider].linkset)
                print("ctx.attr.ppx[PpxCodepsProvider].ppx_codeps: %s"
                      % ctx.attr.ppx[PpxCodepsProvider].ppx_codeps)

            ppx_codeps_info = ctx.attr.ppx[PpxCodepsProvider]

            ## 1. put ppx_codeps in search path with -I
            ## 2. add ppx_codeps.linkset to linkset of module,
            ## otherwise linking an executable will fail with: "No
            ## implementations provided for the following modules:..."
            indirect_linkargs_depsets.append(ppx_codeps_info.linkset)
            indirect_ppx_codep_depsets.append(ppx_codeps_info.ppx_codeps)
            indirect_ppx_codep_path_depsets.append(ppx_codeps_info.paths)
            ppx_codep_cdeps.extend(ppx_codeps_info.cdeps)
            ppx_codep_ldeps.extend(ppx_codeps_info.ldeps)

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

    ppx_codep_ldepset = depset(transitive=ppx_codep_ldeps)
    # print("ppx_codep_ldepset: %s" % ppx_codep_ldepset)

    archives = []
    linkargs = depset(transitive=indirect_linkargs_depsets)
    if debug: print("LINKARGS: %s" % linkargs)
    for larg in linkargs.to_list():
        if larg.extension in struct_extensions:
            archives.append(larg)
            args.add(larg.path)
            includes.append(larg.dirname)

    # for cdep in cdeps_depsets:
    #     for cd in cdep.to_list():
    #         args.add("-I", cd.dirname)

    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = indirect_paths_depsets + indirect_ppx_codep_path_depsets
    )

    includes.extend(paths_depset.to_list()) # , before_each="-I")
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
        ns_deps = [ns_resolver[OcamlProvider].ldeps] # inputs]
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
    # print("cdeps_depsets: %s" % cdeps_depsets)

    # if debug_ppx:
    #     # for dep in inputs_depset.to_list():
    #     # for dset in indirect_ppx_codep_depsets:
    #     for dset in ppx_codep_ldeps:
    #         for d in dset.to_list():
    #             print("PPX IDEP: %s" % d)

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

        transitive = cdeps_depsets
        + indirect_ppx_codep_depsets
        + [ppx_codep_ldepset]
        + [depset(direct=archives)]
        + ns_deps
        + bottomup_ns_inputs
    )
    if debug:
        for dep in inputs_depset.to_list():
            print("IDEP: %s" % dep.path)

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

    new_cdeps_depset = depset(
        order = dsorder,
        direct = ## src_inputs
        ns_resolver_files
        + ctx.files.deps_runtime,
        transitive = cdeps_depsets
        + [cmi_depset] ## action_outputs
        + indirect_ppx_codep_depsets
        + ns_deps
        + bottomup_ns_inputs
    )

    ## same as inputs_depset except structfile omitted
    new_ldeps_depset = depset(
        order = dsorder,
        direct = src_inputs
        + action_outputs #FIXME: omit cmx?
        + ns_resolver_files
        + ctx.files.deps_runtime,
        transitive = ldeps_depsets ## cdeps_depsets
        + indirect_ppx_codep_depsets
        + ns_deps
        + bottomup_ns_inputs
    )

    # if debug:
    #     print("CLOSURE: %s" % new_ldeps_depset)

    linkset    = depset(transitive = indirect_linkargs_depsets)

    fileset_depset = depset(
        direct= action_outputs + cmi_out + mli_out,
        transitive = bottomup_ns_fileset
    )

    ocamlProvider = OcamlProvider(
        # files = ocamlProvider_files_depset,
        cmi      = depset(direct = [work_cmi]), # [cmifile]),
        opaque   = module_opaque,
        fileset  = fileset_depset,
        inputs   = new_ldeps_depset,
        cdeps    = new_cdeps_depset,
        ldeps    = new_ldeps_depset,
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
                       transitive = indirect_ppx_codep_path_depsets),
        ldeps = ppx_codep_ldepset
    )
    providers.append(ppxCodepsProvider)

    ## now merge ccInfo list
    if ccInfo_list:
        ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        providers.append(ccInfo )

    ################
    outputGroupInfo = OutputGroupInfo(
        # cc         = ccInfo.linking_context.linker_inputs.libraries,
        cmi        = cmi_depset,
        fileset    = fileset_depset,
        linkset    = linkset,
        cdeps      = new_cdeps_depset,
        ldeps      = new_ldeps_depset,
        ppx_codeps = ppx_codeps_depset,
        # cc = action_inputs_ccdep_filelist,
        closure = new_ldeps_depset,
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
