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

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def _ppx_repo_impl(repo_ctx):

    repo_ctx.template(
        "BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx"),
        executable = False
    )
    repo_ctx.template(
        "archive/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.archive"),
        executable = False
    )
    repo_ctx.template(
        "executable/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.executable"),
        executable = False
    )
    repo_ctx.template(
        "module/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.module"),
        executable = False
    )
    repo_ctx.template(
        "ns/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.ns"),
        executable = False
    )
    repo_ctx.template(
        "ocamlfind/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.ocamlfind"),
        executable = False
    )
    # repo_ctx.template(
    #     "module/BUILD.bzl",
    #     Label("//ppx/_templates:BUILD.ppx.module.bzl"),
    #     executable = False
    # )
    # repo_ctx.template(
    #     "executable/BUILD.bzl",
    #     Label("//ppx/_templates:BUILD.ppx.executable.bzl"),
    #     executable = False
    # )
    #### BUILD CONFIG FLAGS ####
    repo_ctx.template(
        "cmt/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.cmt"),
        executable = False,
    )
    repo_ctx.template(
        "debug/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.debug"),
        executable = False,
    )
    repo_ctx.template(
        "keep-locs/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.keep_locs"),
        executable = False,
    )
    repo_ctx.template(
        "mode/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.mode"),
        executable = False,
    )
    repo_ctx.template(
        "noassert/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.noassert"),
        executable = False,
    )
    repo_ctx.template(
        "opaque/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.opaque"),
        executable = False,
    )
    repo_ctx.template(
        "short-paths/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.short_paths"),
        executable = False,
    )
    repo_ctx.template(
        "strict-formats/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.strict_formats"),
        executable = False,
    )
    repo_ctx.template(
        "strict-sequence/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.strict_sequence"),
        executable = False,
    )
    repo_ctx.template(
        "verbose/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.verbose"),
        executable = False,
    )

    repo_ctx.template(
        "print/BUILD.bazel",
        Label("//ppx/_templates:BUILD.ppx.print"),
        executable = False
    )

ppx_repo = repository_rule(
    implementation = _ppx_repo_impl,
    environ = ["OCAMLROOT", "OPAM_SWITCH_PREFIX"],
    configure = True
)

