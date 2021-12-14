"""Public definitions for OCaml toolchain rule.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load("//ocaml/_rules:ocaml_toolchain.bzl",
     _ocaml_toolchain = "ocaml_toolchain")

ocaml_toolchain = _ocaml_toolchain
