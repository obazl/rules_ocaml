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
     "get_sdkpath",
)

load("//ocaml/_functions:module_naming.bzl",
     "file_to_lib_name",
     "normalize_module_name")

load(":impl_ccdeps.bzl", "link_ccdeps", "dump_ccdep")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir"
     )

scope = tmpdir

#####################
def impl_module(ctx):

    debug = False

    if hasattr(ctx.attr, "ppx_tags"):
        if len(ctx.attr.ppx_tags) > 1:
            fail("Only one ppx_tag allowed currently.")

    env = {"PATH": get_sdkpath(ctx)}

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    if mode == "native":
        exe = tc.ocamlopt.basename
    else:
        exe = tc.ocamlc.basename

    ext  = ".cmx" if  mode == "native" else ".cmo"

    ################
    indirect_ppx_codep_depsets      = []
    indirect_ppx_codep_path_depsets = []
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
        # print("SIG_%s" % ctx.label.name)

        # derive module name from sigfile
        # for submodules, sigfile name will already contain ns prefix
        sigProvider = ctx.attr.sig[OcamlSignatureProvider]
        out_cmi = sigProvider.cmi
        mlifile = sigProvider.mli
        module_name = out_cmi.basename[:-4]
        if sigProvider.mli.is_source:  # not a generated file
            tmp = capitalize_initial_char(sigProvider.mli.basename)
            normalized_modname = normalize_module_name(sigProvider.mli.basename) + ".mli"
            if (tmp != normalized_modname):
                mlifile = rename_srcfile(ctx, sigProvider.mli, normalized_modname)
            else:
                mlifile = sigProvider.mli
            includes.append(mlifile.dirname)

    if module_name == None:
        # no sigfile dependency, so derive module name from structfile
        # detects and adds ns prefix if appropriate:
        (from_name, module_name) = get_module_name(ctx, ctx.file.struct)
        # and declare cmi output, since ocaml will generate it
        out_cmi = ctx.actions.declare_file(scope + module_name + ".cmi")
        action_outputs.append(out_cmi)

    out_cm_ = ctx.actions.declare_file(scope + module_name + ext) # fname)
    action_outputs.append(out_cm_)
    direct_linkargs.append(out_cm_)
    default_outputs.append(out_cm_)

    if mode == "native":
        out_o = ctx.actions.declare_file(scope + module_name + ".o")
        action_outputs.append(out_o)
        direct_linkargs.append(out_o)

    ns_resolver = ctx.attr._ns_resolver
    ns_resolver_files = ctx.files._ns_resolver

    paths_direct = [d.dirname for d in direct_linkargs]
    if ns_resolver:
        paths_direct.extend([f.dirname for f in ns_resolver_files])
    # print("RESOLVER PATHS: %s" % paths_direct)

    if ctx.attr.ppx:
        # module_name was derived above. ppx xform does not change it.
        structfile = impl_ppx_transform(ctx.attr._rule, ctx, ctx.file.struct, module_name + ".ml")
    else:
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
            ccInfo_list.append(dep[CcInfo])

        if OcamlProvider in dep:
            indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
            indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
            indirect_paths_depsets.append(dep[OcamlProvider].paths)

    ################ Signature Dep ################
    if ctx.attr.sig:
        indirect_inputs_depsets.append(ctx.attr.sig[OcamlProvider].inputs)
        indirect_linkargs_depsets.append(
            ctx.attr.sig[OcamlProvider].linkargs
        )
        indirect_paths_depsets.append(ctx.attr.sig[OcamlProvider].paths)

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

        ## NB: it seems to be sufficient to put the ppx_codep in the
        ## search path with -I; the archive itself need not be added?
        ## omitting the path: e.g. "Unbound module Ppx_inline_test_lib"
        ## adding the path makes the compile work.
        ## BUT: the ppx_codep must be propagated to
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
    args.add_all(includes, before_each="-I", uniquify = True)


    _linkargs_depset = depset(
        transitive = indirect_linkargs_depsets
    )

    linkargs_depset = depset(
        direct = direct_linkargs,
        transitive = [_linkargs_depset]
    )

    # if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
    if hasattr(ns_resolver[OcamlNsResolverProvider], "resolver"):
        ## this will only be the case if this is a submodule in an ns
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
    mli_out = [mlifile] if mlifile else []

    ## runtime deps must be added to the depgraph (so they get built),
    ## but not the command line (they are not build-time deps).

    inputs_depset = depset(
        order = dsorder,
        direct = [structfile] + ns_resolver_files
        + mli_out
        + ctx.files.deps_runtime,
        transitive = indirect_inputs_depsets + indirect_ppx_codep_depsets
    )

    args.add("-c")

    args.add("-o", out_cm_)

    args.add("-impl", structfile)

    ################
    ctx.actions.run(
        env = env,
        executable = exe,
        arguments = [args],
        inputs    = inputs_depset,
        outputs   = action_outputs,
        tools = [tc.ocamlopt, tc.ocamlc],
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
        direct = action_outputs
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    ocamlProvider_files_depset = depset(
        order  = dsorder,
        direct = action_outputs, # + [out_cmi] + mli_out,
    )

    new_inputs_depset = depset(
        direct = action_outputs,
        transitive = indirect_inputs_depsets
    )

    ocamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,

        files = ocamlProvider_files_depset,
    )

    ################################################################
    providers = [
        defaultInfo,
        OcamlModuleMarker(marker="OcamlModule"),
        ocamlProvider,
    ]

    ## FIXME: make this conditional:
    ## if this module is a submodule in a namespace:
    nsResolverProvider = OcamlNsResolverProvider(
        files = ctx.attr._ns_resolver.files,
        paths = depset([d.dirname for d in ctx.attr._ns_resolver.files.to_list()])
    )
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
        ppx_codeps = ppx_codeps_depset,
        # cc = action_inputs_ccdep_filelist,
        inputs = inputs_depset,
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
