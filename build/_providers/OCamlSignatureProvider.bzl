################################################################
OCamlSignatureProvider = provider(
    doc = "OCaml interface provider.",
    fields = {
        "cmi": ".cmi output file",
        "cmti": ".cmti output file",
        "mli": ".mli input file",
        "xmo": "boolean: cross-module optimization. False: compile with -opaque",
    }
)

