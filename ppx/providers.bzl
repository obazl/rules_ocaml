PpxModuleMarker = provider(
    doc = "PPX module Marker.",
    # fields = {
    #     "name": "name of module"
    # }
)

###############################
PpxCodepsProvider = provider(
    doc = "PPX Codeps provider.",
    fields = {
        "sigs":      "depset of .cmi files",
        "structs":   "depset of .cmo or .cmx/.o files depending onn mode",
        "ofiles":    "depset of .o files to go with .cmx files",
        "archives":  "depset of .cmxa or .cma files",
        "afiles":    "depset of .a files to go with .cmxa files",
        "astructs":  "depset of archived structs",
        "cmts":      "depset of .cmt, .cmti files",
        "paths":     "depset of path strings, for efficiency",

        "ccdeps":    "depset of cc libs (static or shared)",
        "ccinfo"  : "a single CcInfo provider, merged",
        "jsoo_runtimes": "depset of runtime.js files",
    }
)

PpxExecutableMarker = provider(doc = "Ppx Executable Marker provider.")

# ################################################################

# PpxInfo = provider(fields=["ppx", "cmo", "o", "cmx", "a", "cmxa"])

