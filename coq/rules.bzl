"""Public definitions for Coq rules.

All public Coq rules imported and re-exported in this file.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load("//coq/_rules:coq_sublibrary.bzl" , _coq_sublibrary = "coq_sublibrary")
load("//coq/_rules:coq_library.bzl"    , _coq_library = "coq_library")

coq_sublibrary = _coq_sublibrary
coq_library    = _coq_library
