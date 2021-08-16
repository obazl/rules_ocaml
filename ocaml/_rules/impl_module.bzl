load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlArchiveProvider",
     "OcamlModuleProvider",
     "OcamlNsResolverProvider",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "OcamlSDK",
     "PpxModuleProvider")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load("//ocaml/_rules/utils:utils.bzl",
     "get_options",
     )

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "file_to_lib_name",
     "get_opamroot",
     "get_sdkpath",
     "normalize_module_name",
)

load(":impl_common.bzl",
     "merge_deps",
     # "tmpdir"
     )

scope = "" # tmpdir

################################################################
def _handle_cc_deps(ctx,
                    for_pack,
                    default_linkmode,
                    cc_deps_dict, ## list of dicts
                    args,
                    includes,
                    cclib_deps,
                    cc_runfiles):

    ## FIXME: static v. dynamic linking of cc libs in bytecode mode
    # see https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss%3Adynlink-c-code

    # default linkmode for toolchain is determined by platform
    # see @ocaml//toolchain:BUILD.bazel, ocaml/_toolchains/*.bzl
    # dynamic linking does not currently work on the mac - ocamlrun
    # wants a file named 'dllfoo.so', which rust cannot produce. to
    # support this we would need to rename the file using install_name_tool
    # for macos linkmode is dynamic, so we need to override this for bytecode mode

    debug = False
    # if ctx.attr._rule == "ocaml_executable":
    # if ctx.label.name == "_Tacarg":
    #     debug = True
    if debug:
        print("EXEC _handle_cc_deps %s" % ctx.label)
        print("CC_DEPS_DICT: %s" % cc_deps_dict)

    # first dedup
    ccdeps = {}
    for ccdict in cclib_deps:
        for [dep, linkmode] in ccdict.items():
            if dep in ccdeps.keys():
                if debug:
                    print("CCDEP DUP? %s" % dep)
            else:
                ccdeps.update({dep: linkmode})

    for [dep, linkmode] in cc_deps_dict.items():
        if debug:
            print("CCLIB DEP: ")
            print(dep)
        if linkmode == "default":
            if debug: print("DEFAULT LINKMODE: %s" % default_linkmode)
            for depfile in dep.files.to_list():
                if default_linkmode == "static":
                    if (depfile.extension == "a"):
                        args.add(depfile)
                        cclib_deps.append(depfile)
                        includes.append(depfile.dirname)
                else:
                    for depfile in dep.files.to_list():
                        if (depfile.extension == "so"):
                            libname = file_to_lib_name(depfile)
                            args.add("-ccopt", "-L" + depfile.dirname)
                            args.add("-cclib", "-l" + libname)
                            cclib_deps.append(depfile)
                        elif (depfile.extension == "dylib"):
                            libname = file_to_lib_name(depfile)
                            args.add("-cclib", "-l" + libname)
                            args.add("-ccopt", "-L" + depfile.dirname)
                            cclib_deps.append(depfile)
                            cc_runfiles.append(dep.files)
        elif linkmode == "static":
            if debug:
                print("STATIC lib: %s:" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "a"):
                    # print("ADDING CC DEP: %s" % depfile.dirname)
                    cclib_deps.append(depfile)
                    if for_pack:
                        # print("LINKING CC DEP: %s" % depfile)
                        args.add(depfile)
                        includes.append(depfile.dirname)
        elif linkmode == "static-linkall":
            if debug:
                print("STATIC LINKALL lib: %s:" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "a"):
                    cclib_deps.append(depfile)
                    includes.append(depfile.dirname)
                    if ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"].cc_toolchain == "clang":
                        args.add("-ccopt", "-Wl,-force_load,{path}".format(path = depfile.path))
                    elif ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"].cc_toolchain == "gcc":
                        libname = file_to_lib_name(depfile)
                        args.add("-ccopt", "-L{dir}".format(dir=depfile.dirname))
                        args.add("-ccopt", "-Wl,--push-state,-whole-archive")
                        args.add("-ccopt", "-l{lib}".format(lib=libname))
                        args.add("-ccopt", "-Wl,--pop-state")
                    else:
                        fail("NO CC")

        elif linkmode == "dynamic":
            if debug:
                print("DYNAMIC lib: %s" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "so"):
                    libname = file_to_lib_name(depfile)
                    print("so LIBNAME: %s" % libname)
                    args.add("-ccopt", "-L" + depfile.dirname)
                    args.add("-cclib", "-l" + libname)
                    cclib_deps.append(depfile)
                elif (depfile.extension == "dylib"):
                    libname = file_to_lib_name(depfile)
                    print("LIBNAME: %s:" % libname)
                    args.add("-cclib", "-l" + libname)
                    args.add("-ccopt", "-L" + depfile.dirname)
                    cclib_deps.append(depfile)
                    cc_runfiles.append(dep.files)

