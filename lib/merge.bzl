load("@rules_ocaml//build:providers.bzl",
     "OCamlCcInfo",
     "OCamlCodepsProvider",
     "OCamlImportProvider",
     "OCamlLibraryProvider",
     # "OCamlModuleProvider",
     "OCamlDepsProvider",
     "OCamlNsResolverProvider",
     "OCamlSignatureProvider")

load("@rules_ocaml//build/_providers:MergedDepsProvider.bzl",
     "MergedDepsProvider")

load("@rules_ocaml//build/_lib:ccdeps.bzl",
     "cc_shared_lib_to_ccinfo",
     "normalize_ccinfo",
     "extract_cclibs", "dump_CcInfo")

COMPILE      = 0
LINK         = 1
COMPILE_LINK = 2

################################################################
def dump_ocamlinfo(bi):
    print("sigs: %s" % bi.sigs)
    print("structs: %s" % bi.structs)
    print("linkdeps: %s" % bi.cli_link_deps)

##########################
def _DepsAggregator_init(*,
                         deps             = None,
                         codeps           = None,
                         compile_codeps   = None,
                         link_codeps      = None,
                         ccinfos          = None,
                         ccinfos_archived = None,
                         cc_dsos = None):
    return {
        "deps"             : MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            link_archives_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmxs          = [],
            cmts          = [],
            cmtis         = [],
            srcs          = [],
            cc_dsos       = [],
            paths         = [],
            jsoo_runtimes = [], # depset(),
            runfiles      = []
        ),
        "codeps"           : MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            link_archives_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmxs          = [],
            cmts          = [],
            cmtis         = [],
            srcs          = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        "compile_codeps"   : MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            link_archives_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmxs          = [],
            cmts          = [],
            cmtis         = [],
            srcs          = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        "link_codeps"      : MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            link_archives_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmxs          = [],
            cmts          = [],
            cmtis         = [],
            srcs          = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        "ccinfos"          : [],
        "ccinfos_archived" : [],
        "cc_dsos"  : []
    }

DepsAggregator, _new_depsaggregator = provider(
    init = _DepsAggregator_init,
    fields = {
        "deps"             : "struct of MergedDepsProvider providers",
        "codeps"           : "an MergedDepsProvider provider",
        "compile_codeps"   : "an MergedDepsProvider provider",
        "link_codeps"      : "an MergedDepsProvider provider",
        "ccinfos"          : "list of CcInfo providers",
        "ccinfos_archived" : "list of ccinfos whose metadata is archived",
        "cc_dsos"          : "list of shared (.so) objs",
    }
)

