load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",

     "PpxAdjunctsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlArchiveProvider",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider",
     # "OcamlPathsMarker",
     "OcamlSDK",
     "OcamlSignatureProvider",

     "PpxArchiveMarker",
     "PpxModuleMarker")

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_transitions:transitions.bzl", "ocaml_signature_deps_out_transition")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     "normalize_module_label",
)

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ppx")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl",
     "dsorder",
     "merge_deps",
     "opam_lib_prefix",
     "tmpdir")

scope = tmpdir

########## RULE:  OCAML_SIGNATURE  ################
def _ocaml_signature_impl(ctx):

    debug = False
    # if ctx.label.name in ["_Impl.cmi"]:
    #     debug = True

    print("#### SIGNATURE {} ####".format(ctx.label))

    if debug:
        print("")
        if ctx.attr._rule == "ocaml_signature":
            print("Start: OCAMLSIG %s" % ctx.label)
        else:
            fail("Unexpected rule for 'ocaml_signature_impl': %s" % ctx.attr._rule)

        print("  ns_prefixes: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
        print("  ns_submodules: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)

    OCAMLFIND_IGNORE = ""
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif/c"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"

    env = {
        "OPAMROOT": get_opamroot(),
        "PATH": get_sdkpath(ctx),
        "OCAMLFIND_IGNORE_DUPS_IN": OCAMLFIND_IGNORE
    }

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    # if len(ctx.attr.deps_opam) > 0:
    #     using_ocamlfind = True
    #     ocamlfind_opts = ["-predicates", "ppx_driver"]
    #     exe = tc.ocamlfind
    # else:
    using_ocamlfind = False
    ocamlfind_opts = []
    if mode == "native":
        exe = tc.ocamlopt.basename
    else:
        exe = tc.ocamlc.basename

    ################
    merged_module_links_depsets = []
    merged_archive_links_depsets = []

    merged_paths_depsets = []
    merged_depgraph_depsets = []
    merged_archived_modules_depsets = []

    # indirect_opam_depsets = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    # indirect_adjunct_opam_depsets = []

    indirect_cc_deps  = {}

    ################
    includes   = []

    # print("SIG SRC: %s" % ctx.file.src)
    # should add ns prefix:
    (from_name, module_name) = get_module_name(ctx, ctx.file.src)
    # print("MODULE NAME: %s" % module_name)

    if ctx.attr.ppx:
        mlifile = impl_ppx_transform("ocaml_signature", ctx,
                                     ctx.file.src,
                                     module_name + ".mli")
    # elif module_name != from_name:
    #     sigfile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")
    else:
        # print("NO PPX %s" % ctx.file.src)
        tmp = capitalize_initial_char(ctx.file.src.basename)
        if (tmp != module_name + ".mli"):
            # print("RENAMING {src} to {dst}".format(
            #     src=tmp, dst=module_name
            # ))
            mlifile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")
        else:
            # print("NOT RENAMING")
            mlifile = ctx.file.src
    # mlifile = ctx.file.src
    # normalize_module_name(sigMarker.mli.basename) + ".mli")
    # print("RENAMED SIG SRC: %s" % mlifile)

    out_cmi = ctx.actions.declare_file(scope + module_name + ".cmi")
    # out_cmi = ctx.actions.declare_file(scope + mlifile.basename)

    #########################
    args = ctx.actions.args()

    _options = get_options(rule, ctx)
    args.add_all(_options)

    # if "-for-pack" in _options:

    # if ctx.attr.pack:

    # if ctx.attr.pack:


    includes.append(out_cmi.dirname)

    args.add_all(includes, before_each="-I", uniquify = True)

    paths_direct   = []
    paths_indirect = []
    all_deps_list = []

    the_deps = ctx.attr.deps + [ctx.attr._ns_resolver]

    for dep in the_deps:
        # print("MDEP: {host} => {d}".format(host=ctx.label, d = dep.label))
        ################ OCamlMarker ################
        if OcamlProvider in dep:
            all_deps_list.append(dep[OcamlProvider].files)
            paths_indirect.append(dep[OcamlProvider].paths)

        ################ OCamlArchiveProvider ################

    paths_depset  = depset(

    args.add_all(paths_depset.to_list(), before_each="-I")

    all_deps = depset(
        order = dsorder,
        transitive = all_deps_list
    )

    link_args = []
    for f in all_deps.to_list():
        if f.extension not in [

    # args.add_all(link_args)

    ## FIXME: do we need the resolver for sigfiles?
    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
        ## this will only be the case if this is a submodule of an nslib
        args.add("-no-alias-deps")
        args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    args.add("-c")
    args.add("-o", out_cmi)

    #     ## cp source file to workdir (__obazl)
    #     ## this is necessary for .mli/.cmi resolution to work
    #     # sigfile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")

    args.add("-intf", mlifile)

    input_depset = depset(
        direct = [mlifile], #sigfile],
        # transitive = merged_depgraph_depsets + [archive_links_depset]
        transitive = [all_deps]
    )

    # print("OUT_CMI: %s" % out_cmi);

    ################
    ################
    ctx.actions.run(
        env = env,
        executable = exe,  ## tc.ocamlfind,
        arguments = [args],
        inputs = input_depset,
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
    ################
    default_depset = depset(
        order = dsorder,
            direct = [out_cmi],
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    sigProvider = OcamlSignatureProvider(
        mli = mlifile, # sigfile,
        cmi = out_cmi,
    )

    ## FIXME: catch incompatible key dups
    cclibs = {}
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        ccdeps_map = cclibs

    )
    # print("OUTPUT CCPROVIDER: %s" % ccProvider)
    new_inputs_depset = depset(
        direct = [out_cmi],
        transitive = indirect_inputs_depsets
    )
    linkargs_depset = depset(
        # cmi file does not go in linkargs
        transitive = indirect_linkargs_depsets
    )
    # paths_depset = depset(
    #     direct = direct_paths_list,
    #     transitive = indirect_paths_depsets
    # )

    ocamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,

        files = depset(
            order  = dsorder,
            direct = [out_cmi], # mli?
            transitive = input_deps_list
            # transitive = [all_deps]
        ),
        archives = archives_depset if archives_depset else False,
        archive_deps = archive_inputs_depset if archive_inputs_depset else False,
    )
    # print("SIG exporting OCamlProvider: %s" % ocamlProvider)
    archiveProvider = OcamlArchiveProvider(
        files = depset() ## FIXME
    )

    providers = [
        defaultInfo,
        ocamlProvider,
        sigProvider,
        # opamMarker,
        ccProvider
    ]

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
            allow_single_file = [".mli", ".cmi"]
        ),
        pack = attr.string(
            doc = "Experimental",
        ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies. See [Dependencies](#deps) for details.",
            providers = [
                # [OcamlSignatureProvider],
                # [OcamlProvider],
                # [CcDepsProvider]
                [OcamlArchiveProvider],
                [OcamlImportMarker],
                [OcamlLibraryMarker],
                [OcamlModuleMarker],
                [OcamlNsMarker],
                [PpxArchiveMarker],
                [PpxModuleMarker],
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
            default = Label("@ocaml//:path")
        ),
        # _opam_lib = attr.label(
        #     default = "@opam//:opam_lib"
        # )
    ),
    incompatible_use_toolchain_transition = True,
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
