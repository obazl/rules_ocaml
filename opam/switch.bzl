load("//ocaml/_debug:utils.bzl", "debug_report_progress")

    # result = repo_ctx.execute(["opam", "config", "var", "switch"])
    # if result.return_code == 0:
    #     current_switch = result.stdout.strip()
    # elif result.return_code == 5: # not found
    #     current_switch = "None"
    # else:
    #     print("OPAM cmd 'opam config var switch' ERROR RC: %s" % result.return_code)
    #     print("cmd STDOUT: %s" % result.stdout)
    #     print("cmd PREFIX STDERR: %s" % result.stderr)
    #     fail("OPAM cmd ERROR")

    # repo_ctx.report_progress("Current OPAM switch: %s" % current_switch)
    # print("Current OPAM switch: %s" % current_switch)

switch_name = ""

##############################
def opam_set_switch(repo_ctx):

    debug_report_progress(repo_ctx, "opam_set_switch")

    if "OPAMSWITCH" in repo_ctx.os.environ:
        # print("OPAMSWITCH = %s" % repo_ctx.os.environ["OPAMSWITCH"])
        switch_name = repo_ctx.os.environ["OPAMSWITCH"]
        # print("Using '{s}' from OPAMSWITCH env var.".format(s = switch_name))
        env_switch = True
    else:
        switch_name = repo_ctx.attr.switch_name
        env_switch = False

    print("@opam using switch '{s}'".format(s = switch_name))

    result = repo_ctx.execute(["opam", "switch", "set", switch_name])
    if result.return_code == 0:
        # print("FOUND SWITCH %s" % switch_name)
        result = repo_ctx.execute(["opam", "config", "var", "ocaml-base-compiler:version"])
        if result.return_code == 5: # not found
            # switch was created by ocaml_configure
            repo_ctx.report_progress("Installing '{c}' to switch '{s}'".format(
                c = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler,
                s = switch_name
            ))
            print("INSTALLING BASE COMPILER")
            result = repo_ctx.execute(["opam", "install", "-y", "--switch=" + switch_name,
                                       "ocaml-base-compiler." + repo_ctx.attr.switch_compiler])
    elif result.return_code == 5: # Not found

        if env_switch:
            repo_ctx.report_progress("SWITCH {s} from env var OPAMSWITCH not found.".format(s = switch_name))
            fail("\n\nERROR: Switch '{s}' (from env var OPAMSWITCH) not found. To create a new switch, either do so from the command line ('opam switch create <name> <version>') or configure the switch in the opam config file (by convention, \"bzl/opam.bzl\").\n\n".format(s = switch_name))

        else:
            # create new switch

            compiler = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler

            repo_ctx.report_progress("Switch {s} not found; creating with compiler {c}".format(
                s = switch_name, c = compiler
            ))
            # print("SWITCH {s} not found; creating".format(s = switch_name))

            result = repo_ctx.execute(["opam", "switch", "-y",
                                       "create", switch_name,
                                       compiler])
            if result.return_code == 0:
                repo_ctx.report_progress("SWITCH {s}: {c} installed.".format(
                    s = switch_name, c = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler
                ))
            else:
                print("ERROR cmd 'opam switch -y create {s} ocaml-base-compiler.{c}".format(
                    s=switch_name, c = repo_ctx.attr.switch_compiler
                ))
                print("cmd STDERR: %s" % result.stderr)
                print("cmd STDOUT: %s" % result.stdout)
                fail("ERROR cmd 'opam switch -y create {s} ocaml-base-compiler.{c}".format(
                    s=switch_name, c = repo_ctx.attr.switch_compiler
                ))
                return

            # result = repo_ctx.execute(["opam", "switch", "create", switch_name, "--empty"])
            # if result.return_code == 0:
            #     repo_ctx.report_progress("SWITCH {s} created. Installing {c} (may take a while)".format(
            #         s = switch_name, c = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler
            #     ))
            # else:
            #     print("SWITCH CREATE ERROR: %s" % result.return_code)
            #     print("SWITCH CREATE STDERR: %s" % result.stderr)
            #     print("SWITCH CREATE STDOUT: %s" % result.stdout)
            #     return
            # result = repo_ctx.execute(["opam", "install", "-y", "--switch=" + switch_name,
            #                            "ocaml-base-compiler." + repo_ctx.attr.switch_compiler])
            # if result.return_code == 0:
            #     repo_ctx.report_progress("SWITCH {s}: {c} installed.".format(
            #         s = switch_name, c = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler
            #     ))
            # else:
            #     print("SWITCH CREATE ERROR: %s" % result.return_code)
            #     print("SWITCH CREATE STDERR: %s" % result.stderr)
            #     print("SWITCH CREATE STDOUT: %s" % result.stdout)
            #     return
    elif result.return_code != 0:
        print("SWITCH RC: %s" % result.return_code)
        print("SWITCH STDERR: %s" % result.stderr)
        print("SWITCH STDOUT: %s" % result.stdout)
        return