#####################
def impl_module(ctx):

    debug = False
    # if ctx.label.name in ["_Tactic_debug"]:
    #     print("CTX LABEL: %s" % ctx.label)
        # debug = True

    if normalize_module_name(ctx.label.name) != normalize_module_name(ctx.file.struct.basename):
        print("Rule name: %s" % normalize_module_name(ctx.label.name))
        print("Structname: %s" % normalize_module_name(ctx.file.struct.basename))
        fail("Rule name and structfile name must yield same module name. Rule name may be prefixed with one or more underscores ('_'). Rule name: {rn}; structfile: {s}".format(rn=ctx.label.name, s=ctx.file.struct.basename))

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
        print("  _NS_RESOLVER Provider: %s" % ctx.attr._ns_resolver[OcamlNsResolverProvider])
        ns_prefixes     = ctx.attr._ns_prefixes[BuildSettingInfo].value
        ns_submodules = ctx.attr._ns_submodules[BuildSettingInfo].value
        print("  _NS_PREFIXES: %s" % ns_prefixes)
        print("  _NS_SUBMODULES: %s" % ns_submodules)

    ## FIXME: use a build flag to pass these dirs.
    ## topdirs.cmi, digestif.cmi, ...
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

    ext  = ".cmx" if  mode == "native" else ".cmo"

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
    outputs   = []

    (from_name, module_name) = get_module_name(ctx, ctx.file.struct)

    out_cm_ = ctx.actions.declare_file(scope + module_name + ext) # fname)
    outputs.append(out_cm_)

    if mode == "native":
        out_o = ctx.actions.declare_file(scope + module_name + ".o")
        outputs.append(out_o)

    mlifile = None
    if ctx.attr.sig:
        # we pass on the sigfile we recd as output.
        # copy it (and .mli) to same outdir as module so that .mli/.cmi resolution will work
        sigProvider = ctx.attr.sig[OcamlSignatureProvider]
        out_cmi = sigProvider.cmi
        # mlifile = sigProvider.mli
        # print("IN SIG: %s" % sigProvider.mli)
        if sigProvider.mli.is_source:  # not a generated file
            mlifile = rename_srcfile(ctx, sigProvider.mli, normalize_module_name(sigProvider.mli.basename) + ".mli")
            # print("OUT SIG: %s" % mlifile)

        # sigProvider = ctx.attr.sig[0][OcamlSignatureProvider]
        # if ctx.attr._rule == "ocaml_module":
        #     sigProvider = ctx.attr.sig[OcamlSignatureProvider]
        # elif ctx.attr._rule == "ppx_module":
        #     sigProvider = ctx.attr.sig[OcamlSignatureProvider]
        # elif ctx.attr._rule == "ocaml_submodule":
        #     sigProvider = ctx.attr.sig[0][OcamlSignatureProvider]
        # elif ctx.attr._rule == "ppx_submodule":
        #     sigProvider = ctx.attr.sig[0][OcamlSignatureProvider]
        # if ctx.file.sig.dirname == out_cm_.dirname:
        #     mlifile = sigProvider.mli
        #     out_cmi = sigProvider.cmi
        # else:
        #     # print("REWRITING %s" % sigProvider)
        #     mlifile = sigProvider.mli
        #     out_cmi = sigProvider.cmi
        #     # mlifile = rename_srcfile(ctx, sigProvider.mli, sigProvider.mli.basename)
        #     # out_cmi = rename_srcfile(ctx, sigProvider.cmi, sigProvider.cmi.basename)
    else:
        ## no sigfile provided: compiler will infer and emit .cmi from .ml src,
        ## so we need to add the output file
        out_cmi = ctx.actions.declare_file(scope + module_name + ".cmi")
        outputs.append(out_cmi)

    #########################
    args = ctx.actions.args()

    if using_ocamlfind:
        if mode == "native":
            args.add(tc.ocamlopt.basename)
        else:
            args.add(tc.ocamlc.basename)

    _options = get_options(ctx.attr._rule, ctx)
    # if "-for-pack" in _options:
    #     for_pack = True
    #     _options.remove("-for-pack")
    # else:
    #     for_pack = False
    args.add_all(_options)

    if "-bin-annot" in _options: ## Issue #17
        out_cmt = ctx.actions.declare_file(scope + paths.replace_extension(module_name, ".cmt"))
        outputs.append(out_cmt)

    mdeps = []
    mdeps.extend(ctx.attr.deps)
    mdeps.append(ctx.attr._ns_resolver)
    mdeps.append(ctx.attr.cc_deps)
    if ctx.attr.sig:
        mdeps.append(ctx.attr.sig)

    if debug:
        print("MDEPS: %s" % mdeps)
    merge_deps(mdeps,
               merged_module_links_depsets,
               merged_archive_links_depsets,
               merged_paths_depsets,
               merged_depgraph_depsets,
               merged_archived_modules_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    # print("MERGED INDIRECT_CC_DEPS: %s" % indirect_cc_deps)
    # if debug:
    #     print("Merged depgraph depsets:")
    #     print(merged_depgraph_depsets)

    # if we have an input cmi, we will pass it on as Provider output,
    # but it is not an output of this action- do NOT add incoming cmi to action outputs
    ## TODO: support compile of mli source
    # if ctx.attr.sig:
    #     # args.add("-intf", ctx.file.sig)
    #     for f in ctx.attr.sig:
    #         merged_module_links_depsets.append(f[OcamlSignatureProvider].module_links)
    #         merged_archive_links_depsets.append(f[OcamlSignatureProvider].archive_links)
    #         merged_paths_depsets.append(f[OcamlSignatureProvider].paths)
    #         merged_depgraph_depsets.append(f[OcamlSignatureProvider].depgraph)
    #         merged_archived_modules_depsets.append(f[OcamlSignatureProvider].archived_modules)

    # if debug:
    #     print("BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
    #     print(merged_depgraph_depsets)

    if debug:
        print("INCLUDES: %s" % includes)

    cclib_deps  = []
    direct_cc_deps    = {}
    direct_cc_deps.update(ctx.attr.cc_deps)

    cc_runfiles = []
    cc_deps_dict = {}
    cc_deps_dict.update(direct_cc_deps)
    cc_deps_dict.update(indirect_cc_deps)
    _handle_cc_deps(ctx,
                    True if ctx.attr.pack else False,
                    tc.linkmode,
                    cc_deps_dict,
                    args,
                    includes,
                    cclib_deps,
                    cc_runfiles)

    # if "-g" in _options:
    #     args.add("-runtime-variant", "d")
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
            print("NOPAM ADJUNCT: %s" % nopam)
            adjunct_deps.append(nopam)
            # for nopamfile in nopam.files.to_list():
            #     adjunct_deps.append(nopamfile)
        for path in provider.nopam_paths.to_list():
            args.add("-I", path)

    for adjunct in adjunct_deps:
        if adjunct.extension == "cmxa":
            # print("ADJUNCT path: %s" % adjunct.path)
            # print("ADJUNCT short-path: %s" % adjunct.short_path)
            dir = paths.relativize(adjunct.dirname, "external/opam/_lib")
            includes.append(
                ctx.attr._opam_lib[BuildSettingInfo].value + "/" + dir
            )
            args.add(adjunct.path)

    indirect_paths_depset = depset(transitive = merged_paths_depsets)
    for path in indirect_paths_depset.to_list():
        includes.append(path)

    if not using_ocamlfind:
        imports_test = depset(transitive = merged_depgraph_depsets)
        for f in imports_test.to_list():
            if f.extension == "cmxa":
                # print("relativizing %s" % f.path)
                dir = paths.relativize(f.dirname, "external/opam/_lib")
                includes.append( ctx.attr._opam_lib[BuildSettingInfo].value + "/" + dir )
            else:
                includes.append( f.dirname)

    if ctx.attr.ppx:
        structfile = impl_ppx_transform(ctx.attr._rule, ctx, ctx.file.struct, module_name + ".ml")
    else:
        structfile = ctx.file.struct
        ## cp src file to working dir (__obazl)
        ## this is necessary for .mli/.cmi resolution to work
        # structfile = rename_srcfile(ctx, ctx.file.struct, module_name + ".ml")

    if debug:
        print("INCLUDES: %s" % includes)

    if ctx.attr.pack:
        args.add("-for-pack", ctx.attr.pack)

    args.add_all(includes, before_each="-I", uniquify = True)

    ## use depsets to get the right ordering. filter to limit to direct deps.
    # module_links_depset = depset(transitive = merged_module_links_depsets)
    # for dep in module_links_depset.to_list():
    #     args.add(dep)
        # if ctx.attr.pack:
        #     if dep in ctx.files.deps:
        #         args.add(dep)
        # else:
        #     if dep in ctx.files.deps:
        #         args.add(dep)

    # archive_links_depset = depset(transitive = merged_archive_links_depsets)
    # if debug:
    #     print("DEPS: %s" % ctx.files.deps)
    # for dep in archive_links_depset.to_list():
    #     if debug:
    #         print("ARCHIVE LINK: %s" % dep.path)
    #     if dep in ctx.files.deps:
    #         args.add(dep.path)

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
        ## this will only be the case if this is a submodule of an nslib
        args.add("-no-alias-deps")
        args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    # if "-shared" in _options:
    #     args.add("-shared")
    # else:
    args.add("-c")
    args.add("-o", out_cm_)

    args.add("-impl", structfile)

    ## if we rec'd a .cmi sigfile, we must add its SOURCE file to the dep graph!
    ## otherwise the ocaml compiler will not use the cmx file, it will generate
    ## one from the module source.
    mli = [mlifile] if mlifile else []

    ## runtime deps must be added to the depgraph (so they get built),
    ## but not the command line (they are not build-time deps).
    inputs_depset = depset(
        order = "postorder",
        direct = [structfile] + mli + cclib_deps + ctx.files.deps_runtime + adjunct_deps,
        transitive = merged_depgraph_depsets
    )
        # NB: these are NOT in the depgraph: cc_direct_depfiles + adjunct_deps + ctx.files.ppx,
        # Why not? cc deps need only be built for executable targets
        # adjunct deps are not needed to build this target
        # ppx has already been used above to transform source, not needed to build transformed source

    ################
    ################
    ctx.actions.run(
        env = env,
        executable = exe, ## tc.ocamlfind,
        arguments = [args],
        inputs    = inputs_depset,
        outputs   = outputs,
        tools = [tc.ocamlfind, tc.ocamlopt, tc.ocamlc],
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
    ################

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            direct = outputs + [out_cmi] + mli
        ),
    )

    if (ctx.attr._rule == "ocaml_module"):
        moduleProvider = OcamlModuleProvider(
            module_links     = depset(
                order = "postorder",
                direct = [out_cm_],
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = "postorder",
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = includes + [out_cm_.dirname], ## depset will uniquify includes
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                direct = outputs + [structfile, out_cmi] + mli,
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = merged_archived_modules_depsets
            ),
        )
    elif ctx.attr._rule == "ppx_module":
        moduleProvider = PpxModuleProvider(
            module_links     = depset(
                order = "postorder",
                direct = [out_cm_],
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = "postorder",
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = includes + [out_cm_.dirname], ## depset will uniquify includes
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                direct = outputs + [structfile] + mli,
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

    adjunctsProvider = AdjunctDepsProvider(
        opam        = depset(transitive = indirect_adjunct_opam_depsets),
        nopam       = depset(
            direct = adjunct_deps,
            transitive = indirect_adjunct_depsets
        ),
        nopam_paths = depset(transitive = indirect_adjunct_path_depsets)
    )
    print("MODULE ADJUNCTS PROVIDER: %s" % adjunctsProvider)

    ## FIXME: catch incompatible key dups
    cclibs = {}
    cclibs.update(ctx.attr.cc_deps)
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs

    )
    # print("OUTPUT CCPROVIDER: %s" % ccProvider)

    return [
        defaultInfo,
        moduleProvider,
        opamProvider,
        adjunctsProvider,
        ccProvider
    ]
