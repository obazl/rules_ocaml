load("@rules_ocaml//ocaml:providers.bzl",
     "OcamlModuleMarker",
     "OcamlNsResolverProvider",
     "OcamlProvider",
     "OcamlVmRuntimeProvider")

load("@rules_ocaml//ppx:providers.bzl",
     "PpxCodepsProvider",
     "PpxModuleMarker",
)

load("@rules_ocaml//ocaml/_rules:impl_ccdeps.bzl",
     "cc_shared_lib_to_ccinfo",
     "normalize_ccinfo",
     "extract_cclibs", "dump_CcInfo")

COMPILE      = 0
LINK         = 1
COMPILE_LINK = 2

def _OCamlProvider_init(*,
                    sigs = [],
                    structs = [],
                    ofiles = [],
                    archives = [],
                    afiles = [],
                    astructs = [],
                    cmts = [],
                    paths = [],
                    jsoo_runtimes = []
                    ):
    return {
        "sigs"          :  sigs,
        "structs"       :  structs,
        "ofiles"        :  ofiles,
        "archives"      :  archives,
        "afiles"        :  afiles,
        "astructs"      :  astructs,
        "cmts"          :  cmts,
        "paths"         :  paths,
        "jsoo_runtimes" :  jsoo_runtimes
    }

OCamlProvider = provider(
    doc = "foo",
    fields = {
        "sigs":      "depset of .cmi files",
        "structs":   "depset of .cmo or .cmx files depending on mode",
        "ofiles":    "depset of the .o files that go with .cmx files",
        "archives":  "depset of .cmxa and .cma files",
        "cma":       "depset of .cma files",
        "cmxa":       "depset of .cmxa files",
        "afiles":    "depset of the .a files that go with .cmxa files",
        "astructs":  "depset of archived structs, added to link depgraph but not command line.",
        "cmts":      "depset of cmt/cmti files",
        "paths"             : "string depset",
        "jsoo_runtimes": "depset of runtime.js files",

        "cli_link_deps": "depset of files to be added to link cmd line"
    },
    # init = _OCamlProvider_init
)

# export OCamlProvider

DepsAggregator = provider(
    fields = {
        "deps"           : "an OCamlProvider provider",
        "codeps"         : "an OCamlProvider provider",
        "compile_codeps" : "an OCamlProvider provider",
        "link_codeps"    : "an OCamlProvider provider",
        "ccinfos"        : "list of CcInfo providers",
    }
)