def opam_set_switch_sh(repo_ctx):

    if "OPAMSWITCH" in repo_ctx.os.environ:
        print("OPAMSWITCH = %s" % repo_ctx.os.environ["OPAMSWITCH"])
        switch_name = repo_ctx.os.environ["OPAMSWITCH"]
        print("Using '{s}' from OPAMSWITCH env var.".format(s = switch_name))
        env_switch = True
    else:
        switch_name = repo_ctx.attr.switch_name
        env_switch = False

    result = repo_ctx.execute(["opam", "switch", "set", switch_name])
    if result.return_code == 0:
        print("FOUND SWITCH %s" % switch_name)
        result = repo_ctx.execute(["opam", "config", "var", "ocaml-base-compiler:version"])
        if result.return_code == 5: # not found
            # switch was created by ocaml_configure
            repo_ctx.report_progress("Installing '{c}' to switch '{s}'".format(
                c = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler,
                s = switch_name
            ))
            print("INSTALLING BASE COMPILER")
            result = repo_ctx.execute(["opam", "install", "-y", "--switch=" + switch_name,
                                       "ocaml-base-compiler." + repo_ctx.attr.switch_compiler])
    elif result.return_code == 5: # Not found

        if env_switch:
            repo_ctx.report_progress("SWITCH {s} from env var OPAMSWITCH not found.".format(s = switch_name))
            fail("\n\nERROR: Switch '{s}' (from env var OPAMSWITCH) not found. To create a new switch, either do so from the command line ('opam switch create <name> <version>') or configure the switch in the opam config file (by convention, \"bzl/opam.bzl\").\n\n".format(s = switch_name))

        else:
            # create new switch
            compiler = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler
            repo_ctx.report_progress("SWITCH {s} not found; creating with compiler {c}".format(
                s = switch_name, c = compiler
            ))
            print("SWITCH {s} not found; creating".format(s = switch_name))

            repo_ctx.report_progress("Waiting for switch to be created. May take a long time.")
            print("Waiting for switch to be created. May take a longish time.")
            tool = repo_ctx.path(Label(":switch.sh"))

            print("running shell script: %s" % tool)
            result2 = repo_ctx.execute([tool, switch_name])

            print("Found switch rc: %s" % result2.return_code)
            print("Found switch: stdout %s" % result2.stdout.strip())
            print("Found switch: stderr %s" % result2.stderr.strip())
            repo_ctx.report_progress("Found switch: %s" % result2.stdout.strip())
            result = repo_ctx.execute(["opam", "switch", "create", switch_name, "--empty"])
            result = repo_ctx.execute(["opam", "switch", "set", switch_name])

            # result = repo_ctx.execute(["opam", "switch", "-y",
            #                            "create", switch_name,
            #                            compiler])
            # if result.return_code == 0:
            #     repo_ctx.report_progress("SWITCH {s}: {c} installed.".format(
            #         s = switch_name, c = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler
            #     ))
            # else:
            #     print("ERROR cmd 'opam switch -y create {s} ocaml-base-compiler.{c}".format(
            #         s=switch_name, c = repo_ctx.attr.switch_compiler
            #     ))
            #     print("cmd STDERR: %s" % result.stderr)
            #     print("cmd STDOUT: %s" % result.stdout)
            #     fail("ERROR cmd 'opam switch -y create {s} ocaml-base-compiler.{c}".format(
            #         s=switch_name, c = repo_ctx.attr.switch_compiler
            #     ))
            #     return

            # result = repo_ctx.execute(["opam", "switch", "create", switch_name, "--empty"])
            # if result.return_code == 0:
            #     repo_ctx.report_progress("SWITCH {s} created. Installing {c} (may take a while)".format(
            #         s = switch_name, c = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler
            #     ))
            # else:
            #     print("SWITCH CREATE ERROR: %s" % result.return_code)
            #     print("SWITCH CREATE STDERR: %s" % result.stderr)
            #     print("SWITCH CREATE STDOUT: %s" % result.stdout)
            #     return
            # result = repo_ctx.execute(["opam", "install", "-y", "--switch=" + switch_name,
            #                            "ocaml-base-compiler." + repo_ctx.attr.switch_compiler])
            # if result.return_code == 0:
            #     repo_ctx.report_progress("SWITCH {s}: {c} installed.".format(
            #         s = switch_name, c = "ocaml-base-compiler." + repo_ctx.attr.switch_compiler
            #     ))
            # else:
            #     print("SWITCH CREATE ERROR: %s" % result.return_code)
            #     print("SWITCH CREATE STDERR: %s" % result.stderr)
            #     print("SWITCH CREATE STDOUT: %s" % result.stdout)
            #     return
    elif result.return_code != 0:
        print("SWITCH RC: %s" % result.return_code)
        print("SWITCH STDERR: %s" % result.stderr)
        print("SWITCH STDOUT: %s" % result.stdout)
        return

