# load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
# load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     # "OcamlArchiveProvider",
     "CompilationModeSettingProvider",

     "PpxAdjunctsProvider",
     "OcamlModuleMarker",
     "OcamlNsResolverProvider",
     "OcamlSignatureProvider",
     "OcamlSDK")

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

    # print("++ MODULE {}".format(ctx.label))

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

    paths_direct = [d.dirname for d in direct_linkargs]
    if ctx.files._ns_resolver:
        paths_direct.extend([f.dirname for f in ctx.files._ns_resolver])

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
            ## we do not need to do anything with ccdeps here,
            ## just pass them on in a provider
            ccInfo_list.append(dep[CcInfo])

        if OcamlProvider in dep:
            # ignore DefaultInfo, its just for printing, not propagation
            indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
            indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
            indirect_paths_depsets.append(dep[OcamlProvider].paths)

    ################ Signature Dep ################
    if ctx.attr.sig:
        dep = ctx.attr.sig

        # ignore DefaultInfo, its just for printing, not propagation
        indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
        indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        indirect_paths_depsets.append(dep[OcamlProvider].paths)

    ################ PPX Adjunct Deps ################
    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []
    # print("TGT: %s" % ctx.label.name)
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[PpxAdjunctsProvider]

        ## NB: it seems to be sufficient to put the ppx_codep in the
        ## search path with -I; the archive itself need not be added?
        ## omitting the path: e.g. "Unbound module Ppx_inline_test_lib"
        ## adding the path makes the compile work.
        ## BUT: the ppx_codep must be propagated to
        ## ocaml_executable, otherwise the link will fail with:
        ## "No implementations provided for the following modules:..."
        dlist = provider.ppx_codeps.to_list()
        args.add("-ccopt", "-DPPX_ADJUNCTS_START")
        for f in dlist: ## provider.files.to_list():
            adjunct_deps.append(f)
            if f.extension in ["cmxa", "a"]:
                if (f.path.startswith(opam_lib_prefix)):
                    dir = paths.relativize(f.dirname, opam_lib_prefix)
                    includes.append( "+../" + dir )
                else:
                    includes.append(f.dirname)
        args.add("-ccopt", "-DPPX_ADJUNCTS_END")

        for path in provider.paths.to_list():
            includes.append(path)

    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = indirect_paths_depsets
    )

    args.add_all(paths_depset.to_list(), before_each="-I")

    _linkargs_depset = depset(
        transitive = indirect_linkargs_depsets
    )

    linkargs_depset = depset(
        direct = direct_linkargs,
        transitive = [_linkargs_depset]
    )

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

    inputs_depset = depset(
        order = dsorder,
        direct = [structfile]
        + mli_out
        + ctx.files.deps_runtime
        + ctx.files._ns_resolver,
        transitive = indirect_inputs_depsets
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

    ## pass on adjunct deps rec'd from deps of this module
    ## do we need to do this?
    ppx_codeps_depset = depset(
        order = dsorder,
        direct = adjunct_deps,
        transitive = indirect_adjunct_depsets
    )

    adjunctsMarker = PpxAdjunctsProvider(
        ppx_codeps = ppx_codeps_depset,
        paths = depset(order = dsorder,
                       transitive = indirect_adjunct_path_depsets)
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

    nsResolverProvider = OcamlNsResolverProvider(
        files = ctx.attr._ns_resolver.files,
        paths = depset([d.dirname for d in ctx.attr._ns_resolver.files.to_list()])
    )

    ################################################################
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

    providers = [
        defaultInfo,
        OcamlModuleMarker(marker="OcamlModule"),
        ocamlProvider,
        nsResolverProvider, # FIXME: only if is submodule?
        outputGroupInfo,
        adjunctsMarker,
    ]

    ## now merge ccInfo list
    if ccInfo_list:
        ccInfo = cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        providers.append(ccInfo )

    return providers
