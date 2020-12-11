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

# load("//implementation:sdk.bzl", "ocaml_home_sdk")
load("//obazl:obazl.bzl", "obazl_repo")

load("//ppx/_bootstrap:ppx.bzl", "ppx_repo")

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

##############################
def _get_opam_paths(repo_ctx):
    "returns opam root and switch prefix"

    result = repo_ctx.execute(["opam", "var", "root"])
    if result.return_code == 0:
        opam_root = result.stdout.strip()
    else:
        print("OPAM VAR OPAM_ROOT ERROR RC: %s" % result.return_code)
        print("OPAM VAR OPAM_ROOT STDOUT: %s" % result.stdout)
        print("OPAM VAR OPAM_ROOT STDERR: %s" % result.stderr)
        fail("OPAM VAR OPAM_ROOT ERROR")

    if repo_ctx.attr.opam_switch:
        opam_switch = repo_ctx.attr.opam_switch
    else:
        result = repo_ctx.execute(["opam", "var", "switch"])
        if result.return_code == 0:
            opam_switch = result.stdout.strip()
        else:
            print("OPAM VAR OPAM_ROOT ERROR RC: %s" % result.return_code)
            print("OPAM VAR OPAM_ROOT STDOUT: %s" % result.stdout)
            print("OPAM VAR OPAM_ROOT STDERR: %s" % result.stderr)
            fail("OPAM VAR OPAM_ROOT ERROR")

    print("OPAM SWITCH: %s" % opam_switch)
    result = repo_ctx.execute(["opam", "var",
                               "--switch=" + opam_switch,
                               "prefix"])
    if result.return_code == 0:
        opam_prefix = result.stdout.strip()
    else:
        print("OPAM VAR PREFIX ERROR RC: %s" % result.return_code)
        print("OPAM VAR PREFIX STDOUT: %s" % result.stdout)
        print("OPAM VAR PREFIX STDERR: %s" % result.stderr)
        fail("OPAM VAR PREFIX ERROR")

    return opam_root, opam_switch, opam_prefix
    # opam_switch = None

    # if "OBAZL_SWITCH" in repo_ctx.os.environ:
    #     print("OBAZL_SWITCH = %s" % repo_ctx.os.environ["OBAZL_SWITCH"])
    #     opam_switch = repo_ctx.os.environ["OBAZL_SWITCH"]
    #     print("Using '{s}' from OBAZL_SWITCH env var.".format(s = opam_switch))
    #     env_switch = True
    # else:
    #     opam_switch = repo_ctx.attr.opam_switch  # + "-" + repo_ctx.attr.switch_version
    #     env_switch = False
    # print("SWITCH: %s" % opam_switch)

    # if "OPAM_SWITCH_PREFIX" in repo_ctx.os.environ:
    #     return repo_ctx.os.environ["OPAM_SWITCH_PREFIX"]
    # else:
    #     fail("Env. var OPAM_SWITCH_PREFIX is unset; try running 'opam env'")

