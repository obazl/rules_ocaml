###############################
PpxCodepsProvider = provider(
    doc = "PPX Codeps provider.",
    fields = {
        "ppx_codeps": "file depset",
        "paths": "string depset",
        ##FIXME: linkset only contains archive files
        ## rename it or eliminate since archives alone insufficient?
        "linkset" : "file depset",

        "cdeps": "compile deps",
        "ldeps": "link deps"
    }
)

PpxExecutableMarker = provider(doc = "Ppx Executable Marker provider.")

# ################################################################

# PpxInfo = provider(fields=["ppx", "cmo", "o", "cmx", "a", "cmxa"])

################ Config Settings ################
PpxCompilationModeSettingProvider = provider(
    doc = "Raw value of ppx_mode_flag or setting",
    fields = {
        "value": "The value of the build setting in the current configuration. " +
                 "This value may come from the command line or an upstream transition, " +
                 "or else it will be the build setting's default.",
    },
)

