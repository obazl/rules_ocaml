load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlNsResolverProvider",
     "OcamlSDK",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "PpxArchiveProvider",
     "PpxModuleProvider",
     "PpxNsArchiveProvider",
     "PpxNsLibraryProvider")

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

load(":impl_common.bzl", "merge_deps", "tmpdir")

scope = tmpdir

########## RULE:  OCAML_SIGNATURE  ################
def _ocaml_signature_impl(ctx):

    debug = False
    # if ctx.label.name in ["_Impl.cmi"]:
    #     debug = True

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

    if len(ctx.attr.deps_opam) > 0:
        using_ocamlfind = True
        ocamlfind_opts = ["-predicates", "ppx_driver"]
        exe = tc.ocamlfind
    else:
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

    indirect_opam_depsets = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets = []

    indirect_cc_deps  = {}

    ################
    includes   = []

    (from_name, module_name) = get_module_name(ctx, ctx.file.src)

    out_cmi = ctx.actions.declare_file(scope + module_name + ".cmi")

    #########################
    args = ctx.actions.args()

    if using_ocamlfind:
        if mode == "native":
            args.add(tc.ocamlopt.basename)
        else:
            args.add(tc.ocamlc.basename)

    _options = get_options(rule, ctx)
    args.add_all(_options)

    mdeps = []
    mdeps.extend(ctx.attr.deps)
    mdeps.append(ctx.attr._ns_resolver)

    if debug:
        print("MDEPS: %s" % mdeps)
    merge_deps(mdeps,
               merged_module_links_depsets,
               merged_archive_links_depsets,
               merged_paths_depsets,
               merged_depgraph_depsets,
               merged_archived_modules_depsets,
               # indirect_file_depsets,
               # indirect_archive_depsets,
               # indirect_path_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    if ctx.attr.pack:
        args.add("-linkpkg")

    opam_depset = depset(direct = ctx.attr.deps_opam,
                         transitive = indirect_opam_depsets)
    if using_ocamlfind:
        for opam in opam_depset.to_list():
            args.add("-package", opam)  ## add dirs to search path

    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[AdjunctDepsProvider]
        if using_ocamlfind:
            for opam in provider.opam.to_list():
                args.add("-package", opam)

        for nopam in provider.nopam.to_list():
            adjunct_deps.append(nopam)
            # for nopamfile in nopam.files.to_list():
                # adjunct_deps.append(nopamfile)
        for path in provider.nopam_paths.to_list():
            args.add("-I", path)

    indirect_paths_depset = depset(transitive = merged_paths_depsets)
    for path in indirect_paths_depset.to_list():
            includes.append(path)

    includes.append(out_cmi.dirname)

    if not using_ocamlfind:
        imports_test = depset(transitive = merged_depgraph_depsets)
        for f in imports_test.to_list():
            # FIXME: only relativize ocaml_imports
            # print("relativizing %s" % f.path)
            if (f.extension == "cmxa"):
                dir = paths.relativize(f.dirname, "external/opam/_lib")
                includes.append(
                    ctx.attr._opam_lib[BuildSettingInfo].value + "/" + dir
                )

    if ctx.attr.pack:
        args.add("-for-pack", ctx.attr.pack)

    args.add_all(includes, before_each="-I", uniquify = True)

    ## use depsets to get the right ordering. filter to limit to direct deps.
    archive_links_depset = depset(transitive = merged_archive_links_depsets)
    link_deps = []
    for link in ctx.files.deps:
        link_deps.append(link.basename)
    if debug:
        print("DEP LINKS: %s" % link_deps)

    # for dep in archive_links_depset.to_list():
    #     if debug:
    #         print("DEP: %s" % dep)
    #     if dep.basename in link_deps:
    #           args.add(dep)

    # module_links_depset = depset(order="postorder", transitive = merged_module_links_depsets)
    # for dep in module_links_depset.to_list():
    #     if dep in ctx.files.deps:
    #         args.add(dep)

    ## FIXME: do we need the resolver for sigfiles?
    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
        ## this will only be the case if this is a submodule of an nslib
        args.add("-no-alias-deps")
        args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    args.add("-c")
    args.add("-o", out_cmi)

    if ctx.attr.ppx:
        sigfile = impl_ppx_transform("ocaml_signature", ctx, ctx.file.src, module_name + ".mli")
    # elif module_name != from_name:
    #     sigfile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")
    else:
        sigfile = ctx.file.src

    #     ## cp source file to workdir (__obazl)
    #     ## this is necessary for .mli/.cmi resolution to work
    #     # sigfile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")

    args.add("-intf", sigfile)

    input_depset = depset(
        direct = [sigfile],
        transitive = merged_depgraph_depsets
    )

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

    defaultInfo = DefaultInfo(
        files = depset(
            order="postorder",
            direct = [out_cmi] # must produce a single file to work with ocaml_module.sig
        )
    )

    sigProvider = OcamlSignatureProvider(
        mli = sigfile,
        cmi = out_cmi,
        module_links     = depset(
            order = "postorder",
            transitive = merged_module_links_depsets
        ),
        archive_links = depset(
            order = "postorder",
            transitive = merged_archive_links_depsets
        ),
        paths    = depset(
            direct = includes + [out_cmi.dirname],
            transitive = merged_paths_depsets
        ),
        depgraph = depset(
            order = "postorder",
            direct = [out_cmi, sigfile],
            transitive = merged_depgraph_depsets
        ),
        archived_modules = depset(
            order = "postorder",
            transitive = merged_archived_modules_depsets
        ),
    )

    opamProvider = OpamDepsProvider(
        pkgs = opam_depset
    )

    ## FIXME: catch incompatible key dups
    cclibs = {}
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs

    )
    # print("OUTPUT CCPROVIDER: %s" % ccProvider)

    return [
        defaultInfo,
        sigProvider,
        opamProvider,
        ccProvider
    ]

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
| @ocaml//interface:thread | True | `-thread`, `-no-thread`|
| @ocaml//interface:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value |

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        rule_options,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//signature/linkall"), # FIXME: call it alwayslink?
        _thread     = attr.label(default = "@ocaml//signature/thread"),
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
                [OcamlArchiveProvider],
                [OcamlImportProvider],
                [OcamlLibraryProvider],
                [OcamlModuleProvider],
                [OcamlNsArchiveProvider],
                [OcamlNsLibraryProvider],
                [OcamlSignatureProvider],
                [PpxArchiveProvider],
                [PpxModuleProvider],
                [PpxNsArchiveProvider],
                [PpxNsLibraryProvider],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        deps_opam = attr.string_list(
            doc = "List of OPAM package names"
        ),
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
        _opam_lib = attr.label(
            default = "@opam//:opam_lib"
        )
    ),
    incompatible_use_toolchain_transition = True,
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
