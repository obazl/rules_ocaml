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

OcamlSDK = provider(
    doc = "Contains information about the Ocaml SDK used in the toolchain",
    fields = {
        "path": "Absolute path to sdk",
        "ocamlos": "The host OS the SDK was built for.",
        "ocamlarch": "The host architecture the SDK was built for.",
        "root_file": "A file in the SDK root directory",
        "libs": ("List of pre-compiled .a files for the standard library " +
                 "built for the execution platform."),
        "headers": ("List of .h files from pkg/include that may be included " +
                    "in assembly sources."),
        "srcs": ("List of source files for importable packages in the " +
                 "standard library. Internal, vendored, and tool packages " +
                 "may not be included."),
        "package_list": ("A file containing a list of importable packages " +
                         "in the standard library."),
        "tools": ("List of executable files in the SDK built for " +
                  "the execution platform, excluding the ocaml binary file"),
        "ocaml": "The ocaml binary file",
    },
)

OcamlStdLib = provider()

OcamlConfigInfo = provider()

OcamlContextInfo = provider()

CocamlContextInfo = provider()

EXPLICIT_PATH = "explicit"

INFERRED_PATH = "inferred"

EXPORT_PATH = "export"

OcamlArchiveProvider = provider(
    doc = "OCaml library provider. A library is a collection of modules.",
    fields = {
        "payload": """A struct with the following fields:
            archive: Name of archive
            cmxa: .cmxa file produced by the target (native compiler)
            cma : .cma file produced by the target (bytecode compiler)
            cmxs: .cmxs file produced by the target  (shared object)
            a   : .a file produced by the target
            modules: list of cmx files archived
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
            cclib: c/c++ lib deps
        """
    }
)

OcamlLibraryProvider = provider(
    doc = "OCaml library provider. A library is a collection of modules.",
    fields = {
        "payload": """A struct with the following fields:
            library: Name of library
            modules : vector of modules in lib
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
            cclib: c/c++ lib deps
        """
    }
)

OcamlInterfaceProvider = provider(
    doc = "OCaml interface provider.",
    fields = {
        "payload": """A struct with the following fields:
            cmi: .cmi file produced by the target
            ml:  .ml source file. without the source file, the cmi file will be ignored!
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
        """
    }
)

OcamlImportProvider = provider(
    doc = "OCaml import provider.",
    fields = {
        "payload": """A struct with the following fields:
            cmx: .cmx file produced by the target
            cma: .cma file produced by the target
            cmxa: .cmxa file produced by the target
            cmxs: .cmxs file produced by the target
        """,
            # ml:  .ml source file. without the source file, the cmi file will be ignored!
        "indirect"   : "A depset of indirect deps."
    }
)

OcamlModuleProvider = provider(
    doc = "OCaml module provider.",
    fields = {
        "payload": """A struct with the following fields:
            cmi: .cmi file produced by the target
            cm : .cmx/cmo file produced by the target
            o  : .o file produced by the target
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
            cclib: c/c++ lib deps
        """
    }
)

OcamlNsModuleProvider = provider(
    doc = "OCaml module provider.",
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
