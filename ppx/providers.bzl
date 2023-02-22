PpxModuleMarker = provider(
    doc = "PPX module Marker.",
    # fields = {
    #     "name": "name of module"
    # }
)

###############################
def _PpxCodepsInfo_init(*,
                        sigs          = [],
                        cli_link_deps = [],
                        archives      = [],
                        afiles        = [],
                        astructs      = [],
                        structs       = [],
                        ofiles        = [],
                        cmts          = [],
                        cmtis         = [],
                        paths         = [],
                        jsoo_runtimes = []
                        ):
    return {
        "sigs"          : sigs,
        "cli_link_deps" : cli_link_deps,
        "archives"      : archives,
        "afiles"        : afiles,
        "astructs"      : astructs,
        "structs"       : structs,
        "ofiles"        : ofiles,
        "cmts"          : cmts,
        "cmtis"         : cmtis,
        "paths"         : paths,
        "jsoo_runtimes" : jsoo_runtimes
    }
PpxCodepsInfo, _new_ppxcodepsinfo = provider(
    doc = "foo",
    fields = {
        "sigs":      "depset of .cmi files",
        "cli_link_deps" : "Depset of cm[x]a and cm[x|o] files to be added to cmd line",
        "structs":   "depset of .cmo or .cmx/.o files depending onn mode",
        "ofiles":    "depset of .o files to go with .cmx files",
        "archives":  "depset of .cmxa or .cma files",
        "afiles":    "depset of .a files to go with .cmxa files",
        "astructs":  "depset of archived structs",
        "cmts":      "depset of .cmt files",
        "cmtis":      "depset of .cmti files",
        "paths":     "depset of path strings, for efficiency",

        "ccdeps":    "depset of cc libs (static or shared)",
        "ccinfo"  : "a single CcInfo provider, merged",
        "jsoo_runtimes": "depset of runtime.js files",
    },
    init = _PpxCodepsInfo_init
)

###############################
PpxCodepsProvider = provider(
    doc = "PPX Codeps provider.",
    fields = {
        "sigs":      "depset of .cmi files",
        "cli_link_deps" : "Depset of cm[x]a and cm[x|o] files to be added to cmd line",
        "structs":   "depset of .cmo or .cmx/.o files depending onn mode",
        "ofiles":    "depset of .o files to go with .cmx files",
        "archives":  "depset of .cmxa or .cma files",
        "afiles":    "depset of .a files to go with .cmxa files",
        "astructs":  "depset of archived structs",
        "cmts":      "depset of .cmt files",
        "cmtis":      "depset of .cmti files",
        "paths":     "depset of path strings, for efficiency",

        "ccdeps":    "depset of cc libs (static or shared)",
        "ccinfo"  : "a single CcInfo provider, merged",
        "jsoo_runtimes": "depset of runtime.js files",
    }
)

PpxExecutableMarker = provider(doc = "Ppx Executable Marker provider.")

# ################################################################

# PpxInfo = provider(fields=["ppx", "cmo", "o", "cmx", "a", "cmxa"])

