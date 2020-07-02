# Copyright 2014 The Bazel Authors. All rights reserved.
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

# A represenatation of the inputs to a ocaml package.
# This is a configuration independent provider.
# You must call resolve with a mode to produce a OcamlSource.
# See ocaml/providers.rst#OcamlLibrary for full documentation.
OcamlLibrary = provider()

# The filtered inputs and dependencies needed to build a OcamlArchive
# This is a configuration specific provider.
# It has no transitive information.
# See ocaml/providers.rst#OcamlSource for full documentation.
OcamlSource = provider()

# This compiled form of a package used in transitive dependencies.
# This is a configuration specific provider.
# See ocaml/providers.rst#OcamlArchiveData for full documentation.
OcamlArchiveData = provider()

# The compiled form of a OcamlLibrary, with everything needed to link it into a binary.
# This is a configuration specific provider.
# See ocaml/providers.rst#OcamlArchive for full documentation.
OcamlArchive = provider()

OcamlAspectProviders = provider()

OcamlPath = provider()

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

def get_source(dep):
    if type(dep) == "struct":
        return dep
    if OcamlAspectProviders in dep:
        return dep[OcamlAspectProviders].source
    return dep[OcamlSource]

def get_archive(dep):
    if type(dep) == "struct":
        return dep
    if OcamlAspectProviders in dep:
        return dep[OcamlAspectProviders].archive
    return dep[OcamlArchive]

def effective_importpath_pkgpath(lib):
    """Returns import and package paths for a given lib with modifications for display.

    This is used when we need to represent sources in a manner compatible with Ocaml
    build (e.g., for packaging or coverage data listing). _test suffixes are
    removed, and vendor directories from importmap may be modified.

    Args:
      lib: OcamlLibrary or OcamlArchiveData

    Returns:
      A tuple of effective import path and effective package path. Both are ""
      for synthetic archives (e.g., generated testmain).
    """
    if lib.pathtype not in (EXPLICIT_PATH, EXPORT_PATH):
        return "", ""
    importpath = lib.importpath
    importmap = lib.importmap
    if importpath.endswith("_test"):
        importpath = importpath[:-len("_test")]
    if importmap.endswith("_test"):
        importmap = importmap[:-len("_test")]
        parts = importmap.split("/")
    if "vendor" not in parts:
        # Unusual case not handled by ocaml build. Just return importpath.
        return importpath, importpath
    elif len(parts) > 2 and lib.label.workspace_root == "external/" + parts[0]:
        # Common case for importmap set by Gazelle in external repos.
        return importpath, importmap[len(parts[0]):]
    else:
        # Vendor directory somewhere in the main repo. Leave it alone.
        return importpath, importmap

OpamPkgInfo = provider(
    doc = "Provider for OPAM packages.",
    fields = {
        ## clients must write: dep[OpamPkgInfo].pkg.to_list()[0].name
        "pkg": "Label depset containing package name string used by ocamlfind.",
    }
)

OcamlArchiveProvider = provider(
    doc = "OCaml library provider. A library is a collection of modules.",
    fields = {
        "archive": """A struct with the following fields:
            name: Name of archive
            cma : .cma file produced by the target
            cmxa: .cmxa file produced by the target
            cmxs: .cmxs file produced by the target
            a   : .a file produced by the target
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
        """
    }
)

OcamlLibraryProvider = provider(
    doc = "OCaml library provider. A library is a collection of modules.",
    fields = {
        "payload": """A struct with the following fields:
            name: Name of library
            modules : vector of modules in lib
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
        """
    }
)

OcamlInterfaceProvider = provider(
    doc = "OCaml interface provider.",
    fields = {
        "interface": """A struct with the following fields:
            cmi: .cmi file produced by the target
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
        """
    }
)

OcamlModuleProvider = provider(
    doc = "OCaml module provider.",
    fields = {
        "payload": """A struct with the following fields:
            cmi: .cmi file produced by the target
            cmx: .cmx file produced by the target
            o  : .o file produced by the target
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
        """
    }
)

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
            nopam: direct and transitive non-opam deps (Files) of target
        """
    }
)

PpxBinaryProvider = provider(
    doc = "OCaml PPX binary provider.",
    fields = {
        "payload": "Executable file produced by the target.",
        "args"   : "Args to be passed when binary is invoked",
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
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
            nopam: direct and transitive non-opam deps (Files) of target
        """
    }
)

PpxModuleProvider = provider(
    doc = "OCaml PPX module provider.",
    fields = {
        "payload": """A struct with the following fields:
            cmi: .cmi file produced by the target
            cm: .cmx or .cmo file produced by the target
            o  : .o file produced by the target
        """,
        "deps"   : """A pair of depsets:
            opam : direct and transitive opam deps (Labels) of target
            nopam: direct and transitive non-opam deps (Files) of target
        """
    }
)
