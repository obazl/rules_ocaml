def _OCamlLibraryProvider_init(*,
                               name = None,
                               ):
    return {
        "name"  : name,
    }

OCamlLibraryProvider, _new_ocamlmoduleinfo = provider(
    doc    = "OCaml runtime provider",
    init   = _OCamlLibraryProvider_init,
    fields = {
        "name": "String",
    }
)

