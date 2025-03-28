def _OCamlArchiveProvider_init(*,
                               archive = None,
                               ):
    return {
        "archive" : archive
    }

OCamlArchiveProvider, _new_ocamlmoduleinfo = provider(
    doc    = "OCaml archive provider",
    init   = _OCamlArchiveProvider_init,
    fields = {
        "archive": "Archive file (.cma/.cmxa)",
    }
)

