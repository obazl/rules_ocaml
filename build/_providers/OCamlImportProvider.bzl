def _OCamlImportProvider_init(*,
                               name = None,
                               ):
    return {
        "name"  : name,
    }

OCamlImportProvider, _new_ocamlmoduleinfo = provider(
    doc    = "OCaml runtime provider",
    init   = _OCamlImportProvider_init,
    fields = {
        "name": "String",
    }
)

