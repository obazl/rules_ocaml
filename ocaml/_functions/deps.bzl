load("@rules_ocaml//ocaml:providers.bzl",
     "OcamlModuleMarker",
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

OCamlInfo = provider(
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
    }
)

DepsAggregator = provider(
    fields = {
        "deps":   "an OCamlInfo provider",
        "codeps": "an OCamlInfo provider",
        "ccinfos": "list of CcInfo providers",
    }
)

################################################################
def aggregate_deps(ctx,
                   target, # a Target
                   depsets, # a struct
                   for_archive = False): # target will be added to archive

    debug = False
    if debug:
        print("aggregate_deps: %s" % target)

    if OcamlProvider in target:
        provider = target[OcamlProvider]
        depsets.deps.sigs.append(provider.sigs)
        depsets.deps.archives.append(provider.archives)
        depsets.deps.afiles.append(provider.afiles)
        depsets.deps.astructs.append(provider.astructs)
        if for_archive:
            depsets.deps.astructs.append(provider.structs)
        else:
            depsets.deps.structs.append(provider.structs)
        depsets.deps.ofiles.append(provider.ofiles)
        if hasattr(provider, "cmts"):
            depsets.deps.cmts.append(provider.cmts)
        depsets.deps.paths.append(provider.paths)
        if hasattr(provider, "jsoo_runtimes"):
            depsets.deps.jsoo_runtimes.append(provider.jsoo_runtimes)

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

    return depsets

################################################################
def aggregate_codeps(ctx,
                     target, # a Target
                     depsets, # a struct
                     for_archive = False): # target will be added to archive

    debug = False
    if debug:
        print("aggregate_codeps: %s" % target)

    if OcamlProvider in target:
        provider = target[OcamlProvider]
        depsets.codeps.sigs.append(provider.sigs)
        depsets.codeps.archives.append(provider.archives)
        depsets.codeps.afiles.append(provider.afiles)
        if for_archive:
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
