def _OpamInstallProvider_init(*,
                              archives = None,
                              sigs     = None,
                              structs  = None,
                              cmts     = None,
                              srcs     = None,
                              ccinfo   = None):
    return {
        "archives": archives,
        "sigs": sigs,
        "structs": structs,
        "cmts": cmts,
        "srcs": srcs,
        "ccinfo": ccinfo
    }

OpamInstallProvider, _new_opaminstallprovider = provider(
    doc = "Provides artifacts for OPAM pkg installation",
    fields = {
        "archives":  "depset of .cma or .cmxa files (plus .a)",
        "sigs":      "depset of .cmi files",
        "structs":   "depset of .cmo or .cmx files (plus .o)",

        "cmts":      "depset of cmt/cmti files",
        "srcs":      "depset of src files",

        "ccinfo"  : "a single CcInfo provider",
    },
    init = _OpamInstallProvider_init
)

