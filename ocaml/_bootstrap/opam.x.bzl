# Copyright 2014 Gregg Reynolds. All rights reserved.
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

# Bootstrap @opam repo.
#   a. verify opam installation, installing if needed
#   b. initialize @opam repo (build files, symlinks etc.)

OpamInfo = provider(
    doc = "A singleton provider that contains OPAM config info.",
    fields = {
        "root"  : "Value of `opam var root`",
        "switch": "Value of `opam var switch`"
    },
)

def is_ppx_driver(repo_ctx, pkg):
    # 'ocamlfind printppx' prints the ppx preprocessor options as they would
    # occur in an OCaml compiler invocation for the packages listed in
    # the command. The output includes one "-ppx" option for each
    # preprocessor. The possible options have the same meaning as for
    # "ocamlfind ocamlc". The option "-predicates" adds assumed
    # predicates and "-ppxopt package,arg" adds "arg" to the ppx
    # invocation of package package.
    # This tells us which packages can serve as ppx exes (?)
    query_result = repo_ctx.execute(["ocamlfind", "printppx", pkg]).stdout.strip()
    # print("IS PPX DRIVER? {pkg} : {ppx}".format( pkg = pkg, ppx = len(query_result)))
    if len(query_result) == 0:
        return False
    else:
        return True

def _opam_repo_impl(repo_ctx):
    print("_bootstrap/opam.bzl opam_configure()")
    repo_ctx.report_progress("Bootstrapping repo @%s" % repo_ctx.name)
    ## pause so we can see the progress msg:
    # for i in range(100000000): x = i

    opampgm = repo_ctx.which("opam") # "/usr/local/Cellar/opam/2.0.7/bin"
    if opampgm:
        print("OPAM PGM: %s" % opampgm)
    else:
        fail("Could not find opam executable.")

    opamroot = repo_ctx.execute(["opam", "var", "root"]).stdout.strip()
    print("OPAMROOT: %s" % opamroot)
    opamswitch = repo_ctx.execute(["opam", "var", "switch"]).stdout.strip()
    print("OPAMSWITCH: %s" % opamswitch)

    # print("repo_ctx.name: %s" % repo_ctx.name)
    # print("repo_ctx.os.environ:")
    # print(repo_ctx.os.environ)

    repo_ctx.report_progress("Bootstrap: processing {} packages.".format(len(repo_ctx.attr.pkgs)))
    ## pause so we can see the progress msg:
    # for i in range(100000000): x = i

    # if repo_ctx.attr.verify:
    #     print("VERIFYING")
    verify = False
    if "OBAZL_VERIFY_OPAM" in repo_ctx.os.environ:
        print("ENV: %s" % repo_ctx.os.environ["OBAZL_VERIFY_OPAM"])
        if bool(int(repo_ctx.os.environ["OBAZL_VERIFY_OPAM"])):
            print("Verifying OPAM package installation...")
            verify = True
    #     else:
    #         print("VERIFYING DISABLED")
    # else:
    #     print("VERIFYING DISABLED")
    print("Processing packages")
    not_found = []
    repo_ctx.report_progress("Processing {} packages...".format(len(repo_ctx.attr.pkgs)))
    for (pkg, version) in repo_ctx.attr.pkgs.items():
        repo_ctx.report_progress("Processing {}: {}...".format(pkg, version))
        print("Processing %s" % pkg)
        if verify:
            # r = repo_ctx.execute(["opam", "show", pkg])
            # print("SHOW {} rc: {}".format(pkg, r.return_code))
            # print("SHOW {} stdout: {}".format(pkg, r.stdout))
            # print("SHOW {} stderr: {}".format(pkg, r.stderr))
            r = repo_ctx.execute(["opam", "install", "-v", pkg])
            # print("INSTALL rc: %s" % r.return_code)
            # print("INSTALL stdout: %s" % r.stdout)
            print("INSTALL stderr: %s" % r.stderr)
            if r.return_code == 0: repo_ctx.report_progress("...installed {}".format(pkg))
            elif r.return_code == 5:
                repo_ctx.report_progress("...NOT found")
                not_found.append(pkg)
            # else:
            #     print("INSTALL rc: %s" % r.return_code)
            #     print("INSTALL stdout: %s" % r.stdout)
            #     print("INSTALL stderr: %s" % r.stderr)

    # for pkg in not_found:
    #     if verify:
    #         print("installing {}...".format(pkg))
    #         r = repo_ctx.execute(["opam", "install", pkg])
    #         print("install rc: {}".format(r.return_code))
    #         print(r.stdout)
    #         print(r.stderr)
    #         # print("Not found: %s" % pkg)

    repo_ctx.report_progress("Bootstrap: configuring Bazel rules for OPAM packages...")
    opam_pkgs = []
    print("Configuring rules...")
    for (pkg, version) in repo_ctx.attr.pkgs.items():
        print("Configuring rule for %s" % pkg)
        repo_ctx.report_progress("Configuring rule for {}...".format(pkg))
        ## WARNING: this is slow
        # ppx = is_ppx_driver(repo_ctx, pkg)
        opam_pkgs.append(
            "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = False )
        )
    # print("ocamlfind pkgs:")
    # for p in opam_pkgs:
    #   print(p)
    ocamlfind_pkgs = "\n".join(opam_pkgs)

    print("Writing BUILD.bazel files...")
    repo_ctx.file("WORKSPACE", "", False)
    repo_ctx.template(
        "BUILD.bazel",
        Label("//ocaml/_bootstrap/opam:BUILD.opam.tpl"),
        executable = False,
        # substitutions = { "{opam_pkgs}": ocamlfind_pkgs }
    )
    repo_ctx.template(
        "pkg/BUILD.bazel",
        Label("//ocaml/_bootstrap/opam:BUILD.opampkg.tpl"),
        executable = False,
        substitutions = { # "{has_pkg_values}": has_pkgs,
                          "{opam_pkgs}": ocamlfind_pkgs }
    )
    # repo_ctx.file(
    #     "BUILD.bazel",
    #     content = "filegroup(name = \"foo\", srcs=glob([\"**\"]))",
    #     executable = False,
    # )



_xopam_repo = repository_rule(
    implementation = _opam_repo_impl,
    # configure = True,  # inspects system for config
    # local = True,
    # attrs = dict(
    #     switch   = attr.string(
    #         # mandatory = True
    #     ),
    #     hermetic = attr.bool(
    #         default = True
    #     ),
    #     pkgs = attr.string_dict(
    #         doc = "List of OPAM packages to install."
    #     ),
    #     verify = attr.bool(
    #         default = False
    #     )
    # )
)

def opam_configure(hermetic = False,
                   opam = None,
                   # switch = None,
                   pkgs = None):
    print("OPAM CONFIG:")
    # print(opam)
    # if hermetic:
    #     if not opam:
    #         fail("Hermetic builds require a list of OPAM deps.")
    # _opam_private_repo(name="_opam")
    result = _xopam_repo(name="opam")
                        # hermetic = False,
                        # verify = opam.verify if opam else False,
                        # switch = opam.switch if opam else None,
                        # pkgs = opam.pkgs if opam else {})
    # print("OPAM_CONFIGURE RESULT:")
    # print("root: %s"    % opamroot)
    # print("switch: %s" % opamswitch)
    # print("OPAMROOT: %s" % opamroot)
    # return opam
