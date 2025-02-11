"""Public definitions for rules_ocaml actions.

All public actions imported and re-exported in this file.

Definitions outside this file are private unless otherwise noted, and
may change without notice. Really.
"""

load("//build/_actions:ppx_transformation.bzl",
     _ppx_transformation = "ppx_transformation")

ppx_transformation = _ppx_transformation
