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

# Once nested repositories work, this file should cease to exist.

load("//ocaml/private:common.bzl", "MINIMUM_BAZEL_VERSION")
load("//ocaml/private:skylib/lib/versions.bzl", "versions")

load("//ocaml/private:sdk.bzl", "ocaml_home_sdk")

# load("//ocaml/private:noocaml.bzl", "DEFAULT_NOOCAML", "ocaml_register_noocaml")
# load("//proto:ocamlocaml.bzl", "ocamlocaml_special_proto")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# print("private/repositories.bzl loading")

def ocaml_configure_tooling(is_rules_ocaml = False):
    """Declares workspaces the Ocaml rules depend on. Workspaces that use
    rules_ocaml should call this.

    See https://github.com/bazelbuild/rules_ocaml/blob/master/ocaml/workspace.rst#overriding-dependencies
    for information on each dependency.

    Instructions for updating this file are in
    https://github.com/bazelbuild/rules_ocaml/wiki/Updating-dependencies.

    PRs updating dependencies are NOT ACCEPTED. See
    https://github.com/bazelbuild/rules_ocaml/blob/master/ocaml/workspace.rst#overriding-dependencies
    for information on choosing different versions of these repositories
    in your own project.
    """
    # print("ocaml_configure_tooling")
    if getattr(native, "bazel_version", None):
        versions.check(MINIMUM_BAZEL_VERSION, bazel_version = native.bazel_version)

    # Repository of standard constraint settings and values.
    # Bazel declares this automatically after 0.28.0, but it's better to
    # define an explicit version.
    # _maybe(
    #     http_archive,
    #     name = "platforms",
    #     strip_prefix = "platforms-9ded0f9c3144258dad27ad84628845bcd7ca6fe6",
    #     # master, as of 2020-05-12
    #     urls = [
    #         "https://mirror.bazel.build/github.com/bazelbuild/platforms/archive/9ded0f9c3144258dad27ad84628845bcd7ca6fe6.zip",
    #         "https://github.com/bazelbuild/platforms/archive/9ded0f9c3144258dad27ad84628845bcd7ca6fe6.zip",
    #     ],
    #     sha256 = "81394f5999413fcdfe918b254de3c3c0d606fbd436084b904e254b1603ab7616",
    # )

    # Needed by rules_ocaml implementation and tests.
    # We can't call bazel_skylib_workspace from here. At the moment, it's only
    # used to register unittest toolchains, which rules_ocaml does not need.
    _maybe(
        http_archive,
        name = "bazel_skylib",
        # 1.0.2, latest as of 2020-05-12
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
        ],
        sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44",
    )

    # Needed for additional targets declared around binaries with c-archive
    # and c-shared link modes.
    # _maybe(
    #     git_repository,
    #     name = "rules_cc",
    #     remote = "https://github.com/bazelbuild/rules_cc",
    #     # master, as of 2020-05-21
    #     commit = "8c31dd406cf17611d7962bee4680cbc4360219ed",
    #     shallow_since = "1588944954 -0700",
    # )

    # This may be overridden by ocaml_register_toolchains, but it's not mandatory
    # for users to call that function (they may declare their own @ocaml_sdk and
    # register their own toolchains).
    # _maybe(
    #     ocaml_register_noocaml,
    #     name = "io_bazel_rules_noocaml",
    #     noocaml = DEFAULT_NOOCAML,
    # )

    # ocaml_name_hack(
    #     name = "io_bazel_rules_ocaml_name_hack",
    #     is_rules_ocaml = is_rules_ocaml,
    # )

    # opam_repo(name="opam")
    ocaml_home_sdk("ocaml_sdk")

    # print("ocaml_configure_tooling done")

def _maybe(repo_rule, name, **kwargs):
    if name not in native.existing_rules():
        # print("XXXXXXXXXXXXXXXX: " + name)
        repo_rule(name = name, **kwargs)

# def _ocaml_name_hack_impl(ctx):
#     ctx.file("BUILD.bazel")
#     content = "IS_RULES_OCAML = {}".format(ctx.attr.is_rules_ocaml)
#     ctx.file("def.bzl", content)

# ocaml_name_hack = repository_rule(
#     implementation = _ocaml_name_hack_impl,
#     attrs = {
#         "is_rules_ocaml": attr.bool(),
#     },
#     doc = """ocaml_name_hack records whether the main workspace is rules_ocaml.

# See documentation for _filter_transition_label in
# ocaml/private/rules/transition.bzl.
# """,
# )

# print("private/repositories.bzl loaded")
