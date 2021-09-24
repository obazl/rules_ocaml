OcamlProvider = provider(
    doc = "OCaml module provider.",
    fields = {
        "inputs"             : "file depset",
        "linkargs"             : "file depset",
        "paths"             : "string depset",

        "files"             : "file depset",
        "archives"          : "file depset",
        "archive_deps"       : "file depset of archive deps",
        "ppx_adjuncts"      : "file depset",
        "ppx_adjunct_paths" : "string depset",
        "cc_deps"           : "dictionary depset",
        "ns_resolver"       : "single target",
    }
)

OcamlArchiveProvider = provider(
    doc = """OCaml archive provider.

Produced only by ocaml_archive, ocaml_ns_archive, ocaml_import.  Archive files are delivered in DefaultInfo; this provider holds deps of the archive, to serve as action inputs.
""",
    fields = {
        "files": "file depset of archive's deps",
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
        "resolver_file": "file",
        "resolver": "Name of resolver module",
        "prefixes": "List of alias prefix segs",
    }
)

OcamlCcInfo = provider(
    doc = "Provides CcInfo deps",
    fields = {
        "ccinfo": "depset of CcInfo providers",
    }
)

PpxAdjunctsProvider = provider(
    doc = "PPX Adjunct Deps provider.",
    fields = {
        "ppx_adjuncts": "file depset",
        "paths": "string depset"
    }
)

# AdjunctDepsMarker    = provider(doc = "OCaml PPX Adjunct Deps Marker provider.")

# OcamlArchiveMarker   = provider(doc = "OCaml Archive Marker provider.")
OcamlExecutableMarker   = provider(doc = "OCaml Executable Marker provider.")
OcamlImportMarker    = provider(doc = "OCaml Library Marker provider.")
OcamlLibraryMarker   = provider(doc = "OCaml Library Marker provider.")
OcamlModuleMarker    = provider(doc = "OCaml Module Marker provider.")
OcamlNsMarker        = provider(doc = "OCaml Namespace Marker provider.")
OcamlSignatureMarker = provider(doc = "OCaml Signature Marker provider.")
OcamlTestMarker      = provider(doc = "OCaml Test Marker provider.")

PpxArchiveMarker = provider(doc = "Ppx Archive Marker provider.")
PpxExecutableMarker = provider(doc = "Ppx Executable Marker provider.")
PpxModuleMarker = provider(doc = "Ppx Module Marker provider.")
PpxLibraryMarker = provider(doc = "Ppx Library Marker provider.")
# PpxNsArchiveMarker = provider(doc = "Ppx NsArchive Marker provider.")
PpxNsLibraryMarker = provider(doc = "Ppx NsLibrary Marker provider.")
