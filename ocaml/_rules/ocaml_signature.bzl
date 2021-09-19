load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",

     "AdjunctDepsMarker",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsArchiveMarker",
     "OcamlNsLibraryMarker",
     "OcamlNsResolverProvider",
     # "OcamlPathsMarker",
     "OcamlSDK",
     "OcamlSignatureProvider",

     "PpxArchiveMarker",
     "PpxModuleMarker",
     "PpxNsArchiveMarker",
     "PpxNsLibraryMarker")

# load("//ocaml:providers.bzl",
#      "OcamlImportMarker",
#      "OcamlImportArchivesMarker",
#      "OcamlImportPluginsMarker",
#      "OcamlImportSignaturesMarker",
#      "OcamlImportPathsMarker",
#      "OcamlImportPpxAdjunctsMarker")

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

    # if debug:
    #     print("MDEPS: %s" % mdeps)
    # merge_deps(mdeps,
    #            merged_module_links_depsets,
    #            merged_archive_links_depsets,
    #            merged_paths_depsets,
    #            merged_depgraph_depsets,
    #            merged_archived_modules_depsets,
    #            # indirect_file_depsets,
    #            # indirect_archive_depsets,
    #            # indirect_path_depsets,
    #            # indirect_opam_depsets,
    #            indirect_adjunct_depsets,
    #            indirect_adjunct_path_depsets,
    #            # indirect_adjunct_opam_depsets,
    #            indirect_cc_deps)

    if ctx.attr.pack:
        args.add("-linkpkg")

    # opam_depset = depset(direct = ctx.attr.deps_opam,
    #                      transitive = indirect_opam_depsets)
    # if using_ocamlfind:
    #     for opam in opam_depset.to_list():
    #         args.add("-package", opam)  ## add dirs to search path

    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[AdjunctDepsMarker]
        # if using_ocamlfind:
        #     for opam in provider.opam.to_list():
        #         args.add("-package", opam)

        for nopam in provider.nopam.to_list():
            adjunct_deps.append(nopam)
            # if OcamlImportArchivesMarker in nopam:
            #     adjuncts = nopam[OcamlImportArchivesMarker].archives
            #     for f in adjuncts.to_list():
            if nopam.extension in ["cmxa", "a"]:
                if (nopam.path.startswith(opam_lib_prefix)):
                    dir = paths.relativize(nopam.dirname, opam_lib_prefix)
                    includes.append( "+../" + dir )
                else:
                    includes.append(nopam.dirname)
                args.add(nopam.path)
            # for nopamfile in nopam.files.to_list():
                # adjunct_deps.append(nopamfile)

        # for path in provider.nopam_paths.to_list():
        #     args.add("-I", path)

    # indirect_paths_depset = depset(transitive = merged_paths_depsets)
    # for apath in indirect_paths_depset.to_list():
    #     if (apath.startswith(opam_lib_prefix)):
    #         dir = paths.relativize(apath, opam_lib_prefix)
    #         includes.append( "+../" + dir )
    #     else:
    #         includes.append( apath )
    # # for path in indirect_paths_depset.to_list():
    # #     includes.append(path)

    includes.append(out_cmi.dirname)

    # if not using_ocamlfind:
    # imports_test = depset(transitive = merged_depgraph_depsets)
    # for f in imports_test.to_list():
    #     # FIXME: only relativize ocaml_imports
    #     if (f.extension == "cmxa"):
    #         # print("relativizing %s" % f.path)
    #         if f.dirname.startswith(opam_lib_prefix):
    #             dir = paths.relativize(f.dirname, opam_lib_prefix)
    #             includes.append( "+../" + dir )

                # ctx.attr._opam_lib[BuildSettingInfo].value + "/" + dir
        # includes.append(f.path)

    if ctx.attr.pack:
        args.add("-for-pack", ctx.attr.pack)

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

        # ################ Paths ################
        # if OcamlPathsMarker in dep:
        #     ps = dep[OcamlPathsMarker].paths
        #     print("MPATHS: %s" % ps)
        #     paths_indirect.append(ps)

        # ################ Archive Deps ################
        # if OcamlArchiveMarker in dep:
        #     all_deps_list.append(dep[OcamlArchiveMarker].files)

        # ################ module deps ################
        # if OcamlModuleMarker in dep:
        #     all_deps_list.append(dep[OcamlModuleMarker].files)
        #     # all_deps_list.append(dep[OcamlModuleMarker].deps)

    # order should not matter, it's already encoded in depsets
    all_deps = depset(
        order = dsorder,
        transitive = all_deps_list
    )

    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = paths_indirect
    )

    # print("ALL_DEPS for MODULE %s" % ctx.label)
    # for d in reversed(all_deps.to_list()):
    # _paths = depset(transitive=paths_indirect).to_list()
    link_args = []
    for f in all_deps.to_list():
        # print("ALL_DEPS: %s" % f)
        if f.extension not in ["cmi", "mli", "ml", "a", "o"]:
            if (f.path.startswith(opam_lib_prefix)):
                dir = paths.relativize(f.dirname, opam_lib_prefix)
                # _paths.append( "+../" + dir )
                link_args.append(f.path)
            else:
                # _paths.append( f.dirname )
                link_args.append(f.path)

    args.add_all(paths_depset.to_list(), before_each="-I")
    args.add_all(link_args)

    # ## use depsets to get the right ordering. filter to limit to direct deps.
    # archive_links_depset = depset(transitive = merged_archive_links_depsets)
    # link_deps = []
    # for link in ctx.files.deps:
    #     link_deps.append(link.basename)
    # if debug:
    #     print("DEP LINKS: %s" % link_deps)

    # for dep in archive_links_depset.to_list():
    #     includes.append(dep.dirname)
    #     if dep.extension in ["cmxa", "a"]:
    #         if (dep.path.startswith(opam_lib_prefix)):
    #             dir = paths.relativize(dep.dirname, opam_lib_prefix)
    #             includes.append( "+../" + dir )
    #         else:
    #             includes.append(dep.dirname)
    #         args.add(dep.basename) # path)

        # if debug:
        #     print("DEP: %s" % dep)
        # if dep.basename in link_deps:
        #       args.add(dep)

    # module_links_depset = depset(order=dsorder, transitive = merged_module_links_depsets)
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

    defaultInfo = DefaultInfo(
        files = depset(
            order=dsorder,
            direct = [out_cmi] # must produce a single file to work with ocaml_module.sig
        )
    )

    sigProvider = OcamlSignatureProvider(
        mli = mlifile, # sigfile,
        cmi = out_cmi,
        # module_links     = depset(
        #     order = dsorder,
        #     transitive = merged_module_links_depsets
        # ),
        # archive_links = depset(
        #     order = dsorder,
        #     transitive = merged_archive_links_depsets
        # ),
        # paths    = depset(
        #     direct = includes + [out_cmi.dirname],
        #     transitive = merged_paths_depsets
        # ),
        # depgraph = depset(
        #     order = dsorder,
        #     direct = [out_cmi, mlifile], # sigfile],
        #     transitive = merged_depgraph_depsets
        # ),
        # archived_modules = depset(
        #     order = dsorder,
        #     transitive = merged_archived_modules_depsets
        # ),
    )

    # opamMarker = OpamDepsMarker(
    #     pkgs = opam_depset
    # )

    ## FIXME: catch incompatible key dups
    cclibs = {}
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        ccdeps_map = cclibs

    )
    # print("OUTPUT CCPROVIDER: %s" % ccProvider)

    ocamlProvider = OcamlProvider(
        files = depset(
            order  = dsorder,
            direct = [out_cmi], # mli?
            transitive = [all_deps]
        ),
        paths = paths_depset
    )

    return [
        defaultInfo,
        ocamlProvider,
        sigProvider,
        # opamMarker,
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
                [OcamlArchiveMarker],
                [OcamlImportMarker],
                [OcamlLibraryMarker],
                [OcamlModuleMarker],
                [OcamlNsArchiveMarker],
                [OcamlNsLibraryMarker],
                [PpxArchiveMarker],
                [PpxModuleMarker],
                [PpxNsArchiveMarker],
                [PpxNsLibraryMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        # deps_opam = attr.string_list(
        #     doc = "List of OPAM package names"
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
