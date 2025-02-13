"""Public definitions for rules_ocaml transition functions.

All public transition functions imported and re-exported in this file.

Definitions outside this file are private unless otherwise noted, and
may change without notice. Really.
"""

load("//build/_transitions:ocaml_executable_in_transition.bzl",
     _ocaml_executable_in_transition = "ocaml_executable_in_transition")
load("//build/_transitions:ppx_executable_in_transition.bzl",
     _ppx_executable_in_transition = "ppx_executable_in_transition")

ocaml_executable_in_transition = _ocaml_executable_in_transition
ppx_executable_in_transition = _ppx_executable_in_transition
