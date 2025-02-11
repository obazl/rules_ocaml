load("@rules_ocaml//build:providers.bzl",
     "OCamlModuleInfo", "OCamlProvider")

load("@rules_ocaml//build:providers.bzl",
     # "OcamlLibraryMarker",
     # "OcamlModuleMarker",
     # "OCamlVmRuntimeProvider"
     "OCamlNsResolverProvider",
     "OCamlSignatureProvider",
     )

load("@rules_ocaml//build:providers.bzl", "OCamlCodepsProvider")

load("@rules_ocaml//build/_lib:impl_ccdeps.bzl",
     "cc_shared_lib_to_ccinfo",
     "normalize_ccinfo",
     "extract_cclibs", "dump_CcInfo")

COMPILE      = 0
LINK         = 1
COMPILE_LINK = 2

################################################################
# RENAME: MergedDepsProvider
def _MergedDepsProvider_init(*,
                    sigs          = [],
                    cli_link_deps = [],
                    archives      = [],
                    afiles        = [],
                    astructs      = [], # archived, for inputs_depset only
                    structs       = [], # free-standing structs (unarchived)
                    ofiles        = [],
                    mli           = [],
                    cmts          = [],
                    cmtis         = [],
                    paths         = [],
                    jsoo_runtimes = [],
                    runfiles      = []
                    ):
    return {
        "sigs"          : sigs,
        "cli_link_deps" : cli_link_deps,
        "archives"      : archives,
        "afiles"        : afiles,
        "astructs"      : astructs,
        "structs"       : structs,
        "ofiles"        : ofiles,
        "mli"           : mli,
        "cmts"          : cmts,
        "cmtis"         : cmtis,
        "paths"         : paths,
        "jsoo_runtimes" : jsoo_runtimes,
        "runfiles"      : runfiles
    }

# RENAME: MergedDepsProvider
MergedDepsProvider, _new_ocamlocamlinfo = provider(
    init = _MergedDepsProvider_init,
    doc = "foo",
    fields = {
        "sigs"          : "Depset of .cmi files. always added to inputs, never to cmd line.",
        "cli_link_deps" : "Depset of cm[x]a and cm[x|o] files to be added to inputs and link cmd line (executables and archives).",
        "archives"      : "Depset of archives.",
        "astructs"      : "Depset of archived .cmx files.",
        "structs"       : "Depset of unarchived .cmo or .cmx files.",
        "afiles"        : "Depset of the .a files that go with .cmxa files",
        "ofiles"        : "Depset of the .o files that go with .cmx files",
        "mli"           : ".mli files needed for .ml compilation",
        "cmts"          : ".cmt files",
        "cmtis"         : ".cmti files",
        "paths"         : "string depset, for efficiency",
        "jsoo_runtimes" : "depset of runtime.js files",
        "runfiles"      : "one merged Runfiles object"
    }
)

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
                         ccinfos_archived = None):
    return {
        "deps"             : MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmts          = [],
            cmtis         = [],
            paths         = [],
            jsoo_runtimes = [], # depset(),
            runfiles      = []
        ),
        "codeps"           : MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmts          = [],
            cmtis         = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        "compile_codeps"   : MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmts          = [],
            cmtis         = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        "link_codeps"      : MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmts          = [],
            cmtis         = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        "ccinfos"          : [],
        "ccinfos_archived" : []
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
    }
)

def XDepsAggregator():
    return DepsAggregator(
        deps = MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmts          = [],
            cmtis         = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        codeps = MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmts          = [],
            cmtis         = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        compile_codeps = MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmts          = [],
            cmtis         = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        link_codeps = MergedDepsProvider(
            sigs          = [],
            cli_link_deps = [],
            archives      = [],
            structs       = [],
            astructs      = [],
            afiles        = [],
            ofiles        = [],
            mli           = [],
            cmts          = [],
            cmtis         = [],
            paths         = [],
            jsoo_runtimes = [],
            runfiles      = []
        ),
        ccinfos           = [],
        ccinfos_archived  = []
    )

