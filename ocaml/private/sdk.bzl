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

# load(
#     "@obazl//ocaml/private:ocaml_toolchain.bzl",
#     "declare_toolchains"
# )
load("@obazl//ocaml/private:ocaml_toolchains.bzl",
     "ocaml_toolchain")
load("@obazl//ocaml/private:providers.bzl",
     "OcamlSDK")
load("@obazl//opam:opam.bzl",
     "OPAMROOT",
     "opam_repo")
load("@obazl//ocaml/private:common.bzl",
     "OCAML_VERSION",
     "OCAMLBUILD_VERSION",
     "OCAMLFIND_VERSION",
     "DEFAULT_VERSION",
     "MIN_SUPPORTED_VERSION",
     "executable_path")

# load(
#     "@obazl//ocaml/private:noocaml.bzl",
#     "ocaml_register_noocaml",
# )
load(
    "@obazl//ocaml/private:platforms.bzl",
    "generate_toolchain_names",
)
load(
    "@obazl//ocaml/private:skylib/lib/versions.bzl",
    "versions",
)

# print("private/sdk.bzl loading")

OCAML_SDK = "ocaml"

def _ocaml_home_sdk_impl(ctx):
    # print("_ocaml_home_sdk_impl")
    # Go calls the next two in order to get <os> and <arch>,
    # which are params in the BUILD template.
    # if "HOME" in ctx.os.environ:
    #     opamroot = ctx.os.environ["HOME"] + "/.opam"
    # else:
    #     fail("HOME environment variable not set.")

    ocamlroot = _detect_installed_sdk_home(ctx)
    platform = _installed_sdk_triplet(ctx, ocamlroot)
    # print("ocamlroot: " + ocamlroot)
    _sdk_build_file(ctx, platform)
    # _symlink_sdk(ctx, ocamlroot)
    _symlink_sdk(ctx) # , opamroot, ctx.attr.switch)

_ocaml_home_sdk = repository_rule(
    _ocaml_home_sdk_impl,
    environ = ["OCAMLROOT", "OPAM_SWITCH_PREFIX"],
    configure = True
)

def ocaml_home_sdk(name, **kwargs):
    # print("ocaml_home_sdk: " + name)
    # print(kwargs)
    _ocaml_home_sdk(name = name, **kwargs)
    # print("ocaml_home_sdk done")
    # _register_toolchains(name)

def _ocaml_project_sdk_impl(repository_ctx):
    print("repository_ctx.attr.version: " + repository_ctx.attr.version)
    # if repository_ctx.attr.version:
    #     if repository_ctx.attr.sdks:
    #         fail("version and sdks must not both be set")
    #     if repository_ctx.attr.version not in SDK_REPOSITORIES:
    #         fail("unknown Ocaml version: {}".format(repository_ctx.attr.version))
    #     sdks = SDK_REPOSITORIES[repository_ctx.attr.version]
    # elif repository_ctx.attr.sdks:
    #     sdks = repository_ctx.attr.sdks
    # else:
    #     sdks = SDK_REPOSITORIES[DEFAULT_VERSION]

    # if not repository_ctx.attr.ocamlos and not repository_ctx.attr.ocamlarch:
    #     platform = _detect_host_platform(repository_ctx)
    # else:
    #     if not repository_ctx.attr.ocamlos:
    #         fail("ocamlos set but ocamlarch not set")
    #     if not repository_ctx.attr.ocamlarch:
    #         fail("ocamlarch set but ocamlos not set")
    #     platform = repository_ctx.attr.ocamlos + "_" + repository_ctx.attr.ocamlarch
    # if platform not in sdks:
    #     fail("unsupported platform {}".format(platform))
    # filename, sha256 = sdks[platform]
    # _sdk_build_file(repository_ctx, platform)
    # _remote_sdk(repository_ctx, [url.format(filename) for url in repository_ctx.attr.urls], repository_ctx.attr.strip_prefix, sha256)

_ocaml_project_sdk = repository_rule(
    _ocaml_project_sdk_impl,
    attrs = {
        "ocamlos": attr.string(),
        "ocamlarch": attr.string(),
        "sdks": attr.string_list_dict(),
        "urls": attr.string_list(default = ["https://dl.ocamlogle.com/ocaml/{}"]),
        "version": attr.string(),
        "strip_prefix": attr.string(default = "ocaml"),
    },
)

def ocaml_project_sdk(name, **kwargs):
    _ocaml_project_sdk(name = name, **kwargs)
    _register_toolchains(name)

def _ocaml_local_sdk_impl(repository_ctx):
    ocamlroot = repository_ctx.attr.path
    platform = _installed_sdk_triplet(repository_ctx, ocamlroot)
    _sdk_build_file(repository_ctx, platform)
    _symlink_sdk(repository_ctx) # , ocamlroot)

_ocaml_local_sdk = repository_rule(
    _ocaml_local_sdk_impl,
    attrs = {
        "path": attr.string(),
    },
)

