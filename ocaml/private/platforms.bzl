# Copyright 2019 The Bazel Authors. All rights reserved.
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

# platforms.bzl defines PLATFORMS, a table that describes each possible
# target platform. This table is used to generate config_settings,
# constraint_values, platforms, and toolchains.

BAZEL_OCAMLOS_CONSTRAINTS = {
    "android": "@platforms//os:android",
    "darwin": "@platforms//os:osx",
    "freebsd": "@platforms//os:freebsd",
    "linux": "@platforms//os:linux",
    "windows": "@platforms//os:windows",
}

BAZEL_OCAMLARCH_CONSTRAINTS = {
    "386": "@platforms//cpu:x86_32",
    "amd64": "@platforms//cpu:x86_64",
    "arm": "@platforms//cpu:arm",
    "arm64": "@platforms//cpu:aarch64",
    "ppc64le": "@platforms//cpu:ppc",
    "s390x": "@platforms//cpu:s390x",
}

OCAMLOS_OCAMLARCH = (
    ("aix", "ppc64"),
    ("android", "386"),
    ("android", "amd64"),
    ("android", "arm"),
    ("android", "arm64"),
    ("darwin", "386"),
    ("darwin", "amd64"),
    ("darwin", "arm"),
    ("darwin", "arm64"),
    ("dragonfly", "amd64"),
    ("freebsd", "386"),
    ("freebsd", "amd64"),
    ("freebsd", "arm"),
    ("freebsd", "arm64"),
    ("illumos", "amd64"),
    ("js", "wasm"),
    ("linux", "386"),
    ("linux", "amd64"),
    ("linux", "arm"),
    ("linux", "arm64"),
    ("linux", "mips"),
    ("linux", "mips64"),
    ("linux", "mips64le"),
    ("linux", "mipsle"),
    ("linux", "ppc64"),
    ("linux", "ppc64le"),
    ("linux", "riscv64"),
    ("linux", "s390x"),
    ("nacl", "386"),
    ("nacl", "amd64p32"),
    ("nacl", "arm"),
    ("netbsd", "386"),
    ("netbsd", "amd64"),
    ("netbsd", "arm"),
    ("netbsd", "arm64"),
    ("openbsd", "386"),
    ("openbsd", "amd64"),
    ("openbsd", "arm"),
    ("openbsd", "arm64"),
    ("plan9", "386"),
    ("plan9", "amd64"),
    ("plan9", "arm"),
    ("solaris", "amd64"),
    ("windows", "386"),
    ("windows", "amd64"),
    ("windows", "arm"),
)

RACE_OCAMLOS_OCAMLARCH = {
    ("darwin", "amd64"): None,
    ("freebsd", "amd64"): None,
    ("linux", "amd64"): None,
    ("windows", "amd64"): None,
}

MSAN_OCAMLOS_OCAMLARCH = {
    ("linux", "amd64"): None,
}

COCAML_OCAMLOS_OCAMLARCH = {
    ("aix", "ppc64"): None,
    ("android", "386"): None,
    ("android", "amd64"): None,
    ("android", "arm"): None,
    ("android", "arm64"): None,
    ("darwin", "amd64"): None,
    ("darwin", "arm"): None,
    ("darwin", "arm64"): None,
    ("dragonfly", "amd64"): None,
    ("freebsd", "386"): None,
    ("freebsd", "amd64"): None,
    ("freebsd", "arm"): None,
    ("illumos", "amd64"): None,
    ("linux", "386"): None,
    ("linux", "amd64"): None,
    ("linux", "arm"): None,
    ("linux", "arm64"): None,
    ("linux", "mips"): None,
    ("linux", "mips64"): None,
    ("linux", "mips64le"): None,
    ("linux", "mipsle"): None,
    ("linux", "ppc64le"): None,
    ("linux", "riscv64"): None,
    ("linux", "s390x"): None,
    ("linux", "sparc64"): None,
    ("netbsd", "386"): None,
    ("netbsd", "amd64"): None,
    ("netbsd", "arm"): None,
    ("netbsd", "arm64"): None,
    ("openbsd", "386"): None,
    ("openbsd", "amd64"): None,
    ("openbsd", "arm"): None,
    ("openbsd", "arm64"): None,
    ("solaris", "amd64"): None,
    ("windows", "386"): None,
    ("windows", "amd64"): None,
}

def _generate_constraints(names, bazel_constraints):
    return {
        name: bazel_constraints.get(name, "@obazl_rules_ocaml//ocaml/toolchain:" + name)
        for name in names
    }

OCAMLOS_CONSTRAINTS = _generate_constraints([p[0] for p in OCAMLOS_OCAMLARCH], BAZEL_OCAMLOS_CONSTRAINTS)
OCAMLARCH_CONSTRAINTS = _generate_constraints([p[1] for p in OCAMLOS_OCAMLARCH], BAZEL_OCAMLARCH_CONSTRAINTS)

def _generate_platforms():
    platforms = []
    for ocamlos, ocamlarch in OCAMLOS_OCAMLARCH:
        constraints = [
            OCAMLOS_CONSTRAINTS[ocamlos],
            OCAMLARCH_CONSTRAINTS[ocamlarch],
        ]
        platforms.append(struct(
            name = ocamlos + "_" + ocamlarch,
            ocamlos = ocamlos,
            ocamlarch = ocamlarch,
            constraints = constraints + ["@obazl_rules_ocaml//ocaml/toolchain:cocaml_off"],
            cocaml = False,
        ))
        if (ocamlos, ocamlarch) in COCAML_OCAMLOS_OCAMLARCH:
            # On Windows, Bazel will pick an MSVC toolchain unless we
            # specifically request mingw or msys.
            mingw = ["@bazel_tools//tools/cpp:mingw"] if ocamlos == "windows" else []
            platforms.append(struct(
                name = ocamlos + "_" + ocamlarch + "_cocaml",
                ocamlos = ocamlos,
                ocamlarch = ocamlarch,
                constraints = constraints + ["@obazl_rules_ocaml//ocaml/toolchain:cocaml_on"] + mingw,
                cocaml = True,
            ))

    for ocamlarch in ("arm", "arm64", "386", "amd64"):
        constraints = [
            "@platforms//os:ios",
            OCAMLARCH_CONSTRAINTS[ocamlarch],
        ]
        platforms.append(struct(
            name = "ios_" + ocamlarch,
            ocamlos = "darwin",
            ocamlarch = ocamlarch,
            constraints = constraints + ["@obazl_rules_ocaml//ocaml/toolchain:cocaml_off"],
            cocaml = False,
        ))
        platforms.append(struct(
            name = "ios_" + ocamlarch + "_cocaml",
            ocamlos = "darwin",
            ocamlarch = ocamlarch,
            constraints = constraints + ["@obazl_rules_ocaml//ocaml/toolchain:cocaml_on"],
            cocaml = True,
        ))

    return platforms

PLATFORMS = _generate_platforms()

def generate_toolchain_names():
    # keep in sync with declare_toolchains
    return ["ocaml_" + p.name for p in PLATFORMS if not p.cocaml]
