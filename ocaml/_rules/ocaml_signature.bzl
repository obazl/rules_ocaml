load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_transitions:ns_transitions.bzl", "nsarchive_in_transition")

load("//ocaml:providers.bzl",
     "OcamlProvider",

     "PpxAdjunctsProvider",
     "CompilationModeSettingProvider",
     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider",
     "OcamlSDK",
     "OcamlSignatureProvider")

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_transitions:transitions.bzl", "ocaml_signature_deps_out_transition")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_sdkpath",
)
load("//ocaml/_functions:module_naming.bzl", "normalize_module_label")

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ppx")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_ccdeps.bzl", "link_ccdeps", "dump_ccdep")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir")

scope = tmpdir

# def _extract_cmi(ctx):
#     if len(ctx.attr.ns_submodule) > 1:
#         fail("only one ns_submodule supported")
#     (ns, module) = ctx.attr.ns_submodule.items()[0];
#     print("Extracting cmi {cmi} from {ns}".format(
#         cmi = module, ns = ns))
#     # print("NS marker: %s" % ns[OcamlNsMarker])
#     # print("OcamlProvider: %s" % ns[OcamlProvider])

#     in_cmi  = None
#     out_cmi = None
#     # for f in ns[OcamlProvider].inputs.to_list(): # nope
#     # for f in ns[OcamlProvider].linkargs.to_list(): #nope
#     for f in ns[OcamlProvider].linkargs.to_list():
#         print("linkarg: %s" % f)
#         if f.basename.endswith(module + ".cmi"):
#             in_cmi = f

#     if in_cmi == None:
#         print("LBL: %s" % ctx.label)
#         fail("ns_submodule submodule: '{m}' not found".format(m=module))

#     if ctx.attr.as_cmi:
#         if ctx.attr.as_cmi.endswith(".cmi"):
#             as_cmi = ctx.attr.as_cmi
#         else:
#             as_cmi = ctx.attr.as_cmi + ".cmi"
#         out_cmi = ctx.actions.declare_file(as_cmi)

#         ctx.actions.symlink(
#             output = out_cmi,
#             target_file = in_cmi
#         )

#     else:
#         out_cmi = in_cmi

#     default_depset = depset(
#         order = dsorder,
#             direct = [out_cmi],
#     )

#     defaultInfo = DefaultInfo(
#         files = default_depset
#     )

#     sigProvider = OcamlSignatureProvider(
#         # mli = mlifile,
#         cmi = out_cmi
#     )

#     return [defaultInfo, sigProvider]