################################################################
## puts everthing into codeps providers
def aggregate_codeps(ctx,
                     kind,   # Compile or Link
                     target, # a Target
                     depsets, # a struct
                     manifest = False): # target will be added to archive

    debug = False
    if debug:
        print("aggregate_codeps: %s" % target)

    # print("PPXCOD: %s" % target)
    # if target.label.name == "config":
    # if target.label.name == "runtime-lib":
    #     print("codep archives: %s" % target[OCamlDepsProvider].archives)
    #     print("codep astructs: %s" % target[OCamlDepsProvider].astructs)
    #     if OCamlCodepsProvider in target:
    #         print("ppx: %s" % target[OCamlCodepsProvider])
    #     fail(target)

    if kind == COMPILE:
        dset = depsets.compile_codeps
    elif kind == LINK:
        dset = depsets.link_codeps
    elif kind == COMPILE_LINK:
        dset = depsets.codeps
    else:
        fail("Invalid kind: {}; must be COMPILE (0), LINK (1), or COMPILE_LINK (2)")

    if OCamlDepsProvider in target:
        provider = target[OCamlDepsProvider]
        depsets.codeps.sigs.append(provider.sigs)
        if provider.cli_link_deps != None:
            depsets.codeps.cli_link_deps.append(provider.cli_link_deps)
        if provider.link_archives_deps != None:
            depsets.codeps.link_archives_deps.append(
                provider.link_archives_deps)
        depsets.codeps.archives.append(provider.archives)
        depsets.codeps.afiles.append(provider.afiles)
        depsets.codeps.astructs.append(provider.astructs)
        if provider.ofiles != None:
            depsets.codeps.ofiles.append(provider.ofiles)
        if hasattr(provider, "cmxs"):
            if provider.cmxs != []:
                depsets.codeps.cmts.append(provider.cmxs)
        if hasattr(provider, "cmts"):
            if provider.cmts != []:
                depsets.codeps.cmts.append(provider.cmts)
        if hasattr(provider, "cmtis"):
            if provider.cmtis != []:
                depsets.codeps.cmtis.append(provider.cmtis)
        depsets.codeps.paths.append(provider.paths)
        if hasattr(provider, "jsoo_runtimes"):
            if provider.jsoo_runtimes != None:
                depsets.codeps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if OCamlCodepsProvider in target:
        provider = target[OCamlCodepsProvider]
        depsets.codeps.sigs.append(provider.sigs)
        if provider.cli_link_deps != None:
            depsets.codeps.cli_link_deps.append(provider.cli_link_deps)
        if provider.link_archives_deps != None:
            depsets.codeps.link_archives_deps.append(provider.link_archives_deps)
        depsets.codeps.structs.append(provider.structs)
        if provider.ofiles != None:
            depsets.codeps.ofiles.append(provider.ofiles)
        depsets.codeps.archives.append(provider.archives)
        depsets.codeps.afiles.append(provider.afiles)
        depsets.codeps.astructs.append(provider.astructs)
        if hasattr(provider, "cmxs"):
            if provider.cmxs != []:
                depsets.codeps.cmts.append(provider.cmxs)
        if hasattr(provider, "cmts"):
            if provider.cmts != []:
                depsets.codeps.cmts.append(provider.cmts)
        if hasattr(provider, "cmtis"):
            if provider.cmtis != []:
                depsets.codeps.cmtis.append(provider.cmtis)
        depsets.codeps.paths.append(provider.paths)
        if hasattr(provider, "jsoo_runtimes"):
            if provider.jsoo_runtimes != None:
                depsets.codeps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if CcInfo in target:
        ccInfo = target[CcInfo]
        if OCamlLibraryProvider in target:
            depsets.ccinfos_archived.append(ccInfo)
        elif OCamlImportProvider in target:
            # print("CoIMPORTP %s" % target)
            depsets.ccinfos_archived.append(ccInfo)
        else:
            depsets.ccinfos.append(ccInfo)

    if CcSharedLibraryInfo in target:
        fail("xxxxxxxxxxxxxxxx")

    # if target.label.name == "runtime-lib":
    #     print("depsets.deps.archives: %s" % depsets.deps.archives)
    #     print("depsets.deps.astructs: %s" % depsets.deps.astructs)
    #     print("depsets.codeps.archives: %s" % depsets.codeps.archives)
    #     print("depsets.codeps.astructs: %s" % depsets.codeps.astructs)
    #     fail(target)

    return depsets

################################
def merge_depsets(depsets, fld):
    # print("unmerged fld: %s" % getattr(depsets.deps, fld))
    merged = depset(transitive = getattr(depsets.deps, fld))
    # print("merged fld {f}: {m}".format(f=fld, m=merged))

    return merged


