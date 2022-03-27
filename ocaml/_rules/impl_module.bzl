load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "OcamlProvider",
     "PpxAdjunctsProvider",

     "OcamlModuleMarker",
     "OcamlNsResolverProvider",
     "OcamlSignatureProvider")

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
     "normalize_module_name")

load(":impl_ccdeps.bzl", "link_ccdeps", "dump_CcInfo")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir"
     )

scope = tmpdir

#####################
def impl_module(ctx, mode, tool, tool_args):

    debug = False
    if ctx.label.name in ["CamlinternalFormat"]:
        debug = True

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
    #     tc = ctx.toolchains["@ocaml//ocaml:toolchain"]
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

    in_structfile = None
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
    if ctx.attr.sig:
        sig_attr = ctx.attr.sig
        if debug:
            print("SIG attr: %s" % sig_attr)

        # if provided sig is in the same directory as the .ml file,
        # then no special action required.

        # but if the provided sig is "remote", then link the .mli and
        # .cmi files to the work dir. the .ml file will also have been
        # linked there, so everything will be where the compiler
        # expects it.

        if OcamlSignatureProvider in sig_attr:
            if debug: print("sig is compiled cmi")
            # sig is ocaml_signature target providing cmi file
            # derive module name from sigfile
            # for submodules, sigfile name will already contain ns prefix

            sigProvider = sig_attr[OcamlSignatureProvider]
            cmifile = sigProvider.cmi
            cmi_workfile = cmifile
            old_cmi = [cmifile]
            mlifile = sigProvider.mli
            mli_workfile = mlifile

            if debug:
                print("cmifile: %s" % cmifile)
                print("mlifile: %s" % mlifile)

            ## we're given a sig cmi, so we're going to derive the module
            ## name from the signame rather than the structfile name.
            ## cmifile has been ppxed and ns-renamed if necessary
            module_name = cmifile.basename[:-4]

            (from_name, struct_module_name) = get_module_name(ctx, ctx.file.struct)
            if debug:
                print("From {src} To: {dst}".format(
                    src = from_name, dst = struct_module_name))

            ## FIXME: is_source not reliable. mli file could be generated
            # if sigProvider.mli.is_source:
            if ctx.label.name == "Stdlib": # FIXME
                # print("Stdlib: sig not renamed")
                # in_structfile = ctx.file.struct
                in_structfile = ctx.actions.declare_file(scope + ctx.file.struct.basename)
                ctx.actions.symlink(output = in_structfile, target_file = ctx.file.struct)

            if from_name == module_name:
                if debug: print("not namespaced") # was not renamed
                ## matching module names is not enough; the sig files
                ## must be in the same directory as the structfile.
                structpath = paths.dirname(ctx.file.struct.short_path)
                sigpath    = paths.dirname(ctx.file.sig.short_path)
                if debug:
                    print("structpath: %s" % structpath)
                    print("sigpath: %s" % sigpath)
                if sigpath != structpath:
                    ## link sig files into workdir
                    mli_workfile = ctx.actions.declare_file(
                        scope + mlifile.basename
                    )
                    ctx.actions.symlink(
                        output = mli_workfile,
                        target_file = mlifile
                    )
                    cmi_workfile = ctx.actions.declare_file(
                        scope + cmifile.basename
                    )
                    ctx.actions.symlink(
                        output = cmi_workfile,
                        target_file = cmifile
                    )
                    if debug:
                        print("mli_workfile: %s" % mli_workfile)
                        print("cmi_workfile: %s" % cmi_workfile)
                    src_inputs = [cmi_workfile, mli_workfile]
                    includes.append(mli_workfile.dirname)

                if ctx.attr.ppx:
                    in_structfile = impl_ppx_transform(
                        ctx.attr._rule, ctx,
                        ctx.file.struct, module_name + ".ml"
                    )
                else:
                    # link struct src file into working dir
                    in_structfile = ctx.actions.declare_file(scope + ctx.file.struct.basename)
                    ctx.actions.symlink(output = in_structfile, target_file = ctx.file.struct)

            else:
                ################ namespaced or otherwise renamed
                if debug:
                    print("name mismatch:")
                    print("mli filename: %s" % mlifile)
                    print("module_name: %s" % module_name)
                    print("struct_module_name: %s" % struct_module_name)
                    print("from_name: %s" % from_name)
                # so we need to rename structfile to match
                # NB: mlifile must be added to provider output
                if ctx.attr.ppx:
                    if debug: print("ppx xforming:")
                    in_structfile = impl_ppx_transform(
                        ctx.attr._rule, ctx,
                        ctx.file.struct, module_name + ".ml"
                    )
                else:
                    if debug: print("no ppx")
                    in_structfile = ctx.actions.declare_file(
                        scope + module_name + ".ml"
                    )
                    ctx.actions.symlink(
                        output = in_structfile,
                        target_file = ctx.file.struct
                    )
                    # print("renamed structfile {src} => {dest}".format(
                    #     src = ctx.file.struct.path,
                    #     dest = in_structfile
                    # ))
                ## NB: cmifile and mlifile must be kept together,
                ## so both go into inputs (and provided outputs)
                ##FIXME: rename src_inputs -> sig_inputs
                src_inputs = [cmifile, mlifile] # , in_structfile]
                includes.append(mlifile.dirname)

                ## FIXME: this logic does not work if we needed to
                ## symlink split sigfiles into working dir
                sig_inputs = sig_attr[OcamlProvider].inputs
                sig_linkargs = sig_attr[OcamlProvider].linkargs
                sig_paths = sig_attr[OcamlProvider].paths

        else:
            ################################################################
            # ctx.attr.sig does not contain OcamlSignatureProvider
            # which means it does not contain a .cmi file, so it must
            # be a source file. it will be passed directly to the
            # compiler along with the .ml file.
            if debug: print("sig is source file")
            (from_name, module_name) = get_module_name(ctx, ctx.file.sig)
            # print("module_name: %s" % module_name)
            if from_name == module_name:
                if debug:
                    print("not namespaced")
                    print("struct file: %s" % ctx.file.struct.path)
                in_structfile = ctx.actions.declare_file(scope + ctx.file.struct.basename)
                ctx.actions.symlink(output = in_structfile, target_file = ctx.file.struct)
                # print("in_structfile: %s" % in_structfile)
                # print("sig file: %s" % ctx.file.sig.path)
                sig_src = ctx.actions.declare_file(scope + ctx.file.sig.basename)
                ctx.actions.symlink(output=sig_src,
                                    target_file = ctx.file.sig)
                # print("sig_src: %s" % sig_src.path)
                cmi = sig_src.basename[:-4] + ".cmi"
                cmifile = ctx.actions.declare_file(scope + cmi)
                # print("cmi out: %s" % cmifile.path)
                action_outputs.append(cmifile)

                ## NB: cmifile and mlifile must be kept together,
                ## so both go into inputs (and provided outputs)
                src_inputs = [sig_src] # , in_structfile] ## , ctx.file.sig]
            else:
                ## namespaced - symlink to ns-prefixed names
                in_structfile = ctx.actions.declare_file(
                    scope + module_name + ".ml"
                )
                ctx.actions.symlink(
                    output = in_structfile, target_file = ctx.file.struct
                )
                # print("in_structfile: %s" % in_structfile)
                # print("sig file: %s" % ctx.file.sig.path)
                sig_src = ctx.actions.declare_file(
                    scope + module_name + ".mli"
                )
                ctx.actions.symlink(
                    output=sig_src, target_file = ctx.file.sig
                )
                # print("sig_src: %s" % sig_src.path)
                cmi = sig_src.basename[:-4] + ".cmi"
                cmifile = ctx.actions.declare_file(scope + cmi)
                # print("cmi out: %s" % cmifile.path)
                action_outputs.append(cmifile)

                ## NB: cmifile and mlifile must be kept together,
                ## so both go into inputs (and provided outputs)
                src_inputs = [sig_src] #, in_structfile] # , ctx.file.sig]
    else: # not ctx.attr.sig:
        if debug: print("No sigfile")
        (from_name, module_name) = get_module_name(ctx, ctx.file.struct)
        if debug:
            print("module_name: %s" % module_name)
        if from_name == module_name:
            # print("not namespaced")
            if ctx.attr.ppx:
                if debug:
                    print("ppxed")
                in_structfile = impl_ppx_transform(
                    ctx.attr._rule, ctx,
                    ctx.file.struct, module_name + ".ml"
                )
            else:
                if debug:
                    print("no ppx")
                # in_structfile = ctx.file.struct
                in_structfile = ctx.actions.declare_file(scope + ctx.file.struct.basename)
                ctx.actions.symlink(output = in_structfile, target_file = ctx.file.struct)

            cmi = module_name + ".cmi"
            cmifile = ctx.actions.declare_file(scope + cmi)
            # print("cmi out: %s" % cmifile.path)
            action_outputs.append(cmifile)
            src_inputs = [] # in_structfile]
        else:
            # print("namespaced")
            ## renaming input puts it into output dir; not strictly
            # necessary, since w/o an mli file, input can be
            # non-namepaced name and no confusion about cmi file ensues.
            ## but for consistency and clarity, we symlink the input
            ## file to ns-prefixed name in output dir. then we could
            ## omit the -o arg, since compiler writes to its input dir
            ## (which after symlinking is our Bazel output dir).
            # w/o renaming we get stuff like:
            # -c -impl modules/namespaced/green.ml
            #    -o bazel-out/ ... /Color__Green.cmx
            # with renaming:
            # -c -impl bazel-out/darwin-fastbuild/ ... /Color__Green.ml
            #    -o bazel-out/darwin-fastbuild-ST ... /Color__Green.cmx

            if ctx.attr.ppx:
                # print("ppxed")
                in_structfile = impl_ppx_transform(
                    ctx.attr._rule, ctx,
                    ctx.file.struct, module_name + ".ml"
                )
            else:
                # print("no ppx")
                in_structfile = ctx.actions.declare_file(
                    scope + module_name + ".ml"
                )
                ctx.actions.symlink(
                    output = in_structfile, target_file = ctx.file.struct
                )

            cmi = module_name + ".cmi"
            cmifile = ctx.actions.declare_file(scope + cmi)
            # print("cmi out: %s" % cmifile.path)
            action_outputs.append(cmifile)
            src_inputs = [] # in_structfile]

    # end: if ctx.attr.sig ... else
    ################################################################
    if debug:
        print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
        print("%%%% finished ctx.sig handling %%%%")
        print("in_structfile: %s" % in_structfile)
        print("src_inputs: %s" % src_inputs)

    out_cm_ = ctx.actions.declare_file(scope + module_name + ext)
                                       # sibling = new_cmi) # fname)
    # print("OUT_CM_: %s" % out_cm_.path)
    action_outputs.append(out_cm_)
    # direct_linkargs.append(out_cm_)
    default_outputs.append(out_cm_)

    if mode == "native":
        # if not ctx.attr._rule.startswith("bootstrap"):
        out_o = ctx.actions.declare_file(scope + module_name + ".o",
                                         sibling = out_cm_)
        action_outputs.append(out_o)
        # direct_linkargs.append(out_o)

    ################
    indirect_ppx_codep_depsets      = []
    indirect_ppx_codep_path_depsets = []
    indirect_cc_deps  = {}

    ns_resolver = ctx.attr._ns_resolver
    ns_resolver_files = ctx.files._ns_resolver

    # if ctx.label.name in ["Stdlib", "Stdlib_cmi"]:
    #     print("lbl: %s" % ctx.label.name)
    #     print(" ns_resolver: %s" % ns_resolver)
    #     print(" ns_resolver_files: %s" % ns_resolver_files)

    paths_direct = [out_cm_.dirname] # d.dirname for d in direct_linkargs]
    if ns_resolver:
        paths_direct.extend([f.dirname for f in ns_resolver_files])
    # print("RESOLVER PATHS: %s" % paths_direct)

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
    the_deps = []
    the_deps.extend(ctx.attr.deps) # + [ctx.attr._ns_resolver]

    #### INDIRECT DEPS first ####
    # these are "indirect" from the perspective of the consumer
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

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
        ppx_codeps_info = ctx.attr.ppx[PpxAdjunctsProvider]

        ## NB: it seems to be sufficient to put the ppx_codeps in the
        ## search path with -I; the archive itself need not be added?
        ## omitting the path: e.g. "Unbound module Ppx_inline_test_lib"
        ## adding the path makes the compile work.
        ## BUT: the ppx_codeps must be propagated to
        ## ocaml_executable, otherwise the link will fail with:
        ## "No implementations provided for the following modules:..."
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

    # linkargs = depset(transitive=indirect_linkargs_depsets)
    # for larg in linkargs.to_list():
    #     if larg.extension in ["cmxa", "cmx"]:
    #         args.add("-I", larg.dirname)

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

    ## if we rec'd a .cmi sigfile, we must add its SOURCE file to the dep graph!
    ## otherwise the ocaml compiler will not use the cmx file, it will generate
    ## one from the module source.
    # sig_in = [sig_src] if sig_src else []
    # mli_out = [mlifile] if mlifile else []
    mli_out = [mli_workfile] if mli_workfile else []
    # cmi_out = [cmifile] if cmifile else [] # new_cmi]
    cmi_out = [cmi_workfile] if cmi_workfile else [] # new_cmi]

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
    # if hasattr(ctx.attr, "ns"):
    if ctx.attr.ns:
        # print("NS lbl: %s" % ctx.label)
        # print("ns: %s" % ctx.file.ns)
        bottomup_ns_resolver = ctx.attr.ns
        bottomup_ns_files   = [bottomup_ns_resolver[DefaultInfo].files]
        bottomup_ns_inputs  = [bottomup_ns_resolver[OcamlProvider].inputs]
        bottomup_ns_fileset = [bottomup_ns_resolver[OcamlProvider].fileset]
        bottomup_ns_cmi     = [bottomup_ns_resolver[OcamlProvider].cmi]
    else:
        bottomup_ns_resolver = []
        bottomup_ns_files    = []
        bottomup_ns_fileset  = []
        bottomup_ns_inputs   = []
        bottomup_ns_cmi      = []

    # print("bottomup_ns_inputs: %s" % bottomup_ns_inputs)

    if debug:
        print("SRC_INPUTS: %s" % src_inputs)

    inputs_depset = depset(
        order = dsorder,
        direct = src_inputs + [in_structfile] + ns_resolver_files
        + mli_out

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

    args.add("-c")

    if sig_src:
        args.add("-I", sig_src.dirname)
        # args.add("-intf", sig_src)
        args.add(sig_src)

        # args.add("-impl", structfile)
        args.add(in_structfile) # structfile)
    else:
        args.add("-impl", in_structfile) # structfile)
        args.add("-o", out_cm_)

    # if ctx.attr._rule.startswith("bootstrap"):
    #     toolset = [tc.ocamlrun, tc.ocamlc]
    # else:
    #     toolset = [tc.ocamlopt, tc.ocamlc]

    # if debug:
    #     print("INPUTS: %s" % inputs_depset)

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
        cmi      = depset(direct = [cmifile]),
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

    nsResolverProvider = OcamlNsResolverProvider(
        files = ctx.attr._ns_resolver.files,
        paths = depset([d.dirname for d in ctx.attr._ns_resolver.files.to_list()])
    )
    # print("RESOLVER PROVIDER: %s" % nsResolverProvider)
    providers.append(nsResolverProvider)

    ## if this is a ppx module, its ppx_codeps (direct or indirect)
    ## must be passed to any ppx_executable that depends on it.
    ## FIXME: make this conditional:
    ## if module has direct or indirect ppx_codeps:
    ppx_codeps_depset = depset(
        order = dsorder,
        direct = ppx_codeps_list,
        transitive = indirect_ppx_codep_depsets
    )
    ppxCodepsProvider = PpxAdjunctsProvider(
        ppx_codeps = ppx_codeps_depset,
        paths = depset(order = dsorder,
                       transitive = indirect_ppx_codep_path_depsets)
    )
    providers.append(ppxCodepsProvider)

    ## now merge ccInfo list
    if ccInfo_list:
        ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        providers.append(ccInfo )

    ################
    outputGroupInfo = OutputGroupInfo(
        # cc         = ccInfo.linking_context.linker_inputs.libraries,
        cmi        = depset(
            direct=cmi_out,
            transitive = bottomup_ns_cmi
        ),
        fileset    = fileset_depset,
        linkset    = linkset,
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