########## RULE:  OCAML_SIGNATURE  ################
def _ocaml_signature_impl(ctx):

    debug = False
    # if ctx.label.name in ["_Impl.cmi"]:
    #     debug = True

    env = {"PATH": get_sdkpath(ctx)}

    # if ctx.attr.ns_submodule:
    #     return _extract_cmi(ctx)

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    if mode == "native":
        exe = tc.ocamlopt.basename
    else:
        exe = tc.ocamlc.basename

    ################
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_cc_deps  = {}

    ################
    includes   = []

    (from_name, module_name) = get_module_name(ctx, ctx.file.src)

    if ctx.attr.ppx:
        mlifile = impl_ppx_transform("ocaml_signature", ctx,
                                     ctx.file.src,
                                     module_name + ".mli")
    else:
        tmp = capitalize_initial_char(ctx.file.src.basename)

        # FIXME: if src is foo.ml, then use -i to extract mli and compile it
        # instead of renaming src to .mli?
        # OR: do not rename, just pass -intf foo.ml -o foo.cmi???

        if (tmp != module_name + ".mli"):
            mlifile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")
        else:
            mlifile = ctx.file.src

    out_cmi = ctx.actions.declare_file(scope + module_name + ".cmi")

    #########################
    args = ctx.actions.args()

    _options = get_options(rule, ctx)
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

    the_deps = ctx.attr.deps # + [ctx.attr._ns_resolver]
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
        provider = ctx.attr.ppx[PpxAdjunctsProvider]

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

    args.add("-c")
    args.add("-o", out_cmi)

    args.add("-intf", mlifile)

    inputs_depset = depset(
        order = dsorder,
        direct = [mlifile], # + ctx.files._ns_resolver,
        transitive = indirect_inputs_depsets + ns_resolver_depset
    )

    ################
    ctx.actions.run(
        env = env,
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
        mli = mlifile,
        cmi = out_cmi
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

    return providers


################################################################
################################################################

################################
rule_options = options("ocaml")
rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

#######################
ocaml_signature = rule(
    implementation = _ocaml_signature_impl,
    doc = """Generates OCaml .cmi (inteface) file. [User Guide](../ug/ocaml_signature.md). Provides `OcamlSignatureProvider`.

**CONFIGURABLE DEFAULTS** for rule `ocaml_executable`

In addition to the [OCaml configurable defaults](#configdefs) that apply to all
`ocaml_*` rules, the following apply to this rule:

| Label | Default | `opts` attrib |
| ----- | ------- | ------- |
| @ocaml//interface:linkall | True | `-linkall`, `-no-linkall`|
| @ocaml//interface:threads | False | true: `-I +threads`|
| @ocaml//interface:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value |

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        rule_options,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//signature/linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//signature/threads"),
        _warnings  = attr.label(default = "@ocaml//signature:warnings"),
        #### end options ####

        src = attr.label(
            doc = "A single .mli source file label",
            allow_single_file = [".mli", ".ml"] #, ".cmi"]
        ),

        # ns_submodule = attr.label_keyed_string_dict(
        #     doc = "Extract cmi file from namespaced module",
        #     providers = [
        #         [OcamlNsMarker, OcamlArchiveMarker],
        #     ]
        # ),

        as_cmi = attr.string(
            doc = "For use with ns_module only. Creates a symlink from the extracted cmi file."
        ),

        pack = attr.string(
            doc = "Experimental",
        ),

        deps = attr.label_list(
            doc = "List of OCaml dependencies. Use this for compiling a .mli source file with deps. See [Dependencies](#deps) for details.",
            providers = [
                [OcamlProvider],
                [OcamlArchiveMarker],
                [OcamlImportMarker],
                [OcamlLibraryMarker],
                [OcamlModuleMarker],
                [OcamlNsMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        ################################################################
        ## do we need resolver for sigfiles?
        _ns_resolver = attr.label(
            doc = "Experimental",
            providers = [OcamlNsResolverProvider],
            default = "@ocaml//ns",
            # cfg = ocaml_signature_deps_out_transition
        ),

        _ns_submodules = attr.label( # _list(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@ocaml//ns:submodules", ## NB: ppx modules use ocaml_signature
        ),
        # _ns_strategy = attr.label(
        #     doc = "Experimental",
        #     default = "@ocaml//ns:strategy"
        # ),
        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        _rule = attr.string( default = "ocaml_signature" ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:sdkpath")
        ),
    ),
    incompatible_use_toolchain_transition = True,
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)

################################################################
## extract cmi from ns resolver
########## RULE:  OCAML_NS_SIGNATURE  ################
def _ocaml_ns_signature_impl(ctx):

    ns = ctx.attr.ns
    # print("Extracting resolver cmi from {ns}".format(ns = ns))
    # print("NS marker: %s" % ns[OcamlNsMarker])
    # print("OcamlProvider: %s" % ns[OcamlProvider])

    in_cmi  = None
    out_cmi = None

    if OcamlNsMarker in ctx.attr.ns:
        ns_name = ctx.attr.ns[OcamlNsMarker].ns_name

    if ns_name == None:
        print("LBL: %s" % ctx.label)
        fail("ns resolver for {ns} not found".format(ns=ns))
    else:
        for f in ns[OcamlProvider].fileset.to_list():
            # print("fileset f: %s" % f)
            if f.basename.endswith(ns_name + ".cmi"):
                in_cmi = f

    if in_cmi == None:
        print("LBL: %s" % ctx.label)
        fail("ns resolver cmi {cmi} for {ns} not found".format(
            cmi = ns_name + ".cmi", ns=ns))

    if ctx.attr.as_cmi:
        if ctx.attr.as_cmi.endswith(".cmi"):
            as_cmi = ctx.attr.as_cmi
        else:
            as_cmi = ctx.attr.as_cmi + ".cmi"
        out_cmi = ctx.actions.declare_file(as_cmi)

        ctx.actions.symlink(
            output = out_cmi,
            target_file = in_cmi
        )

    else:
        out_cmi = in_cmi

    default_depset = depset(
        order = dsorder,
            direct = [out_cmi],
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    sigProvider = OcamlSignatureProvider(
        # mli = mlifile,
        cmi = out_cmi
    )

    return [defaultInfo, sigProvider]

#######################
ocaml_ns_signature = rule(
    implementation = _ocaml_ns_signature_impl,
    doc = """Extract .cmi from ns lib or archive.
    """,
    attrs = dict(
        rule_options,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//signature/linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//signature/threads"),
        _warnings  = attr.label(default = "@ocaml//signature:warnings"),
        #### end options ####

        ns = attr.label(
            doc = "An ocaml_ns_library or ocaml_ns_archive",
            allow_single_file = True,
            providers = [OcamlNsMarker]
        ),

        as_cmi = attr.string(
            doc = "For use with ns_module only. Creates a symlink from the extracted cmi file."
        ),

        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        _rule = attr.string( default = "ocaml_ns_signature" ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:sdkpath")
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    ## this is not an ns archive, and it does not use ns ConfigState,
    ## but we need to reset the ConfigState anyway, so the deps are
    ## not affected if this is a dependency of an ns aggregator.
    # cfg     = nsarchive_in_transition,
    incompatible_use_toolchain_transition = True,
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)

################################################################
## extract cmi from ns submodule
########## RULE:  OCAML_NS_SUBSIGNATURE  ################
def _ocaml_ns_subsignature_impl(ctx):

    ns = ctx.attr.ns
    # print("Extracting cmi for submodule {m} from {ns}".format(
    #     m = ctx.attr.module, ns = ns, ))
    # print("NS marker: %s" % ns[OcamlNsMarker])
    # print("OcamlProvider: %s" % ns[OcamlProvider])

    in_cmi  = None
    out_cmi = None

    for f in ns[OcamlProvider].fileset.to_list():
        # print("fileset f: %s" % f)
        if f.basename.endswith(ctx.attr.module + ".cmi"):
            in_cmi = f

    if in_cmi == None:
        print("LBL: %s" % ctx.label)
        fail("cmi for submodule {m} of ns {ns} not found".format(
            m = ctx.attr.module + ".cmi", ns=ns))

    if ctx.attr.as_cmi:
        if ctx.attr.as_cmi.endswith(".cmi"):
            as_cmi = ctx.attr.as_cmi
        else:
            as_cmi = ctx.attr.as_cmi + ".cmi"
        out_cmi = ctx.actions.declare_file(as_cmi)

        ctx.actions.symlink(
            output = out_cmi,
            target_file = in_cmi
        )

    else:
        out_cmi = in_cmi

    default_depset = depset(
        order = dsorder,
            direct = [out_cmi],
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    sigProvider = OcamlSignatureProvider(
        # mli = mlifile,
        cmi = out_cmi
    )

    return [defaultInfo, sigProvider]

#######################
ocaml_ns_subsignature = rule(
    implementation = _ocaml_ns_subsignature_impl,
    doc = """Extract .cmi from ns submodule
    """,
    attrs = dict(
        rule_options,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//signature/linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//signature/threads"),
        _warnings  = attr.label(default = "@ocaml//signature:warnings"),
        #### end options ####

        ns = attr.label(
            doc = "An ocaml_ns_library or ocaml_ns_archive",
            allow_single_file = True,
            providers = [OcamlNsMarker]
        ),

        module = attr.string(
            doc = "Module whose .cmi we want",
        ),

        as_cmi = attr.string(
            doc = "Creates a symlink from the extracted cmi file. Use to rename .cmi file."
        ),

        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        _rule = attr.string( default = "ocaml_ns_signature" ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:sdkpath")
        ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    ## this is not an ns archive, and it does not use ns ConfigState,
    ## but we need to reset the ConfigState anyway, so the deps are
    ## not affected if this is a dependency of an ns aggregator.
    cfg     = nsarchive_in_transition,
    incompatible_use_toolchain_transition = True,
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)

