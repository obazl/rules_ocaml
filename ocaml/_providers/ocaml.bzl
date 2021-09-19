OcamlProvider = provider(
    doc = "OCaml module provider.",
    fields = {
        "files": "file depset",
        "paths": "string depset"
    }
)

# OcamlNsResolverMarker = provider(doc = "OCaml NsResolver Marker provider.")
OcamlNsResolverProvider = provider(
    doc = "OCaml NS Resolver provider.",
    fields = {
        "files"   : "Depset, instead of DefaultInfo.files",
        "paths":    "Depset of paths for -I params",
        "submodules": "String list of submodules in this ns",
        "resolver": "Name of resolver module",
        "prefixes": "List of alias prefix segs",
    }
)

AdjunctDepsMarker    = provider(doc = "OCaml PPX Adjunct Deps Marker provider.")

OcamlArchiveMarker   = provider(doc = "OCaml Archive Marker provider.")
OcamlExecutableMarker   = provider(doc = "OCaml Executable Marker provider.")
OcamlImportMarker    = provider(doc = "OCaml Library Marker provider.")
OcamlLibraryMarker   = provider(doc = "OCaml Library Marker provider.")
OcamlModuleMarker    = provider(doc = "OCaml Module Marker provider.")
OcamlNsArchiveMarker = provider(doc = "OCaml NsArchive Marker provider.")
OcamlNsLibraryMarker = provider(doc = "OCaml NsLibrary Marker provider.")
OcamlSignatureMarker = provider(doc = "OCaml Signature Marker provider.")
OcamlTestMarker   = provider(doc = "OCaml Test Marker provider.")

PpxArchiveMarker = provider(doc = "Ppx Archive Marker provider.")
PpxExecutableMarker = provider(doc = "Ppx Executable Marker provider.")
PpxModuleMarker = provider(doc = "Ppx Module Marker provider.")
PpxLibraryMarker = provider(doc = "Ppx Library Marker provider.")
PpxNsArchiveMarker = provider(doc = "Ppx NsArchive Marker provider.")
PpxNsLibraryMarker = provider(doc = "Ppx NsLibrary Marker provider.")