def ocaml_local_sdk(name, **kwargs):
    _ocaml_local_sdk(name = name, **kwargs)
    _register_toolchains(name)

def _ocaml_wrap_sdk_impl(repository_ctx):
    ocamlroot = str(repository_ctx.path(repository_ctx.attr.root_file).dirname)
    platform = _installed_sdk_triplet(repository_ctx, ocamlroot)
    _sdk_build_file(repository_ctx, platform)
    _symlink_sdk(repository_ctx) # , ocamlroot)

_ocaml_wrap_sdk = repository_rule(
    _ocaml_wrap_sdk_impl,
    attrs = {
        "root_file": attr.label(
            mandatory = True,
            doc = "A file in the SDK root direcotry. Used to determine OCAMLROOT.",
        ),
    },
)

def ocaml_wrap_sdk(name, **kwargs):
    _ocaml_wrap_sdk(name = name, **kwargs)
    _register_toolchains(name)

def _register_toolchains(repo):
    print("_register_toolchains: " + repo)
    # labels = [
    #     "@{}//:{}".format(repo, name)
    #     for name in generate_toolchain_names()
    # ]
    # native.register_toolchains(*labels)

def _remote_sdk(ctx, urls, strip_prefix, sha256):
    # TODO(bazelbuild/bazel#7055): download_and_extract fails to extract
    # archives containing files with non-ASCII names. Ocaml 1.12b1 has a test
    # file like this. Remove this workaround when the bug is fixed.
    if len(urls) == 0:
        fail("no urls specified")
    if urls[0].endswith(".tar.gz"):
        if strip_prefix != "ocaml":
            fail("strip_prefix not supported")
        ctx.download(
            url = urls,
            sha256 = sha256,
            output = "ocaml_sdk.tar.gz",
        )
        res = ctx.execute(["tar", "-xf", "ocaml_sdk.tar.gz", "--strip-components=1"])
        if res.return_code:
            fail("error extracting Ocaml SDK:\n" + res.stdout + res.stderr)
        ctx.execute(["rm", "ocaml_sdk.tar.gz"])
    else:
        ctx.download_and_extract(
            url = urls,
            stripPrefix = strip_prefix,
            sha256 = sha256,
        )

