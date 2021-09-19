## ocaml_import always provides an empty DefaultInfo and an empty
## OcamlImportProvider (as a marker, for consumers that require it.)
## In addition it may provided zero or more of:
##     OcamlImportArchivesProvider
##     OcamlImportPluginsProvider
##     OcamlImportSignaturesProvider
## It gloms all the paths of the above into:
##     OcamlImportPathsProvider
## Finally, it may provide "ppx deps" (formerly "adjunct deps"):
##     OcamlImportPpxAdjunctsProvider

OcamlImportProvider = provider(
    doc = "Marker provider, for consumers that require it.",
)

OcamlImportArchivesProvider = provider(
    doc = "Provider for imported OCaml archive files.",
    fields = {
        "archives": "Depset of .cma, .cmxa, .a"
    }
)

OcamlImportPluginsProvider = provider(
    doc = "Provider for imported OCaml plugin files.",
    fields = {
        "plugins": "Depset of .cmxs"
    }
)

OcamlImportSignaturesProvider = provider(
    doc = "Provider for imported OCaml signature files.",
    fields = {
        "signatures" : "Depset of sig files",
    }
)

OcamlImportPathsProvider = provider(
    doc = "Provider for paths of imported OCaml files.",
    fields = {
        "paths": "String depset"
    }
)

OcamlImportPpxAdjunctsProvider = provider(
    doc = "Provider for PPX adjunct deps.",
    fields = {
        "ppx_adjuncts": "Depset of targets"
    }
)
