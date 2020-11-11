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

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load
load("//implementation:common.bzl", "MINIMUM_BAZEL_VERSION")
# load("//implementation:skylib/lib/versions.bzl", "versions")

# load("//implementation:sdk.bzl", "ocaml_home_sdk")
# load("//opam:opam.bzl", "opam_repo")
load("//obazl:obazl.bzl", "obazl_repo")

load("//ocaml/_bootstrap:opam.bzl", "opam_configure")
# load("//opam:bootstrap.bzl",    _opam_configure = "opam_configure")

load(
    "//ocaml/_toolchains:sdk.bzl",
    "ocaml_register_toolchains",
    # _ocaml_download_sdk = "ocaml_download_sdk",
    # _ocaml_home_sdk = "ocaml_home_sdk",
    # _ocaml_local_sdk = "ocaml_local_sdk",
    # _ocaml_wrap_sdk = "ocaml_wrap_sdk",
)

# load("//implementation:noocaml.bzl", "DEFAULT_NOOCAML", "ocaml_register_noocaml")
# load("//proto:ocamlocaml.bzl", "ocamlocaml_special_proto")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# print("private/repositories.bzl loading")

def _detect_installed_sdk_home(ctx):
    """returns sdk installation root, ie. OCAMLROOT.

    FIXME: should return ocaml root in $HOME, which may be different than OCAMLROOT.
"""
    # print("_detect_installed_sdk_home")
    if "OPAM_SWITCH_PREFIX" in ctx.os.environ:
        return ctx.os.environ["OPAM_SWITCH_PREFIX"]
    else:
        fail("Env. var OPAM_SWITCH_PREFIX is unset; try running 'opam env'")

def _ocaml_repo_impl(repo_ctx):
    sdkpath = _detect_installed_sdk_home(repo_ctx)

    repo_ctx.template(
        "BUILD.bazel",
        Label("//ocaml/_bootstrap/ocaml/templates:BUILD.ocaml.tpl"),
        executable = False,
        substitutions = {
            "{sdkpath}": sdkpath
        },
    )
    repo_ctx.template(
        "tools/BUILD.bazel",
        Label("//ocaml/_bootstrap/ocaml/templates:BUILD.tools.tpl"),
        executable = False,
        substitutions = {
            "{sdkpath}": sdkpath
        },
    )
    repo_ctx.template(
        "mode/BUILD.bazel",
        Label("//ocaml/_bootstrap/ocaml/templates:BUILD.mode.tpl"),
        executable = False,
        substitutions = {
            "{sdkpath}": sdkpath
        },
    )
    ocaml_version = repo_ctx.execute(["ocaml", "-vnum"]).stdout.strip()
    [ocaml_major, sep, rest] = ocaml_version.partition(".")
    [ocaml_minor, sep, rest] = rest.partition(".")
    [ocaml_patch, sep, rest] = rest.partition(".")
    repo_ctx.template(
        "version/BUILD.bazel",
        Label("//ocaml/_bootstrap/ocaml/templates:BUILD.version.tpl"),
        executable = False,
        substitutions = {
            "{VERSION}": ocaml_version,
            "{MAJOR}": ocaml_major,
            "{MINOR}": ocaml_minor,
            "{PATCH}":  ocaml_patch
        },
    )
    repo_ctx.template(
        "csdk/BUILD.bazel",
        Label("//ocaml/_bootstrap/ocaml/templates:BUILD.csdk.tpl"),
        executable = False,
        substitutions = {
            "{sdkpath}": sdkpath
        },
    )
    repo_ctx.template(
        "csdk/ctypes/BUILD.bazel",
        Label("//ocaml/_bootstrap/ocaml/templates:BUILD.ctypes.csdk.tpl"),
        executable = False,
        substitutions = {
            "{sdkpath}": sdkpath
        },
    )

    if "OPAMROOT" in repo_ctx.os.environ:
        repo_ctx.symlink(repo_ctx.os.environ["OPAMROOT"], "opamroot")
        # repo_ctx.symlink(opamroot, "opamroot")
    else:
        fail("Environment var OPAMROOT must be set (try `$ export OPAMROOT=~/.opam'un).")
    if "OPAM_SWITCH_PREFIX" in repo_ctx.os.environ:
        repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"], "switch")
        # repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/bin", "tools")
        repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/ocaml", "csdk/ocaml")
        # repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/ocaml/caml", "csdk/include")
        repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/ctypes", "csdk/ctypes/api")
        # repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/ctypes", "lib/ctypes/api")
        # repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/integers", "csdk/integers/api")
    else:
        fail("Env. var OPAM_SWITCH_PREFIX is unset; try running 'opam env'")

_ocaml_repo = repository_rule(
    implementation = _ocaml_repo_impl,
    environ = ["OCAMLROOT", "OPAM_SWITCH_PREFIX"],
    configure = True
)

def ocaml_configure(is_rules_ocaml = False,
                    opam = None):
    """Declares workspaces (repositories) the Ocaml rules depend on. Workspaces that use
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
    # print("ocaml_configure")
    # print(opam)

    # if getattr(native, "bazel_version", None):
    #     versions.check(MINIMUM_BAZEL_VERSION, bazel_version = native.bazel_version)

    # Needed by rules_ocaml implementation and tests.
    # We can't call bazel_skylib_workspace from here. At the moment, it's only
    # used to register unittest toolchains, which rules_ocaml does not need.
    maybe(
        http_archive,
        name = "bazel_skylib",
        # 1.0.2, latest as of 2020-05-12
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
        ],
        sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44",
    )

    opam_configure()

    # ocaml_home_sdk("ocaml")
    _ocaml_repo(name="ocaml") # opam=opam)

    obazl_repo(name="obazl")

    ocaml_register_toolchains(installation="host")

    # print("ocaml_configure done")

# def _maybe(repo_rule, name, **kwargs):
#     if name not in native.existing_rules():
#         # print("XXXXXXXXXXXXXXXX: " + name)
#         repo_rule(name = name, **kwargs)

# def _ocaml_name_hack_impl(repo_ctx):
#     repo_ctx.file("BUILD.bazel")
#     content = "IS_RULES_OCAML = {}".format(repo_ctx.attr.is_rules_ocaml)
#     repo_ctx.file("def.bzl", content)

# ocaml_name_hack = repository_rule(
#     implementation = _ocaml_name_hack_impl,
#     attrs = {
#         "is_rules_ocaml": attr.bool(),
#     },
#     doc = """ocaml_name_hack records whether the main workspace is rules_ocaml.

# See documentation for _filter_transition_label in
# ocaml/_rules/transition.bzl.
# """,
# )

# print("private/repositories.bzl loaded")