################################################################
def aggregate_deps(ctx,
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
    debug_ccinfo   = False # True
    debug_runfiles = False
    # if target.label.name == "Ppxlib_driver":
    #     debug = True
    # if debug:

    # print("XXXXXXXXXXXXXXXX")
    # print(target)
    # fail("A")

    archiving = len(manifest) > 0

    module_archived = False
    # if OCamlModuleInfo in target:
    #     mInfo = target[OCamlModuleInfo]
    #     print("mInfo: %s" % mInfo)
    #     print("manifest: %s" % manifest)
    #     for item in manifest:
    #         print("item: %s" % item.label.name)
    #         if mInfo.name == item.label.name:
    #             module_archived = True

    if OCamlProvider in target: # FIXME: MergedDepsProvider
        provider = target[OCamlProvider]

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

        if OCamlModuleInfo in target:
            ## FIXME: won't work for topdown namespaced libs/archives
            ## since mInfo.name will have ns prefix, e.g. Color__Red, not Red

            if debug_runfiles:
                print("module runfiles: %s" % target[DefaultInfo].default_runfiles.files)
            depsets.deps.runfiles.append(target[DefaultInfo].default_runfiles)

            mInfo = target[OCamlModuleInfo]
            if debug:
                print("mInfo: %s" % mInfo)
                print("manifest: %s" % manifest)
            for item in manifest:
                if debug:
                    print("manifest item: %s" % item)
                # print("manifest item.label: %s" % item.label)
                # if OCamlModuleInfo in item:
                #     print("item.minfo: %s" % item[OCamlModuleInfo])
                # else:
                #     print("no minfo in item")
                    #NB: lib manifest may contain non-modules (e.g. libs)
                    #FIXME: if item is library, need we iterate over it???
                    # if OcamlLibraryMarker in item:
                    #     print("Item is library")
                    #     for libitem in item[OCamlProvider].sigs.to_list():
                    #         print("libitem sig: %s" % libitem)
                        # fail("embedded libs not yet implemented")

                if mInfo.label_name == item.label.name:
                    if debug:
                        print("MODULE ARCHIVED: %s" % mInfo)
                    module_archived = True
                else:
                    if debug:
                        print("MODULE UNARCHIVED: %s" % mInfo)

            # bottomup ns resolver:
            if OCamlNsResolverProvider in target:
                module_archived = True

            depsets.deps.sigs.append(depset([mInfo.sig]))
            if mInfo.ofile:
                depsets.deps.ofiles.append(depset([mInfo.ofile]))
            if module_archived:
                depsets.deps.astructs.append(
                    depset(direct = [mInfo.struct],
                           transitive = [provider.astructs])
                )
                ## cli_link_deps will be used to construct archiving CLI
                depsets.deps.cli_link_deps.append(
                    depset(direct = [mInfo.struct],
                           # transitive = [provider.structs]
                           transitive = [provider.cli_link_deps]
                           )
                )

            else:
                depsets.deps.structs.append(provider.structs)
                depsets.deps.cli_link_deps.append(
                    depset(
                        direct = [mInfo.struct],
                        transitive = [provider.cli_link_deps]
                    )
                )
                # target[OCamlProvider].cli_link_deps)

        if hasattr(provider, "sigs"):
            if provider.sigs != []:
                depsets.deps.sigs.append(provider.sigs)

        # if target not in manifest:
        #     if hasattr(provider, "cli_link_deps"):
        #         # if target.label.name == "Simple":
        #         #     fail("CLI LINKDEPS: %s" % provider.cli_link_deps)
        #         depsets.deps.cli_link_deps.append(provider.cli_link_deps)

        if not OCamlModuleInfo in target:
            if hasattr(provider, "cli_link_deps"): # tmp, for OCamlProvider
                if provider.cli_link_deps != []:
                    depsets.deps.cli_link_deps.append(provider.cli_link_deps)
            if hasattr(provider, "astructs"):
                if provider.astructs != []:
                    depsets.deps.astructs.append(provider.astructs)

        if hasattr(provider, "archives"):
            if provider.archives != []:
                depsets.deps.archives.append(provider.archives)

        if hasattr(provider, "afiles"):
            if provider.afiles != []:
                depsets.deps.afiles.append(provider.afiles)

        if not module_archived:
            if hasattr(provider, "structs"):
                if provider.structs != []:
                    depsets.deps.structs.append(provider.structs)

        # if manifest: # for OCamlModuleInfo only
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
            if provider.ofiles != []:
                depsets.deps.ofiles.append(provider.ofiles)

        if hasattr(provider, "cmts"):
            if provider.cmts != []:
                depsets.deps.cmts.append(provider.cmts)

        if hasattr(provider, "cmtis"):
            if provider.cmtis != []:
                depsets.deps.cmtis.append(provider.cmtis)

        if hasattr(provider, "paths"):
            if provider.paths != []:
                depsets.deps.paths.append(provider.paths)

        if hasattr(provider, "jsoo_runtimes"):
            if provider.jsoo_runtimes != []:
                depsets.deps.jsoo_runtimes.append(provider.jsoo_runtimes)

    ## Now ocaml_signature, ocaml_module
    if OCamlSignatureProvider in target:
        depsets.deps.mli.append(target[OCamlSignatureProvider].mli)

    # if OCamlModuleInfo in target:
    #     # if target.label.name == "Common":
    #         # print("ModuleInfo: %s" % target[ModuleInfo])
    #         # print("DefaultInfo.files: %s" % target[DefaultInfo].files)
    #         # print("BootInfo.linkdeps: %s" % target[BootInfo].cli_link_deps)
    #         # fail("COMMON")

    #     if not suppress_cmi:
    #         depsets.deps.sigs.append(
    #             depset([target[ModuleInfo].sig]))

    #     if target[ModuleInfo].ofile:
    #         depsets.deps.ofiles.append(depset([target[ModuleInfo].ofile]))

    #     if archiving:
    #         if target not in manifest:
    #             if provider.cli_link_deps != []:
    #                 depsets.deps.cli_link_deps.append(
    #                     depset([target[ModuleInfo].struct]))
    #         else:
    #             depsets.deps.astructs.append(target[ModuleInfo].struct)
    #     else:
    #         if provider.cli_link_deps != []:
    #             depsets.deps.cli_link_deps.append(
    #                 depset([target[ModuleInfo].struct]))

    ## ns resolvers
    if type(target) == "list":
        if OCamlNsResolverProvider in target[0]:
            if debug: print("ns resolver: %s" % target)
            # fail()
            provider = target[0][OCamlNsResolverProvider]
            depsets.deps.sigs.append(depset([provider.cmi]))
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

        if provider.cli_link_deps != []:
            if ctx.attr._rule == "ppx_executable":
                depsets.codeps.cli_link_deps.append(provider.cli_link_deps)
            else:
                depsets.deps.cli_link_deps.append(provider.cli_link_deps)

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
            if provider.jsoo_runtimes != []:
                if ctx.attr._rule == "ppx_executable":
                    depsets.codeps.jsoo_runtimes.append(provider.jsoo_runtimes)
                else:
                    depsets.deps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if CcInfo in target:
        if debug_ccinfo:
            print("CCCCCCCCCCCCCCCC")
        # if ctx.label.name == "Alpha":
        #     print("Agg CcInfo, tgt: %s" % target)
        ## if target == vm, and vmruntime = dynamic, then cc_binary
        ## targets producing shared libs will deliver the shared lib
        ## in DefaultInfo, but not in CcInfo. E.g. jsoo
        ## lib/runtime:jsoo_runtime builds a cc_bindary
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
        #     ## this dep has CcInfo but not OCamlProvider (i.e. it
        #     ## was not propagated by an ocaml_* rule?); infer it
        #     ## was delivered by cc_binary must be a shared lib
        #     ccfile = dep[DefaultInfo].files.to_list()[0]
        #     ## put the cc file into a CcInfo provider:
        #     cc_info = cc_shared_lib_to_ccinfo(ctx, dep[CcInfo], ccfile)
        #     ccinfos.append(cc_info)
        #     # dump_CcInfo(ctx, dep[CcInfo])

        ccInfo = normalize_ccinfo(ctx, target)
        # if ctx.label.name == "jsoo_runtime":
        #     dump_CcInfo(ctx, ccInfo)
        #     fail("asdf")

        depsets.ccinfos.append(ccInfo)

    # if target.label.name == "Ppxlib_driver":
    #     # print("manifest: %s" % manifest)
    #     # print("target: %s" % target)
    #     print("target structs: %s" % provider.structs)
    #     print("depsets.deps.structs: %s" % depsets.deps.structs)
    #     # print("target astructs: %s" % provider.astructs)
    #     fail("deps")
    return depsets

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
    #     print("codep archives: %s" % target[OCamlProvider].archives)
    #     print("codep astructs: %s" % target[OCamlProvider].astructs)
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

    if OCamlProvider in target:
        provider = target[OCamlProvider]
        depsets.codeps.sigs.append(provider.sigs)
        if provider.cli_link_deps != []:
            depsets.codeps.cli_link_deps.append(provider.cli_link_deps)
        depsets.codeps.archives.append(provider.archives)
        depsets.codeps.afiles.append(provider.afiles)
        depsets.codeps.astructs.append(provider.astructs)
        if provider.ofiles != []:
            depsets.codeps.ofiles.append(provider.ofiles)
        if hasattr(provider, "cmtis"):
            if provider.cmtis != []:
                depsets.codeps.cmtis.append(provider.cmtis)
        if hasattr(provider, "cmts"):
            if provider.cmts != []:
                depsets.codeps.cmts.append(provider.cmts)
        depsets.codeps.paths.append(provider.paths)
        if hasattr(provider, "jsoo_runtimes"):
            if provider.jsoo_runtimes != []:
                depsets.codeps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if OCamlCodepsProvider in target:
        provider = target[OCamlCodepsProvider]
        depsets.codeps.sigs.append(provider.sigs)
        if provider.cli_link_deps != []:
            depsets.codeps.cli_link_deps.append(provider.cli_link_deps)
        depsets.codeps.structs.append(provider.structs)
        if provider.ofiles != []:
            depsets.codeps.ofiles.append(provider.ofiles)
        depsets.codeps.archives.append(provider.archives)
        depsets.codeps.afiles.append(provider.afiles)
        depsets.codeps.astructs.append(provider.astructs)
        if hasattr(provider, "cmtis"):
            depsets.codeps.cmtis.append(provider.cmtis)
        if hasattr(provider, "cmts"):
            depsets.codeps.cmts.append(provider.cmts)
        depsets.codeps.paths.append(provider.paths)
        if hasattr(provider, "jsoo_runtimes"):
            if provider.jsoo_runtimes != []:
                depsets.codeps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if CcInfo in target:
            depsets.ccinfos.append(target[CcInfo])

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
