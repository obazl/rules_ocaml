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

################ Config Settings ################
CompilationModeSettingProvider = provider(
    doc = "Raw value of compilation_mode_flag or setting",
    fields = {
        "value": "The value of the build setting in the current configuration. " +
                 "This value may come from the command line or an upstream transition, " +
                 "or else it will be the build setting's default.",
    },
)

################
OcamlVerboseFlagProvider = provider(
    doc = "Raw value of ocaml_verbose_flag",
    fields = {
        "value": "The value of the build setting in the current configuration. " +
                 "This value may come from the command line or an upstream transition, " +
                 "or else it will be the build setting's default.",
    },
)

################################################################
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

################################################################
# OcamlStdLib = provider()

# OcamlConfigInfo = provider()

# OcamlContextInfo = provider()

# CocamlContextInfo = provider()

# EXPLICIT_PATH = "explicit"

# INFERRED_PATH = "inferred"

# EXPORT_PATH = "export"

OcamlDepsetProvider = provider(
    doc = "A Provider struct used by OBazl rules to provide heterogenous dependencies. Not provided by rule.",
    fields = {
        "opam"   : "depset of OPAM deps (Labels) of target",
        "nopam"  : "depset of non-OPAM deps (Files) of target",
        "cclib"  : "depset of C/C++ lib deps"
   }
)

OcamlArchivePayload = provider(
    doc = "A Provider struct used by [OcamlArchiveProvider](#ocamlarchiveprovider) and [PpxArchiveProvider](providers_ppx.md#ppxarchiveprovider). Not provided by rule.",
    fields = {
        "archive": "Name of archive",
        "cmxa"   : ".cmxa file produced by the target (native mode)",
        "a"      : ".a file produced by the target (native mode)",
        "cma"    : ".cma file produced by the target (bytecode mode)",
        "cmxs"   : ".cmxs file produced by the target  (shared object)",
        # "modules": "list of cmx files archived"
    }
)

OcamlArchiveProvider = provider(
    doc = """OCaml archive provider.

Provided by rule: [ocaml_archive](rules_ocaml.md#ocaml_archive)
    """,
    fields = {
        "payload": "An [OcamlArchivePayload](#ocamlarchivepayload) provider",
        "deps"   : "An [OcamlDepsetProvider](#ocamldepsetprovider) provider."
    }
)

OcamlLibraryProvider = provider(
    doc = """OCaml library provider. A library is a collection of modules, not to be confused with an archive.

Provided by rule: [ocaml_library](rules_ocaml#ocaml_library)
    """,
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
        "payload": "An [OcamlInterfacePayload](#ocamlinterfacepayload) structure.",
        "deps"   : "An [OcamlDepsetProvider](#ocamldepsetprovider)."
    }
)

OcamlInterfacePayload = provider(
    doc = "OCaml interface payload.",
    fields = {
        "cmi"  : ".cmi file produced by the target",
        "mli"  :  ".mli source file. without the source file, the cmi file will be ignored!"
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

OcamlModulePayload = provider(
    doc = "OCaml module payload.",
    fields = {
        "cmx"  : ".cmx file produced by the target (native mode)",
        "o"    : ".o file produced by the target (native mode)",
        "cmo"  : ".cmo file produced by the target (bytecode mode)",
        # "cm"   : ".cmx/cmo file produced by the target",
        "cmi"  : ".cmi file produced by the target (optional)",
        "mli"  : ".mli source file (optional)",
        "cmt"  : ".cmt file produced by the target (optional)"
    }
)

OcamlModuleProvider = provider(
    doc = "OCaml module provider.",
    fields = {
        "payload": "An [OcamlModulePayload](#ocamlmodulepayload) provider.",
        "deps"   : "An [OcamlDepsetProvider](#ocamldepsetprovider) provider."
    }
)

OcamlNsModuleProvider = provider(
    doc = "OCaml module provider.",
    fields = {
        "payload": "An [OcamlNsModulePayload](#ocamlnsmodulepayload) structure.",
        "deps"   : "An [OcamlDepsetProvider](#ocamldepsetprovider)"
    }
)

OcamlNsModulePayload = provider(
    doc = "OCaml NS Module payload provider.",
    fields = {
        "ns"  : "namespace string",
        "sep" : "separator string",
        "cmx"  : ".cmx file produced by the target (native mode)",
        "o"   : ".o file produced by the target (native mode)",
        "cmo"  : ".cmo file produced by the target (native mode)",
        "cmi" : ".cmi file produced by the target",
    }
)
