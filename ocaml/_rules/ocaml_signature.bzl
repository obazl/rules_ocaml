load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_transitions:ns_transitions.bzl", "nsarchive_in_transition")

load("//ocaml:providers.bzl",
     "OcamlProvider",

     "CompilationModeSettingProvider",
     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider",
     "OcamlSDK",
     "OcamlSignatureProvider")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
)

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_transitions:transitions.bzl", "ocaml_signature_deps_out_transition")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     # "get_sdkpath",
)
load("//ocaml/_functions:module_naming.bzl",
     "normalize_module_name",
     "normalize_module_label")

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ppx",
     "options_signature")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_ccdeps.bzl", "link_ccdeps", "dump_CcInfo")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir")

workdir = tmpdir

########## RULE:  OCAML_SIGNATURE  ################
def _ocaml_signature_impl(ctx):

    debug = False
    # if ctx.label.name in ["_Impl.cmi"]:
    #     debug = True

    if debug:
        print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$")
        print("SIG %s" % ctx.label)

    # env = {"PATH": get_sdkpath(ctx)}

    # if ctx.attr.ns_submodule:
    #     return _extract_cmi(ctx)

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@rules_ocaml//ocaml:toolchain"]

    if mode == "native":
        exe = tc.ocamlopt # .basename
    else:
        exe = tc.ocamlc # .basename

    ################
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_cc_deps  = {}

    ################
    includes   = []

    sig_src = ctx.file.src
    if debug:
        print("sig_src: %s" % sig_src)

    # add prefix if namespaced. from_name == normalized module name
    # derived from sig_src; module_name == prefixed if ns else same as
    # from_name.

    modname = None
    # if ctx.label.name[:1] == "@":
    # if ctx.attr.forcename:
    if ctx.attr.module:
        if debug: print("Setting module name to %s" % ctx.attr.module)
        basename = ctx.attr.module
        modname = basename[:1].capitalize() + basename[1:]
        #FIXME: add ns prefix if needed
    else:
        (from_name, modname) = get_module_name(ctx, ctx.file.src)

    # (from_name, module_name) = get_module_name(ctx, sig_src)

    if debug: print("ctx.attr.ppx: %s" % ctx.attr.ppx)

    if ctx.attr.ppx:
        if debug: print("ppx")
        ## work_mli output is generated output of ppx processing
        work_mli = impl_ppx_transform("ocaml_signature", ctx,
                                      ctx.file.src, ## sig_src,
                                      modname + ".mli")
                                      # module_name + ".mli")
        work_cmi = ctx.actions.declare_file(
            workdir + modname + ".cmi")

    else:
        ## for now, symlink everything to workdir
        ## later we can optimize, avoiding symlinks if src in pkg dir
        ## and no renaming
        if debug: print("no ppx")
        # sp = ctx.file.src.short_path
        # spdir = paths.dirname(sp)
        # if paths.basename(spdir) + "/" == workdir:
        #     pkgdir = paths.dirname(spdir)
        # else:
        #     pkgdir = spdir
        # print("target spec pkg: %s" % ctx.label.package)
        # print("sigfiles pkgdir: %s" % pkgdir)

        # if ctx.label.package == pkgdir:
        #     print("PKGDIR == sigfile dir")
        #     sigsrc_modname = normalize_module_name(ctx.file.src.basename)
        #     print("sigsrc modname %s" % sigsrc_modname)
        #     if modname == sigsrc_modname:
        #         work_mli = ctx.file.src
        #         work_cmi = ctx.actions.declare_file(modname + ".cmi")
        #     else:
        #         work_mli = ctx.actions.declare_file(
        #             workdir + modname + ".mli")
        #         ctx.actions.symlink(output = work_mli,
        #                             target_file = ctx.file.src)
        #         work_cmi = ctx.actions.declare_file(
        #             workdir + modname + ".cmi")

        #     # work_cmi = sigProvider.cmi
        # else:  ## mli src in different pkg dir
        # if from_name == module_name:
        #     if debug: print("no namespace renaming")
        #     # work_mli = sig_src
        work_mli = ctx.actions.declare_file(
            workdir + modname + ".mli")
            # workdir + ctx.file.mli.basename)
        ctx.actions.symlink(output = work_mli,
                            target_file = ctx.file.src)
        # out_cmi = ctx.actions.declare_file(modname + ".cmi")
        work_cmi = ctx.actions.declare_file(
            workdir + modname + ".cmi")

        # else:
        #     if debug: print("namespace renaming")
        #     # namespaced w/o ppx: symlink sig_src to prefixed name, so
        #     # that output dir will contain both renamed input mli and
        #     # output cmi.
        #     ns_sig_src = module_name + ".mli"
        #     if debug:
        #         print("ns_sig_src: %s" % ns_sig_src)
        #     work_mli = ctx.actions.declare_file(workdir + ns_sig_src)
        #     ctx.actions.symlink(output = work_mli,
        #                         target_file = sig_src)
        #     if debug:
        #         print("work_mli %s" % work_mli)

    # out_cmi = ctx.actions.declare_file(workdir + modname + ".cmi")
    out_cmi = work_cmi
    # out_cmi = ctx.actions.declare_file(workdir + module_name + ".cmi")
    if debug: print("out_cmi %s" % out_cmi)

    #########################
    args = ctx.actions.args()

    opaque = False

    _options = get_options(rule, ctx)
    if "-opaque" in _options:
        opaque = True

    args.add_all(_options)

    # if "-for-pack" in _options:
    #     for_pack = True
    #     _options.remove("-for-pack")
    # else:
    #     for_pack = False

    # if ctx.attr.pack:
    #     args.add("-for-pack", ctx.attr.pack)

    # if ctx.attr.pack:
    #     args.add("-linkpkg")


    includes.append(out_cmi.dirname)

    args.add_all(includes, before_each="-I", uniquify = True)

    # paths_direct   = []
    # paths_indirect = []
    # all_deps_list = []
    # direct_deps_list = []
    # archive_deps_list = []
    # archive_inputs_list = [] # not for command line!

    # input_deps_list = []

    #### INDIRECT DEPS first ####
    # these direct deps are "indirect" from the perspective of the consumer
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    ccInfo_list = []

    the_deps = ctx.attr.deps + ctx.attr.open
    for dep in the_deps:

        if OcamlProvider in dep:
            indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
            indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
            indirect_paths_depsets.append(dep[OcamlProvider].paths)


        if CcInfo in dep:
            ccInfo_list.append(dep[CcInfo])

    # print("SIGARCHDL: %s" % archive_deps_list)
    ################ PPX Adjunct Deps ################
    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[PpxCodepsProvider]

        for ppx_codep in provider.ppx_codeps.to_list():
            adjunct_deps.append(ppx_codep)
            # if OcamlImportArchivesMarker in ppx_codep:
            #     adjuncts = ppx_codep[OcamlImportArchivesMarker].archives
            #     for f in adjuncts.to_list():
            if ppx_codep.extension in ["cmxa", "a"]:
                if (ppx_codep.path.startswith(opam_lib_prefix)):
                    dir = paths.relativize(ppx_codep.dirname, opam_lib_prefix)
                    includes.append( "+../" + dir )
                else:
                    includes.append(ppx_codep.dirname)
                args.add(ppx_codep.path)

    paths_depset  = depset(
        order = dsorder,
        direct = [out_cmi.dirname],
        transitive = indirect_paths_depsets
    )

    args.add_all(paths_depset.to_list(), before_each="-I")

    ## FIXME: do we need the resolver for sigfiles?
    # for f in ctx.files._ns_resolver:
    #     if f.extension == "cmx":
    #         args.add("-I", f.dirname) ## REQUIRED, even if cmx has full path
    #         args.add(f.path)

    if OcamlProvider in ctx.attr._ns_resolver:
        ns_resolver_depset = [ctx.attr._ns_resolver[OcamlProvider].inputs]
    else:
        ns_resolver_depset = []

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
        ## this will only be the case if this is a submodule of an nslib
        # if OcamlProvider in ctx.attr._ns_resolver:
        for f in ctx.attr._ns_resolver[DefaultInfo].files.to_list():
            args.add("-I", f.dirname)
            args.add(f)

        args.add("-no-alias-deps")
        args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    if ctx.attr.open:
        for dep in ctx.files.open:
            args.add("-open", normalize_module_name(dep.basename))

    args.add("-c")
    args.add("-o", out_cmi)

    args.add("-intf", work_mli)

    inputs_depset = depset(
        order = dsorder,
        direct = [work_mli], # + ctx.files._ns_resolver,
        transitive = indirect_inputs_depsets + ns_resolver_depset
    )

    ################
    ctx.actions.run(
        # env = env,
        executable = exe,
        arguments = [args],
        inputs = inputs_depset,
        outputs = [out_cmi],
        tools = [tc.ocamlopt],
        mnemonic = "CompileOcamlSignature",
        progress_message = "{mode} compiling ocaml_signature: {ws}//{pkg}:{tgt}".format(
            mode = mode,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name
        )
    )

    ################
    default_depset = depset(
        order = dsorder,
            direct = [out_cmi],
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    sigProvider = OcamlSignatureProvider(
        mli = work_mli,
        cmi = out_cmi,
        opaque = True if opaque else False
    )

    new_inputs_depset = depset(
        direct = [out_cmi],
        transitive = indirect_inputs_depsets
    )
    linkargs_depset = depset(
        # cmi file does not go in linkargs
        transitive = indirect_linkargs_depsets
    )

    ocamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,
    )

    providers = [
        defaultInfo,
        ocamlProvider,
        sigProvider,
    ]

    ## ppx codeps? signatures may contribute to construction of a
    ## ppx_executable, but they will not inject codeps, since they are
    ## just interfaces, not runing code.

    if ccInfo_list:
        providers.append(
            cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        )


    outputGroupInfo = OutputGroupInfo(
        cmi        = default_depset,
    )

    providers.append(outputGroupInfo)

    return providers