def _symlink_sdk(ctx): # , opamroot, switch):
    # print("_symlink_sdk: " + opamroot + ", " + switch)
    if "OPAMROOT" in ctx.os.environ:
        ctx.symlink(ctx.os.environ["OPAMROOT"], "opamroot")
        # ctx.symlink(opamroot, "opamroot")
    else:
        fail("Environment var OPAMROOT must be set (try `$ export OPAMROOT=~/.opam'un).")
    if "OPAM_SWITCH_PREFIX" in ctx.os.environ:
        ctx.symlink(ctx.os.environ["OPAM_SWITCH_PREFIX"], "switch")
        ctx.symlink(ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/lib/ocaml", "csdk")
    else:
        fail("Env. var OPAM_SWITCH_PREFIX is unset; try running 'opam env'")
    # ctx.symlink(opamroot + "/" + switch, "switch")
    # print("_symlink_sdk done")

def _sdk_build_file(ctx, platform):
    # print("_sdk_build_file")
    ctx.file("ROOT")
    sdkpath = _detect_installed_sdk_home(ctx)
    ctx.template(
        "BUILD.bazel",
        Label("@obazl//ocaml/private:BUILD.sdk.tpl"),
        executable = False,
        substitutions = {
            "{sdkpath}": sdkpath
        },
    )
    # ctx.template(
    #     "csdk/BUILD.bazel",
    #     Label("@obazl//ocaml/private:BUILD.csdk.tpl"),
    #     executable = False,
    #     substitutions = {
    #         "{sdkpath}": sdkpath
    #     },
    # )

## We use a trick to obtain the absolute path of the sdk, which we
## need to set the PATH env var for the compilers. This rule is only
## used in the BUILD file that we generate, parameterized by the path
## at load time (which we can do from within a repository_rule).
## So rules that need the sdk path can get it from "@ocaml_sdk//:path"
def _ocaml_sdk_impl(ctx):
  return [OcamlSDK(path=ctx.attr.path)]

ocaml_sdkpath = rule(
    implementation = _ocaml_sdk_impl,
    attrs = {
        "path": attr.string(
            mandatory = True
        ),
    },
)

def _detect_host_platform(ctx):
    """returns <sys>_<arch>, e.g. darwin_amd64. uses bazel ctx.os, or system's uname

    If installation=project, sdk must be downloaded; in that case, this routine is called to find build_host platform descriptor (triplet?).
"""
    if ctx.os.name == "linux":
        host = "linux_amd64"
        res = ctx.execute(["uname", "-p"])
        if res.return_code == 0:
            uname = res.stdout.strip()
            if uname == "s390x":
                host = "linux_s390x"
            elif uname == "i686":
                host = "linux_386"

        # uname -p is not working on Aarch64 boards
        # or for ppc64le on some distros
        res = ctx.execute(["uname", "-m"])
        if res.return_code == 0:
            uname = res.stdout.strip()
            if uname == "aarch64":
                host = "linux_arm64"
            elif uname == "armv6l":
                host = "linux_arm"
            elif uname == "armv7l":
                host = "linux_arm"
            elif uname == "ppc64le":
                host = "linux_ppc64le"

        # Default to amd64 when uname doesn't return a known value.

    elif ctx.os.name == "linux":
        host = "linux_amd64"
    elif ctx.os.name == "mac os x":
        host = "darwin_amd64"
    elif ctx.os.name.startswith("windows"):
        host = "windows_amd64"
    elif ctx.os.name == "freebsd":
        host = "freebsd_amd64"
    else:
        fail("Unsupported operating system: " + ctx.os.name)

    return host

def _detect_installed_sdk_home(ctx):
    """returns sdk installation root, ie. OCAMLROOT.

    FIXME: should return ocaml root in $HOME, which may be different than OCAMLROOT.
"""
    # print("_detect_installed_sdk_home")
    if "OPAM_SWITCH_PREFIX" in ctx.os.environ:
        return ctx.os.environ["OPAM_SWITCH_PREFIX"]
    else:
        fail("Env. var OPAM_SWITCH_PREFIX is unset; try running 'opam env'")

    # root = "@invalid@"
    # # if "OCAMLROOT" in ctx.os.environ:
    # if "OPAMROOT" in ctx.os.environ:
    #     return ctx.os.environ["OPAMROOT"]
    # else:
    #     fail("OPAMROOT must be set.")

    # res = ctx.execute([executable_path(ctx, "opam"), "switch", "show"])
    # if res.return_code:
    #     fail("Could not detect host ocaml version")
    # root = res.stdout.strip()
    # if not root:
    #     fail("host ocaml version failed to report it's OCAMLROOT")
    # ##FIXME: get OPAMHOME
    # return "/Users/gar/.opam/" + root

def _installed_sdk_triplet(ctx, ocamlroot):
    """Return platform triple for installed sdk, e.g. darwin_amd64.
    Compare _detect_host_platform, used by download_sdk_impl.

    TODO: does ocaml provide a means of obtaining this info?

    """
    # res = ctx.execute(["ls", ocamlroot + "/pkg/tool"])
    # if res.return_code != 0:
    #     fail("Could not detect SDK platform")
    # for f in res.stdout.strip().split("\n"):
    #     if f.find("_") >= 0:
    #         return f
    # fail("Could not detect SDK platform")
    return "darwin_amd64"

## this is the fn used by the user, in WORKSPACE
def ocaml_register_toolchains(installation = None, noocaml = None):
    """See /ocaml/toolchains.rst#ocaml-register-toolchains for full documentation."""
    # print("ocaml_register_toolchains, installation = " + installation)
    sdk_kinds = ("_ocaml_project_sdk", "_ocaml_home_sdk", "_ocaml_local_sdk", "_ocaml_wrap_sdk")
    existing_rules = native.existing_rules()
    sdk_rules = [r for r in existing_rules.values() if r["kind"] in sdk_kinds]
    if len(sdk_rules) == 0 and OCAML_SDK in existing_rules:
        # may be local_repository in bazel_tests.
        sdk_rules.append(existing_rules[OCAML_SDK])

    opam_repo(name="opam")

    # if installation and len(sdk_rules) > 0:
    #     fail("installation set after ocaml sdk rule declared ({})".format(", ".join([r["name"] for r in sdk_rules])))
    if len(sdk_rules) == 0:
        if not installation:
            installation = DEFAULT_VERSION
        if installation == "host":
            ocaml_home_sdk(name = OCAML_SDK)
        else:
            if not versions.is_at_least(MIN_SUPPORTED_VERSION, installation):
                print("DEPRECATED: ocaml_register_toolchains: support for Ocaml versions before {} will be removed soon".format(MIN_SUPPORTED_VERSION))
                ocaml_project_sdk(
                    name = OCAML_SDK,
                    version = installation,
                )

    # toolchain target defined in generated file ocaml_sdk/BUILD.bazel
    native.register_toolchains("@ocaml//:ocaml_toolchain_native_macos")
    native.register_toolchains("@ocaml//:ocaml_toolchain_native_linux")
    native.register_toolchains("@ocaml//:ocaml_toolchain_bytecode_macos")
    # native.register_toolchains("@ocaml//:ocaml_toolchain_bytecode_linux")

    # if noocaml:
    #     # Override default definition in ocaml_rules_dependencies().
    #     ocaml_register_noocaml(
    #         name = "io_bazel_rules_noocaml",
    #         noocaml = noocaml,
    #     )

# print("private/sdk.bzl loaded")
