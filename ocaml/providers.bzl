"""Public Providers for obaz_rules_ocaml LSP.

All public OCaml providers imported and re-exported in this file.

Definitions outside this file should not be loaded by client code
unless otherwise noted, and may change without notice. """


# load("//ocaml/_providers:ppx.bzl",
#      _PpxPrintSettingProvider = "PpxPrintSettingProvider"
#      )

# PpxPrintSettingProvider = _PpxPrintSettingProvider

PpxNsModuleProvider = provider(
    doc = "OCaml PPX NS Module provider.",
    fields = {
        "payload": """A struct with the following fields:
            ns : namespace
            cmi: .cmi file produced by the target
            cm : .cmx/cmo file produced by the target
            o  : .o file produced by the target
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
        """
    }
)