################################################################
################################################################

################################
rule_options = options("ocaml")
rule_options.update(options_signature)
rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

#######################
ocaml_signature = rule(
    implementation = _ocaml_signature_impl,
    doc = """Generates OCaml .cmi (inteface) file. [User Guide](../ug/ocaml_signature.md). Provides `OcamlSignatureProvider`.

**CONFIGURABLE DEFAULTS** for rule `ocaml_signature`

In addition to the <<Configurable defaults>> that
apply to all `ocaml_*` rules, the following apply to this rule. (Note
the difference between '/' and ':' in such labels):

[.rule_attrs]
[cols="1,1,1"]
|===
| Label | Default | `opts` attrib

| @rules_ocaml//cfg/signature/linkall | True | `-linkall`, `-no-linkall`

| @rules_ocaml//cfg/signature:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value

|===

// | @rules_ocaml//cfg/signature/threads | False | true: `-I +threads`


    """,
    attrs = dict(
        rule_options,
        ## RULE DEFAULTS
        # _linkall     = attr.label(default = "@rules_ocaml//cfg/signature/linkall"), # FIXME: call it alwayslink?
        # _threads     = attr.label(default = "@rules_ocaml//cfg/signature/threads"),
        _warnings  = attr.label(default = "@rules_ocaml//cfg/signature:warnings"),
        #### end options ####

        # src = attr.label(
        #     doc = "A single .mli source file label",
        #     allow_single_file = [".mli", ".ml"] #, ".cmi"]
        # ),

        # ns_submodule = attr.label_keyed_string_dict(
        #     doc = "Extract cmi file from namespaced module",
        #     providers = [
        #         [OcamlNsMarker, OcamlArchiveMarker],
        #     ]
        # ),

        # pack = attr.string(
        #     doc = "Experimental",
        # ),

        # deps = attr.label_list(
        #     doc = "List of OCaml dependencies. Use this for compiling a .mli source file with deps. See [Dependencies](#deps) for details.",
        #     providers = [
        #         [OcamlProvider],
        #         [OcamlArchiveMarker],
        #         [OcamlImportMarker],
        #         [OcamlLibraryMarker],
        #         [OcamlModuleMarker],
        #         [OcamlNsMarker],
        #     ],
        #     # cfg = ocaml_signature_deps_out_transition
        # ),

        # data = attr.label_list(
        #     allow_files = True
        # ),

        # ################################################################
        # _ns_resolver = attr.label(
        #     doc = "Experimental",
        #     providers = [OcamlNsResolverProvider],
        #     default = "@rules_ocaml//cfg/ns",
        #     # cfg = ocaml_signature_deps_out_transition
        # ),

        # _ns_submodules = attr.label( # _list(
        #     doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
        #     default = "@rules_ocaml//cfg/ns:submodules", ## NB: ppx modules use ocaml_signature
        # ),
        # _ns_strategy = attr.label(
        #     doc = "Experimental",
        #     default = "@rules_ocaml//cfg/ns:strategy"
        # ),
        # _mode       = attr.label(
        #     default = "@rules_ocaml//build/mode",
        # ),

        module = attr.string(
            doc = "Set module (sig) name to this string"
        ),

        opaque = attr.bool(
            doc = "Compile with -opaque if true",
            default = False
        ),

        _rule = attr.string( default = "ocaml_signature" ),

        # _sdkpath = attr.label(
        #     default = Label("@rules_ocaml//cfg:sdkpath")
        # ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    incompatible_use_toolchain_transition = True,
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@rules_ocaml//ocaml:toolchain"],
)