#######################
def merge_deps(ctx,
               target, # a Target
               depsets, # a struct
               manifest = []): # target will be added to archive

    #NB: for libs/archives, the manifest is derived directly from the
    #manifest attribute. but for modules and sigs, it is derived
    #indirectly from the ns resolver, so its empty for non-namespaced
    #objects, even if they are aggregated. IOW it serves two roles:
    #one as an ns-manifest for a namespace (a lib, maybe archived),
    #and one as an archive-manifest for a non-namespaced archive (in
    #which case it is not used by the component items.)

    debug = False
    debug_archives = False
    debug_ccinfo   = False # True if ctx.label.name == "Test" else False
    debug_runfiles = False
    # if target.label.name == "Ppxlib_driver":
    #     debug = True
    # if debug:

    # print("XXXXXXXXXXXXXXXX")
    # print(target)
    # fail("A")

    archiving = len(manifest) > 0

    module_archived = False
    # if OCamlModuleProvider in target:
    #     mInfo = target[OCamlModuleProvider]
    #     print("mInfo: %s" % mInfo)
    #     print("manifest: %s" % manifest)
    #     for item in manifest:
    #         print("item: %s" % item.label.name)
    #         if mInfo.name == item.label.name:
    #             module_archived = True

    # if OCamlModuleProvider in target:
    #     print("OCamlModuleProvider")
    # elif OCamlSignatureProvider in target:
    #     # sigs
    #     depsets.deps.mli.append(target[OCamlSignatureProvider].mli)

    #     provider = target[OCamlSignatureProvider].merged_deps
    # else:
    #     print("OTHER")

    # if debug_runfiles:
    #     print("module runfiles: %s" % target[DefaultInfo].default_runfiles.files)

    # if OCamlModuleProvider in target:


    ## FIXME: if there are out transitions involved,
    ## targets are indexed by ints, not providers!

    if (OCamlDepsProvider in target) or (type(target) == "list"):
        if OCamlDepsProvider in target:
            provider = target[OCamlDepsProvider]
            default_info = target[DefaultInfo]
        else:
            provider = target[0][OCamlDepsProvider]
            default_info = target[0][DefaultInfo]

        depsets.deps.runfiles.append(default_info.default_runfiles)

        # if ctx.label.name == "Expansion":
        #     print("target: %s" % target)
        #     for dep in provider.sigs.to_list():
        #         print("ASTRUCT: %s" % dep)
        #     fail("mmmmmmmmmmmmmmmm")

        ##TMP HACK:
        ## for 'main'dep of executable:
        ## MergedDepsProvider deps of 'main' must go first,
        ## before OCamlMainInfo of main module itself,
        ## to preserve correct link ordering
        if ctx.attr._rule == "ocaml_test": ##FIXME
            depsets.deps.cli_link_deps.append(provider.cli_link_deps)
            depsets.deps.link_archives_deps.append(provider.link_archives_deps)

        # if OCamlModuleProvider in target:
        #     module_archived = _handle_module_provider(
        #         manifest, target, provider, depsets)
        # else:
        if hasattr(provider, "cli_link_deps"): # tmp, for OCamlDepsProvider
            if provider.cli_link_deps != None:
                depsets.deps.cli_link_deps.append(provider.cli_link_deps)
        # if hasattr(provider, "cli_link_deps"):
        #     depsets.deps.cli_link_deps.append(provider.cli_link_deps)

        # if ctx.label.name == "Green":
        #     fail(provider)

        if hasattr(provider, "link_archives_deps"): # tmp, for OCamlDepsProvider
            if provider.link_archives_deps == None:
                print(ctx.label)
            if provider.link_archives_deps == []:
                fail(ctx.label)
            if provider.link_archives_deps != None:
                depsets.deps.link_archives_deps.append(provider.link_archives_deps)

        if hasattr(provider, "astructs"):
            if provider.astructs != None:
                depsets.deps.astructs.append(provider.astructs)

        depsets.deps.structs.append(provider.structs)

        if hasattr(provider, "sigs"):
            if provider.sigs != None:
                depsets.deps.sigs.append(provider.sigs)

        if hasattr(provider, "archives"):
            if provider.archives != None:
                depsets.deps.archives.append(provider.archives)

        if hasattr(provider, "afiles"):
            if provider.afiles != None:
                depsets.deps.afiles.append(provider.afiles)

        if not module_archived:
            if hasattr(provider, "structs"):
                if provider.structs != None:
                    depsets.deps.structs.append(provider.structs)

        # if manifest: # for OCamlModuleProvider only
        #     if debug_archives:
        #         print("archive manifest: %s" % manifest)
        #     if target in manifest:
        #         if debug_archives:
        #             print("TARGET IN MANIFEST: %s" % target)
        #             # if target.label.name == "Red":
        #             #     print("RED structs: %s" % provider.structs)
        #             # fail("testagddg")
        #         depsets.deps.astructs.append(provider.structs)
        #     else:
        #         depsets.deps.structs.append(provider.structs)
        # else:
        #     depsets.deps.structs.append(provider.structs)

        if hasattr(provider, "ofiles"):
            if provider.ofiles != None:
                depsets.deps.ofiles.append(provider.ofiles)

        if hasattr(provider, "srcs"):
            if provider.srcs != None:
                depsets.deps.srcs.append(provider.srcs)

        if hasattr(provider, "cmxs"):
            if provider.cmxs != []:
                # print(ctx.label)
                if provider.cmxs == None:
                    print(ctx.label)
                    fail("CMXS %s" % provider.cmxs)
                depsets.deps.cmxs.append(provider.cmxs)

        if hasattr(provider, "cmts"):
            if provider.cmts != []:
                # print(ctx.label)
                if provider.cmts == None:
                    print(ctx.label)
                    fail("CMT %s" % provider.cmts)
                depsets.deps.cmts.append(provider.cmts)

        if hasattr(provider, "cmtis"):
            if provider.cmtis != []:
                depsets.deps.cmtis.append(provider.cmtis)

        if hasattr(provider, "paths"):
            if provider.paths != None:
                depsets.deps.paths.append(provider.paths)

        if hasattr(provider, "jsoo_runtimes"):
            if provider.jsoo_runtimes != None:
                depsets.deps.jsoo_runtimes.append(provider.jsoo_runtimes)

        if hasattr(provider, "cc_dsos"):
            if provider.cc_dsos != None:
                depsets.deps.cc_dsos.append(provider.cc_dsos)

    ## end if OCamlDepsProvider in target FIXME: MergedDepsProvider

    ## Now ocaml_signature, ocaml_module
    if OCamlSignatureProvider in target:
        depsets.deps.mli.append(target[OCamlSignatureProvider].mli)

    ## ns resolvers
    if type(target) == "list":
        if OCamlNsResolverProvider in target[0]:
            if debug: print("ns resolver: %s" % target)
            # fail()
            provider = target[0][OCamlNsResolverProvider]
            depsets.deps.sigs.append(
                target[0][OCamlDepsProvider].sigs
                # provider.sigs
                # depset([provider.cmi])
            )
            # depsets.deps.archives.append(provider.archives)
            if hasattr(provider, "astructs"):
                depsets.deps.astructs.append(provider.astructs)
            depsets.deps.structs.append(depset([provider.struct]))
            # if manifest:
            #     depsets.deps.astructs.append(provider.structs)
            # else:
            #     depsets.deps.structs.append(provider.structs)
            if provider.ofile:
                depsets.deps.ofiles.append(depset([provider.ofile]))
            # if hasattr(provider, "cmts"):
            #     depsets.deps.cmts.append(provider.cmts)
            # depsets.deps.paths.append(provider.paths)

    ## if target is ctx.attr.ppx, then we want to put codeps in deps
    ## elif target is e.g. prologue of ppx_executable, put them in codeps
    ## BUT any target may have been preprocessed and
    ## thus have codeps
    if OCamlCodepsProvider in target:
        # print("AGGREGATING CODEPS FOR")
        # print("Target: %s" % target)
        provider = target[OCamlCodepsProvider]
        # if ctx.label.name == "ppx.exe":
        #     print("AGGREGATING PPXCODEPS FOR")
        #     print("Target: %s" % target)
        #     print("ARCHIVES: %s" % provider.archives)

        #if "ppx" in ctx.attr._tags:
        if ctx.attr._rule == "ppx_executable":
            depsets.codeps.sigs.append(provider.sigs)
        else:
            depsets.deps.sigs.append(provider.sigs)

        if provider.cli_link_deps != None:
            if ctx.attr._rule == "ppx_executable":
                depsets.codeps.cli_link_deps.append(provider.cli_link_deps)
            else:
                depsets.deps.cli_link_deps.append(provider.cli_link_deps)

        if provider.link_archives_deps != None:
            if ctx.attr._rule == "ppx_executable":
                depsets.codeps.link_archives_deps.append(provider.link_archives_deps)
            else:
                depsets.deps.link_archives_deps.append(provider.link_archives_deps)

        if ctx.attr._rule == "ppx_executable":
            depsets.codeps.structs.append(provider.structs)
        else:
            depsets.deps.structs.append(provider.structs)

        if ctx.attr._rule == "ppx_executable":
            depsets.codeps.ofiles.append(provider.ofiles)
        else:
            depsets.deps.ofiles.append(provider.ofiles)

        if ctx.attr._rule == "ppx_executable":
            depsets.codeps.archives.append(provider.archives)
        else:
            depsets.deps.archives.append(provider.archives)

        if ctx.attr._rule == "ppx_executable":
            depsets.codeps.afiles.append(provider.afiles)
        else:
            depsets.deps.afiles.append(provider.afiles)

        if ctx.attr._rule == "ppx_executable":
            depsets.codeps.astructs.append(provider.astructs)
        else:
            depsets.deps.astructs.append(provider.astructs)

        if hasattr(provider, "cmxs"):
            if provider.cmxs != []:
                if ctx.attr._rule == "ppx_executable":
                    depsets.codeps.cmxs.append(provider.cmxs)
                else:
                    fail(provider.cmxs)
                    depsets.deps.cmts.append(provider.cmxs)

        if hasattr(provider, "cmts"):
            if provider.cmts != []:
                if ctx.attr._rule == "ppx_executable":
                    depsets.codeps.cmts.append(provider.cmts)
                else:
                    depsets.deps.cmts.append(provider.cmts)

        if hasattr(provider, "cmtis"):
            if provider.cmtis != []:
                if ctx.attr._rule == "ppx_executable":
                    depsets.codeps.cmtis.append(provider.cmtis)
                else:
                    depsets.deps.cmtis.append(provider.cmtis)

        if ctx.attr._rule == "ppx_executable":
            depsets.codeps.paths.append(provider.paths)
        else:
            depsets.deps.paths.append(provider.paths)

        if hasattr(provider, "jsoo_runtimes"):
            if provider.jsoo_runtimes != None:
                if ctx.attr._rule == "ppx_executable":
                    depsets.codeps.jsoo_runtimes.append(provider.jsoo_runtimes)
                else:
                    depsets.deps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if OCamlCcInfo in target:
        ## contains ccinfos and ccinfos_arch (for ccinfos embedded in archives)
        depsets.ccinfos.append(target[OCamlCcInfo].direct)
        depsets.ccinfos_archived.append(target[OCamlCcInfo].archived)

    if CcSharedLibraryInfo in target:
        # print("target: %s" % ctx.label)
        # print("CcSharedLibraryInfo %s" % target[CcSharedLibraryInfo])
        # print("Shared lib DefaultInfo %s" % target[DefaultInfo])
        depsets.deps.cc_dsos.append(target[DefaultInfo].files)

    if CcInfo in target:
        if debug_ccinfo:
            print("CCCC %s" % target)
        ## if target == vm, and linkage = dynamic, then cc_binary
        ## targets producing shared libs will deliver the shared lib
        ## in DefaultInfo, but not in CcInfo. E.g. jsoo
        ## lib/runtime:jsoo_runtime builds a cc_binary
        ## dlljsoo_runtime_stubs.so or a cc_library
        ## libjsoo_runtime.stubs.a, depending on build context.

        ## to handle this anomlous case we need to detect it and then
        ## construct a CcInfo provider containing the shared lib.

        # print(target[DefaultInfo].default_runfiles.files)
        # print(target[DefaultInfo].files_to_run.runfiles_manifest)
        # fail("X")

        # (libname, filtered_ccinfo) = filter_ccinfo(dep)
        # if debug_cc:
        #     print("LIBNAME: %s" % libname)
        #     print("FILTERED CCINFO: %s" % filtered_ccinfo)
        # if filtered_ccinfo:
        #     ccinfos.append(filtered_ccinfo)
        #     # ccinfos.append(libname)
        # else:
        #     ## this dep has CcInfo but not OCamlDepsProvider (i.e. it
        #     ## was not propagated by an ocaml_* rule?); infer it
        #     ## was delivered by cc_binary must be a shared lib
        #     ccfile = dep[DefaultInfo].files.to_list()[0]
        #     ## put the cc file into a CcInfo provider:
        #     cc_info = cc_shared_lib_to_ccinfo(ctx, dep[CcInfo], ccfile)
        #     ccinfos.append(cc_info)
        #     # dump_CcInfo(ctx, dep[CcInfo])

        ccInfo = normalize_ccinfo(ctx, target)
        # print("CCTGT %s" % target)

        if OCamlLibraryProvider in target:
            # if ctx.label.name == "Test":
            #     if target.label.name == "zstd":
            #         dump_CcInfo(ctx, ccInfo)
            #         fail("asdf")
            depsets.ccinfos_archived.append(ccInfo)
            depsets.ccinfos.append(ccInfo)
        elif OCamlImportProvider in target:
            # print("IMPORTP %s" % ctx.label.name)
            # print("IMPORTP cc %s" % depsets.ccinfos_archived)
            depsets.ccinfos_archived.append(ccInfo)
            depsets.ccinfos.append(ccInfo)
        else:
            depsets.ccinfos.append(ccInfo)

    # if target.label.name == "Ppxlib_driver":
    #     # print("manifest: %s" % manifest)
    #     # print("target: %s" % target)
    #     print("target structs: %s" % provider.structs)
    #     print("depsets.deps.structs: %s" % depsets.deps.structs)
    #     # print("target astructs: %s" % provider.astructs)
    #     fail("deps")
    return depsets