def _ocaml_repo_impl(repo_ctx):
    opam_root, opam_switch, opam_switch_prefix = _get_opam_paths(repo_ctx)
    # print("OPAM_ROOT: %s" % opam_root)
    # print("OPAM_SWITCH_PREFIX: %s" % opam_switch_prefix)

    repo_ctx.template(
        "BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml"),
        executable = False,
        substitutions = {
            "{sdkpath}": opam_switch_prefix
        },
    )
    repo_ctx.template(
        "csdk/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.csdk"),
        executable = False,
        # substitutions = {
        #     "{sdkpath}": opam_switch_prefix
        # },
    )
    repo_ctx.template(
        "csdk/ctypes/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.csdk.ctypes"),
        executable = False,
        # substitutions = {
        #     "{sdkpath}": opam_switch_prefix
        # },
    )

    #### ASPECTS ####
    repo_ctx.template(
        "aspects/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.aspects"),
        executable = False,
    )
    repo_ctx.template(
        "aspects/ppx.bzl",
        Label("//ocaml/_aspects:ppx.bzl"),
        executable = False,
    )

    #### BUILD CONFIG FLAGS ####
    repo_ctx.template(
        "cmt/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.cmt"),
        executable = False,
    )
    repo_ctx.template(
        "debug/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.debug"),
        executable = False,
    )
    repo_ctx.template(
        "keep-locs/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.keep_locs"),
        executable = False,
    )
    repo_ctx.template(
        "mode/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.mode"),
        executable = False,
    )
    repo_ctx.template(
        "noassert/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.noassert"),
        executable = False,
    )
    repo_ctx.template(
        "opaque/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.opaque"),
        executable = False,
    )
    repo_ctx.template(
        "short-paths/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.short_paths"),
        executable = False,
    )
    repo_ctx.template(
        "strict-formats/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.strict_formats"),
        executable = False,
    )
    repo_ctx.template(
        "strict-sequence/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.strict_sequence"),
        executable = False,
    )

    ## rule types
    repo_ctx.template(
        "archive/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.archive"),
        executable = False,
    )
    repo_ctx.template(
        "executable/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.executable"),
        executable = False,
    )
    repo_ctx.template(
        "module/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.module"),
        executable = False,
    )
    repo_ctx.template(
        "linkmode/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.linkmode"),
        executable = False,
    )
    repo_ctx.template(
        "ns/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.ns"),
        executable = False,
    )
    repo_ctx.template(
        "tools/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.tools"),
        executable = False,
        # substitutions = {
        #     "{sdkpath}": opam_switch_prefix
        # },
    )
    repo_ctx.template(
        "verbose/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.verbose"),
        executable = False,
    )

    ocaml_version = repo_ctx.execute(["ocaml", "-vnum"]).stdout.strip()
    [ocaml_major, sep, rest] = ocaml_version.partition(".")
    [ocaml_minor, sep, rest] = rest.partition(".")
    [ocaml_patch, sep, rest] = rest.partition(".")
    repo_ctx.template(
        "version/BUILD.bazel",
        Label("//ocaml/_templates:BUILD.ocaml.version"),
        executable = False,
        substitutions = {
            "{VERSION}": ocaml_version,
            "{MAJOR}": ocaml_major,
            "{MINOR}": ocaml_minor,
            "{PATCH}":  ocaml_patch
        },
    )

    ## FIXME: use "opam var prefix"???
    repo_ctx.symlink(opam_root, "opamroot")
    repo_ctx.symlink(opam_switch_prefix, "switch")
    # repo_ctx.symlink(opam_switch_prefix + "/bin", "tools")
    repo_ctx.symlink(opam_switch_prefix + "/lib/ocaml", "csdk/ocaml")
    # repo_ctx.symlink(opam_switch_prefix + "/lib/ocaml/caml", "csdk/include")
    repo_ctx.symlink(opam_switch_prefix + "/lib/ctypes", "csdk/ctypes/api")
    # repo_ctx.symlink(opam_switch_prefix + "/lib/ctypes", "lib/ctypes/api")
    # repo_ctx.symlink(opam_switch_prefix + "/lib/integers", "csdk/integers/api")

    # if "OPAMROOT" in repo_ctx.os.environ:
    #     print("OPAMROOT: %s" % repo_ctx.os.environ["OPAMROOT"])
    #     repo_ctx.symlink(repo_ctx.os.environ["OPAMROOT"], "opamroot")
    #     # repo_ctx.symlink(opamroot, "opamroot")
    # else:
    #     fail("Environment var OPAMROOT must be set (try '$ export OPAMROOT=~/.opam').")

    # if "OPAM_SWITCH_PREFIX" in repo_ctx.os.environ:
    #     repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"], "switch")
    #     # repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/bin", "tools")
    #     repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/ocaml", "csdk/ocaml")
    #     # repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/ocaml/caml", "csdk/include")
    #     repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/ctypes", "csdk/ctypes/api")
    #     # repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/ctypes", "lib/ctypes/api")
    #     # repo_ctx.symlink(repo_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/integers", "csdk/integers/api")
    # else:
    #     fail("Env. var OPAM_SWITCH_PREFIX is unset; try running 'opam env'")

##############################
_ocaml_repo = repository_rule(
    implementation = _ocaml_repo_impl,
    environ = ["OCAMLROOT", "OPAM_SWITCH_PREFIX"],
    attrs = dict(
        opam_switch = attr.string()
    ),
    configure = True
)

##############################
def configure(**kwargs):
    # is_rules_ocaml = False,
    #                 opam = None):
    """Declares workspaces (repositories) the Ocaml rules depend on. Workspaces that use
    rules_ocaml should call this.
    """
    # maybe(
    #     http_archive,
    #     name = "rules_foreign_cc",
    #     strip_prefix="rules_foreign_cc-master",
    #     url = "https://github.com/bazelbuild/rules_foreign_cc/archive/master.zip",
    #     sha256 = "3e6b0691fc57db8217d535393dcc2cf7c1d39fc87e9adb6e7d7bab1483915110"
    # )

    # opam_configure()

    # for [kw,arg] in kwargs.items():
    #     print("KWARG: {kw} = {arg}".format(kw = kw, arg = arg))

    ppx_repo(name="ppx")

    if hasattr(kwargs, "switch"):
        _ocaml_repo(name="ocaml", opam_switch = kwargs["switch"])
    else:
        _ocaml_repo(name="ocaml")

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