################################################################
def aggregate_deps(ctx,
                   target, # a Target
                   depsets, # a struct
                   archive_manifest = []): # target will be added to archive

    debug = False
    debug_archives = False
    # if target.label.name == "Ppxlib_driver":
    #     debug = True
    if debug:
        print("aggregate_deps: %s" % target)
        print("depsets: %s" % depsets)

    if OcamlProvider in target:
        provider = target[OcamlProvider]

        if target not in archive_manifest:
            if hasattr(provider, "cli_link_deps"):
                # if target.label.name == "Simple":
                #     fail("CLI LINKDEPS: %s" % provider.cli_link_deps)
                depsets.deps.cli_link_deps.append(provider.cli_link_deps)

        depsets.deps.sigs.append(provider.sigs)
        depsets.deps.archives.append(provider.archives)
        depsets.deps.afiles.append(provider.afiles)
        depsets.deps.astructs.append(provider.astructs)
        if archive_manifest:
            if debug_archives:
                print("archive manifest: %s" % archive_manifest)
            if target in archive_manifest:
                if debug_archives:
                    print("TARGET IN MANIFEST: %s" % target)
                    if target.label.name == "Red":
                        print("RED structs: %s" % provider.structs)
                    # fail("testagddg")
                depsets.deps.astructs.append(provider.structs)
            else:
                depsets.deps.structs.append(provider.structs)
        else:
            depsets.deps.structs.append(provider.structs)
            # if target.label.name == "Ppx_color":
                # fail("color: %s" % provider)
        depsets.deps.ofiles.append(provider.ofiles)
        if hasattr(provider, "cmts"):
            depsets.deps.cmts.append(provider.cmts)
        depsets.deps.paths.append(provider.paths)
        if hasattr(provider, "jsoo_runtimes"):
            depsets.deps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if type(target) == "list":
        if OcamlNsResolverProvider in target[0]:
            provider = target[0][OcamlNsResolverProvider]
            depsets.deps.sigs.append(depset([provider.cmi]))
            # depsets.deps.archives.append(provider.archives)
            # depsets.deps.astructs.append(provider.astructs)
            depsets.deps.structs.append(depset([provider.struct]))
            # if archive_manifest:
            #     depsets.deps.astructs.append(provider.structs)
            # else:
            #     depsets.deps.structs.append(provider.structs)
            depsets.deps.ofiles.append(depset([provider.ofile]))
            # if hasattr(provider, "cmts"):
            #     depsets.deps.cmts.append(provider.cmts)
            # depsets.deps.paths.append(provider.paths)

    if PpxCodepsProvider in target:
        provider = target[PpxCodepsProvider]
        depsets.codeps.sigs.append(provider.sigs)
        depsets.codeps.structs.append(provider.structs)
        depsets.codeps.ofiles.append(provider.ofiles)
        depsets.codeps.archives.append(provider.archives)
        depsets.codeps.afiles.append(provider.afiles)
        depsets.codeps.astructs.append(provider.astructs)
        if hasattr(provider, "cmts"):
            depsets.codeps.cmts.append(provider.cmts)
        depsets.codeps.paths.append(provider.paths)
        if hasattr(provider, "jsoo_runtimes"):
            depsets.codeps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if CcInfo in target:
        ## if target == vm, and vmruntime = dynamic, then cc_binary
        ## targets producing shared libs will deliver the shared lib
        ## in DefaultInfo, but not in CcInfo. E.g. jsoo
        ## lib/runtime:jsoo_runtime builds a cc_bindary
        ## dlljsoo_runtime_stubs.so or a cc_library
        ## libjsoo_runtime.stubs.a, depending on build context.

        ## to handle this anomlous case we need to detect it and then
        ## construct a CcInfo provider containing the shared lib.

        # (libname, filtered_ccinfo) = filter_ccinfo(dep)
        # if debug_cc:
        #     print("LIBNAME: %s" % libname)
        #     print("FILTERED CCINFO: %s" % filtered_ccinfo)
        # if filtered_ccinfo:
        #     ccinfos.append(filtered_ccinfo)
        #     # ccinfos.append(libname)
        # else:
        #     ## this dep has CcInfo but not OcamlProvider (i.e. it
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

    if kind == COMPILE:
        dset = depsets.compile_codeps
    elif kind == LINK:
        dset = depsets.link_codeps
    elif kind == COMPILE_LINK:
        dset = depsets.codeps
    else:
        fail("Invalid kind: {}; must be COMPILE (0), LINK (1), or COMPILE_LINK (2)")

    if OcamlProvider in target:
        provider = target[OcamlProvider]
        depsets.codeps.sigs.append(provider.sigs)
        depsets.codeps.archives.append(provider.archives)
        depsets.codeps.afiles.append(provider.afiles)
        if manifest:
            depsets.codeps.astructs.append(provider.astructs)
        else:
            depsets.codeps.structs.append(provider.structs)
        depsets.codeps.ofiles.append(provider.ofiles)
        if hasattr(provider, "cmts"):
            depsets.codeps.cmts.append(provider.cmts)
        depsets.codeps.paths.append(provider.paths)
        if hasattr(provider, "jsoo_runtimes"):
            depsets.codeps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if PpxCodepsProvider in target:
        provider = target[PpxCodepsProvider]
        depsets.codeps.sigs.append(provider.sigs)
        depsets.codeps.structs.append(provider.structs)
        depsets.codeps.ofiles.append(provider.ofiles)
        depsets.codeps.archives.append(provider.archives)
        depsets.codeps.afiles.append(provider.afiles)
        depsets.codeps.astructs.append(provider.astructs)
        if hasattr(provider, "cmts"):
            depsets.codeps.cmts.append(provider.cmts)
        depsets.codeps.paths.append(provider.paths)
        if hasattr(provider, "jsoo_runtimes"):
            depsets.codeps.jsoo_runtimes.append(provider.jsoo_runtimes)

    if CcInfo in target:
            depsets.ccinfos.append(target[CcInfo])

    return depsets

def merge_depsets(depsets, fld):
    print("unmerged fld: %s" % getattr(depsets.deps, fld))
    merged = depset(transitive = getattr(depsets.deps, fld))
    print("merged fld {f}: {m}".format(f=fld, m=merged))

    return merged
