"""Public definitions for OCamlX rules.

All public OCamlX rules, providers, and other definitions are imported and
re-exported in this file. This allows the real location of definitions
to change for easier maintenance.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load("@obazl_rules_ocaml//ocamlx/rules:ocamlx_cppo_runner.bzl",
    _ocaml_cppo_runner = "ocamlx_cppo_runner"
)

ocamlx_cppo_runner = _ocaml_cppo_runner
