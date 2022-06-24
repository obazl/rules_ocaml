###############################
PpxCodepsProvider = provider(
    doc = "PPX Codeps provider.",
    fields = {
        "ppx_codeps": "file depset",
        "paths": "string depset",
        ##FIXME: linkset only contains archive files
        ## rename it or eliminate since archives alone insufficient?
        "linkset" : "file depset",

        "sigs":      "depset of .cmi files",
        "structs":   "depset of .cmo or .cmx/.o files depending onn mode",
        "ofiles":    "depset of .o files to go with .cmx files",
        "archives":  "depset of .cmxa or .cma files",
        "arfiles":   "depset of .a files to go with .cmxa files",
        "arstructs": "depset of archived structs",

        "cdeps": "compile deps",  # DEPRECATED
        "ldeps": "link deps"      # DEPRECATED
    }
)

PpxExecutableMarker = provider(doc = "Ppx Executable Marker provider.")

# ################################################################

# PpxInfo = provider(fields=["ppx", "cmo", "o", "cmx", "a", "cmxa"])

