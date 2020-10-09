"""Public definitions for OCaml eXtension rules.

All public OCaml eXtension rules, providers, and other definitions are imported and
re-exported in this file. This allows the real location of definitions
to change for easier maintenance.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load("//ocaml/extension/implementation/rules:ocamlx_cppo_runner.bzl",
    _ocaml_cppo_runner = "ocamlx_cppo_runner"
)

ocamlx_cppo_runner = _ocaml_cppo_runner
