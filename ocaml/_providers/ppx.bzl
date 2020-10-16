# Copyright 2020 Gregg Reynolds. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PpxInfo = provider(fields=["ppx", "cmo", "o", "cmx", "a", "cmxa"])

PpxArchiveProvider = provider(
    doc = "OCaml PPX archive provider.",
    fields = {
        "payload": """A struct with the following fields:
            cmxa : .cmxa file produced by the target
            a    : .a file produced by the target
            # cmi  : .cmi file produced by the target
            # cm   : .cmx or .cmo file produced by the target
            # o    : .o file produced by the target
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            opam_lazy : extension output deps; needed when transformed source is compiled
            nopam: direct and transitive non-opam deps (Files) of target
            nopam_lazy : extension output deps; needed when transformed source is compiled
        """
    }
)

PpxExecutableProvider = provider(
    doc = "OCaml PPX binary provider.",
    fields = {
        "payload": "Executable file produced by the target.",
        "args"   : "Args to be passed when binary is invoked",
        "deps"   : """A triple of depsets:
            opam : direct and transitive opam deps (Labels) of target
            opam_lazy : extension output deps; needed when transformed source is compiled
            nopam: direct and transitive non-opam deps (Files) of target
            nopam_lazy : extension output deps; needed when transformed source is compiled
        """
    }
)

PpxLibraryProvider = provider(
    doc = "PPX library provider. A PPX library is a collection of ppx modules.",
    fields = {
        "payload": """A struct with the following fields:
            name: Name of library
            modules : vector of modules in lib
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            opam_lazy_deps : extension output deps; needed when transformed source is compiled
            nopam: direct and transitive non-opam deps (Files) of target
            nopam_lazy_deps : extension output deps; needed when transformed source is compiled
        """
    }
)

PpxModuleProvider = provider(
    doc = "OCaml PPX module provider.",
    fields = {
        "payload": """A struct with the following fields:
            cmi: .cmi file produced by the target
            # mli: ???
            cm: .cmx or .cmo file produced by the target
            o  : .o file produced by the target
        """,
        "deps"   : """A collectikon of depsets:
            opam : direct and transitive opam deps (Labels) of target
            opam_lazy : extension output deps; needed when transformed source is compiled
            nopam: direct and transitive non-opam deps (Files) of target
            nopam_lazy : extension output deps; needed when transformed source is compiled
            cc_deps : C/C++ deps
        """
    }
)
