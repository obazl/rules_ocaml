load(":MergedDepsProvider.bzl", "MergedDepsProvider")

def _OCamlSignatureProvider_init(
    *,
    cmi      = None,
    cmti     = None,
    mli      = None,
    xmo      = None,
    merged_deps = None,
    # sigs     = None,
    # cmtis    = None,
    # structs  = None,
    # ofiles   = None,
    # archives = None,
    # afiles   = None,
    # astructs = None,
    # paths    = None
):
    return {
        "cmi": cmi,
        "cmti": cmti,
        "mli": mli,
        "xmo" : xmo,
        "merged_deps": merged_deps,
        # "sigs": sigs,
        # "cmtis": cmtis,
        # "structs": structs,
        # "ofiles" : ofiles,
        # "archives" : archives,
        # "afiles" : afiles,
        # "astructs" : astructs,
        # "paths" : paths
    }
OCamlSignatureProvider, _new_ocamlsignatureprovider = provider(
    doc = "OCaml signature provider.",
    init = _OCamlSignatureProvider_init,
    fields = {
        ## Does client ever need cmi/cmti/mli files freestanding?
        "cmi"      : ".cmi output file",
        "cmti"     : ".cmti output file",
        "mli"      : ".mli input file",
        "xmo"      : "boolean: cross-module optimization. False: compile with -opaque",
        "merged_deps": "instance of MergedDepsProvider",
        # "sigs"     : "sig deps",
        # "cmtis"    : "cmit deps",
        # "structs"  : "structs",
        # "ofiles"   : "ofiles",
        # "archives" : "archives",
        # "afiles"   : "afiles",
        # "astructs" : "astructs",
        # "paths"    : "paths"
    }
)

