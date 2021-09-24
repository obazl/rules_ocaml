load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "AdjunctDepsMarker",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlArchiveMarker",
     "OcamlModuleMarker",
     "OcamlNsResolverProvider",
     "OcamlSignatureMarker",
     # "OpamDepsMarker",
     "OcamlSDK",
     "PpxModuleMarker")

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
     "dsorder",
     "merge_deps",
     "tmpdir")

scope = tmpdir

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
    if ctx.label.name == "_Tacarg":
        debug = True
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
                    print("ADDING CC DEP: %s" % depfile.dirname)
                    cclib_deps.append(depfile)
                    if for_pack:
                        print("LINKING CC DEP: %s" % depfile)
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
def impl_pack_library(ctx):

    debug = False
    if ctx.label.name in ["_Tacarg"]:
        debug = True

    # if normalize_module_name(ctx.label.name) != normalize_module_name(ctx.file.struct.basename):
    #     print("Rule name: %s" % normalize_module_name(ctx.label.name))
    #     print("Structname: %s" % normalize_module_name(ctx.file.struct.basename))
    #     fail("Rule name and structfile name must yield same module name. Rule name may be prefixed with one or more underscores ('_'). Rule name: {rn}; structfile: {s}".format(rn=ctx.label.name, s=ctx.file.struct.basename))

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
            fail("Unexpected rule for 'impl_pack_library': %s" % ctx.attr._rule)

        print("  _NS_RESOLVER: %s" % ctx.attr._ns_resolver[DefaultInfo])
        print("  _NS_RESOLVER Marker: %s" % ctx.attr._ns_resolver[OcamlNsResolverProvider])
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

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ext  = ".cmx" if  mode == "native" else ".cmo"

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
    outputs   = []

    module_name = ctx.label.name

    out_cm_ = ctx.actions.declare_file(scope + module_name + ext) # fname)
    outputs.append(out_cm_)
    out_cmi = ctx.actions.declare_file(scope + module_name + ".cmi")
    outputs.append(out_cmi)

    if mode == "native":
        out_o = ctx.actions.declare_file(tmpdir + module_name + ".o")
        outputs.append(out_o)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    _options = get_options(ctx.attr._rule, ctx)
    # if "-thread" in _options:  ## FIXME: TESTING
    #     _options.remove("-thread")

    # if "-for-pack" in _options:
    #     for_pack = True
    #     _options.remove("-for-pack")
    # else:
    #     for_pack = False
    args.add_all(_options)

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
                    False,  #  -for-pack
                    tc.linkmode,
                    cc_deps_dict,
                    args,
                    includes,
                    cclib_deps,
                    cc_runfiles)

    if "-g" in _options:
        args.add("-runtime-variant", "d")

    # args.add("-linkpkg")

    # opam_depset = depset(# direct = ctx.attr.deps_opam,
    #                      transitive = indirect_opam_depsets)
    # for opam in opam_depset.to_list():
    #     args.add("-package", opam)  ## add dirs to search path

    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []

    indirect_paths_depset = depset(transitive = merged_paths_depsets)
    for path in indirect_paths_depset.to_list():
        includes.append(path)

    # if ctx.attr.ppx:
    #     structfile = impl_ppx_transform(ctx.attr._rule, ctx, ctx.file.struct, module_name + ".ml")
    # else:
    #     ## cp src file to working dir (__obazl)
    #     ## this is necessary for .mli/.cmi resolution to work
    #     structfile = rename_srcfile(ctx, ctx.file.struct, module_name + ".ml")
    #     # structfile = ctx.file.struct

    if debug:
        print("INCLUDES: %s" % includes)

    # args.add_all(includes, before_each="-I", uniquify = True)

    args.add("-pack")
        # else:
        #     args.add("-c")
    args.add("-o", out_cm_)

    ## use depsets to get the right ordering. filter to limit to direct deps.
    module_links_depset = depset(transitive = merged_module_links_depsets)
    for dep in module_links_depset.to_list():
        if dep in ctx.files.deps:
            args.add(dep)

    # if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
    #     ## this will only be the case if this is a submodule of an nslib
    #     args.add("-no-alias-deps")
    #     args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    # if ctx.attr.for_pack:
    #     args.add("-for-pack", ctx.attr.pack)
    #     args.add("-c")
    #     args.add("-o", out_cm_)
    # else:
    #     if "-pack" in _options:

    # args.add("-impl", structfile)

    inputs_depset = depset(
        order = dsorder,
        direct = cclib_deps,
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
        executable = tc.ocamlfind,
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
            order = dsorder,
            direct = [out_cm_],
        ),
    )

    if (ctx.attr._rule == "ocaml_pack_library"):
        moduleMarker = OcamlModuleMarker(
            module_links     = depset(
                order = dsorder,
                direct = [out_cm_],
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = dsorder,
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = includes + [out_cm_.dirname], ## depset will uniquify includes
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = dsorder,
                direct = outputs + [out_cmi],
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = dsorder,
                transitive = merged_archived_modules_depsets
            ),
        )
    elif ctx.attr._rule == "ppx_module" or ctx.attr._rule == "ppx_submodule":
        moduleMarker = PpxModuleMarker(
            module_links     = depset(
                order = dsorder,
                direct = [out_cm_],
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = dsorder,
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                direct = includes + [out_cm_.dirname], ## depset will uniquify includes
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = dsorder,
                direct = outputs,
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = dsorder,
                transitive = merged_archived_modules_depsets
            ),
        )

    # opamMarker = OpamDepsMarker(
    #     pkgs = opam_depset
    # )

    adjunctsMarker = AdjunctDepsMarker(
        # opam        = depset(transitive = indirect_adjunct_opam_depsets),
        nopam       = depset(transitive = indirect_adjunct_depsets),
        nopam_paths = depset(transitive = indirect_adjunct_path_depsets)
    )

    ## FIXME: catch incompatible key dups
    cclibs = {}
    cclibs.update(ctx.attr.cc_deps)
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccMarker = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs

    )
    print("OUTPUT CCPROVIDER: %s" % ccMarker)

    return [
        defaultInfo,
        moduleMarker,
        # opamMarker,
        adjunctsMarker,
        ccMarker
    ]
