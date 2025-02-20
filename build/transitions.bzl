"""Public definitions for rules_ocaml transition functions.

All public transition functions imported and re-exported in this file.

Definitions outside this file are private unless otherwise noted, and
may change without notice. Really.
"""

load("//build/_transitions:ocaml_executable_in_transition.bzl",
     _ocaml_executable_in_transition = "ocaml_executable_in_transition")

load("//build/_transitions:in_transitions.bzl",
     _get_tc = "get_tc")

load("//build/_transitions:in_transitions.bzl",
     _executable_in_transition_impl = "executable_in_transition_impl")

# load("//build/_transitions:ppx_executable_in_transition.bzl",
#      _ppx_executable_in_transition = "ppx_executable_in_transition")

get_tc = _get_tc
executable_in_transition_impl = _executable_in_transition_impl

ocaml_executable_in_transition = _ocaml_executable_in_transition
# ppx_executable_in_transition = _ppx_executable_in_transition
