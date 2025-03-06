def _OCamlLibraryProvider_init(*,
                               name = None,
                               manifest = [],
                               ):
    return {
        "name"    : name,
        "manifest": manifest
    }

OCamlLibraryProvider, _new_ocamlmoduleinfo = provider(
    doc    = "OCaml runtime provider",
    init   = _OCamlLibraryProvider_init,
    fields = {
        "name": "String",
        "manifest": "Depset of modules, unarchived, w/o deps"
    }
)

