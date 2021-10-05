load("@bazel_skylib//lib:paths.bzl", "paths")

load("@bazel_tools//tools/build_defs/repo:utils.bzl",
     "workspace_and_buildfile")

#######################################
def impl_new_local_pkg_repository(repo_ctx):

    # print("impl_new_local_pkg_repository")

    ## symlinks before build files

    ## FIXME: get opam switch prefix and add to path

    ## top-level subdir and bldfile
    srcpath = repo_ctx.path(repo_ctx.attr.path).realpath
    # print("SRCPATH: %s" % srcpath)
    # dirs = srcpath.readdir()
    cmd = ["ls", "-p", str(srcpath) + "/"]
    r = repo_ctx.execute(
        cmd,
    )
    if r.return_code == 0:
        dirlist = r.stdout.strip().splitlines()
        # print("DIRLIST %s" % dirlist)
    elif r.return_code == 1:
        print("{cmd} rc    : {rc}".format(
            cmd=cmd, rc= r.return_code))
        # print("  stdout: {stdout}".format(
        #     cmd=cmd, stdout= r.stdout))
        # print("  stderr: {stderr}".format(
        #     cmd=cmd, stderr= r.stderr))
        dirlist = []
    else:
        print("{cmd} rc    : {rc}".format(
            cmd=cmd, rc= r.return_code))
        print("  stdout: {stdout}".format(
            cmd=cmd, stdout= r.stdout))
        print("  stderr: {stderr}".format(
            cmd=cmd, stderr= r.stderr))
        fail(" cmd failure.")

    for f in dirlist:
        if (not f.endswith("/")):
            fpath = repo_ctx.path(str(srcpath) + "/" + f)

            if (fpath.basename not in [
                "BUILD.bazel", "BUILD", "WORKSPACE.bazel",  "WORKSPACE",
                "META", "opam"
            ]):
                # if repo_ctx.name == "cmdliner":
                #     print("cmdliner F: %s" % fpath.basename)

                repo_ctx.symlink(fpath, fpath.basename)

    workspace_and_buildfile(repo_ctx)

    # print("SUBPACKAGES: %s" % repo_ctx.attr.subpackages)

    if repo_ctx.attr.subpackages:
        if repo_ctx.name == "cmdliner":
            print("CMDLINER SUBPACKAGES")

    for [build_file, linkage] in repo_ctx.attr.subpackages.items():
        lst = linkage.split(" ", 2)
        # print("Linkage: {sd} <= {lnk}".format(
        #     sd = lst[0], lnk = lst[1]))
        srcpath = repo_ctx.path(lst[1]).realpath

        # print("SRCPATH: %s" % srcpath)
        cmd = ["ls", "-p", str(srcpath) + "/"]
        r = repo_ctx.execute(
            cmd,
            # working_directory = str(srcpath)
        )
        if r.return_code == 0:
            dirlist = r.stdout.strip().splitlines()
            # print("DIRLIST %s" % dirlist)
        elif r.return_code == 1:
            print("{cmd} rc    : {rc}".format(
                cmd=cmd, rc= r.return_code))
            # print("  stdout: {stdout}".format(
            #     cmd=cmd, stdout= r.stdout))
            # print("  stderr: {stderr}".format(
            #     cmd=cmd, stderr= r.stderr))
            dirlist = []
        else:
            print("{cmd} rc    : {rc}".format(
                cmd=cmd, rc= r.return_code))
            print("  stdout: {stdout}".format(
                cmd=cmd, stdout= r.stdout))
            print("  stderr: {stderr}".format(
                cmd=cmd, stderr= r.stderr))
            fail(" cmd failure.")

        # dirs = srcpath.readdir()
        for f in dirlist:
            # print("LINKING: %s" % f)

            if not f.endswith("/") and f not in ["META"]:
                fpath = repo_ctx.path(str(srcpath) + "/" + f)
                [bn, ext] = paths.split_extension(fpath.basename)
                repo_ctx.symlink(fpath, lst[0] + "/" + fpath.basename)

        repo_ctx.file(lst[0] + "/BUILD.bazel", repo_ctx.read(build_file))

###################
new_local_pkg_repository = repository_rule(
    implementation = impl_new_local_pkg_repository,
        attrs = dict(
            path = attr.string(
                doc = "Path to opam, relative to OPAM_SWITCH_PREFIX"
            ),
            build_file = attr.label(
                allow_single_file = True,
            ),
            subpackages = attr.label_keyed_string_dict(

            ),
            build_file_content = attr.string(
                doc =
                "The content for the BUILD file for this repository. " +
                "Either build_file or build_file_content can be specified, but " +
                "not both.",
            ),
            workspace_file = attr.label(
                doc =
                "The file to use as the `WORKSPACE` file for this repository. " +
                "Either `workspace_file` or `workspace_file_content` can be " +
                "specified, or neither, but not both.",
            ),
            workspace_file_content = attr.string(
                doc =
                "The content for the WORKSPACE file for this repository. " +
                "Either `workspace_file` or `workspace_file_content` can be " +
                "specified, or neither, but not both.",
            ),

        )
)
