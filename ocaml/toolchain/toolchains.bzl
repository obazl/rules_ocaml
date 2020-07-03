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

load(
    "@obazl_rules_ocaml//ocaml/private:sdk.bzl",
    _ocaml_register_toolchains = "ocaml_register_toolchains",
)
load(
    "@obazl_rules_ocaml//ocaml/private:sdk_list.bzl",
    _DEFAULT_VERSION = "DEFAULT_VERSION",
    _MIN_SUPPORTED_VERSION = "MIN_SUPPORTED_VERSION",
    _SDK_REPOSITORIES = "SDK_REPOSITORIES",
)
load(
    "@obazl_rules_ocaml//ocaml/private:platforms.bzl",
    "OCAMLARCH_CONSTRAINTS",
    "OCAMLOS_CONSTRAINTS",
    "PLATFORMS",
)

# These symbols should be loaded from sdk.bzl or deps.bzl instead of here..
DEFAULT_VERSION = _DEFAULT_VERSION
MIN_SUPPORTED_VERSION = _MIN_SUPPORTED_VERSION
SDK_REPOSITORIES = _SDK_REPOSITORIES
ocaml_register_toolchains = _ocaml_register_toolchains

def declare_constraints():
    """Generates constraint_values and platform targets for valid platforms.

    Each constraint_value corresponds to a valid ocamlos or ocamlarch.
    The ocamlos and ocamlarch values belong to the constraint_settings
    @platforms//os:os and @platforms//cpu:cpu, respectively.
    To avoid redundancy, if there is an equivalent value in @platforms,
    we define an alias here instead of another constraint_value.

    Each platform defined here selects a ocamlos and ocamlarch constraint value.
    These platforms may be used with --platforms for cross-compilation,
    though users may create their own platforms (and
    @bazel_tools//platforms:default_platform will be used most of the time).
    """
    for ocamlos, constraint in OCAMLOS_CONSTRAINTS.items():
        if constraint.startswith("@obazl_rules_ocaml//ocaml/toolchain:"):
            native.constraint_value(
                name = ocamlos,
                constraint_setting = "@platforms//os:os",
            )
        else:
            native.alias(
                name = ocamlos,
                actual = constraint,
            )

    for ocamlarch, constraint in OCAMLARCH_CONSTRAINTS.items():
        if constraint.startswith("@obazl_rules_ocaml//ocaml/toolchain:"):
            native.constraint_value(
                name = ocamlarch,
                constraint_setting = "@platforms//cpu:cpu",
            )
        else:
            native.alias(
                name = ocamlarch,
                actual = constraint,
            )

    native.constraint_setting(
        name = "cocaml_constraint",
    )

    native.constraint_value(
        name = "cocaml_on",
        constraint_setting = ":cocaml_constraint",
    )

    native.constraint_value(
        name = "cocaml_off",
        constraint_setting = ":cocaml_constraint",
    )

    for p in PLATFORMS:
        native.platform(
            name = p.name,
            constraint_values = p.constraints,
        )
