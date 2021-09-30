load("@bazel_skylib//lib:paths.bzl", "paths")

load("@bazel_tools//tools/build_defs/repo:utils.bzl",
     "workspace_and_buildfile")

#######################################
def impl_new_local_pkg_repository(repo_ctx):

    print("impl_new_local_pkg_repository")
    ## FIXME: get opam switch prefix and add to path

    workspace_and_buildfile(repo_ctx)

    for [build_file, linkage] in repo_ctx.attr.build_files.items():
        lst = linkage.split(" ", 2)
        # print("Linkage: {sd} <= {lnk}".format(
        #     sd = lst[0], lnk = lst[1]))
        repo_ctx.file(lst[0] + "/BUILD.bazel", repo_ctx.read(build_file))

        srcpath = repo_ctx.path(lst[1]).realpath
        dirs = srcpath.readdir()
        for file in dirs:
            [bn, ext] = paths.split_extension(file.basename)
            if ext in [".cmi", ".cmt", ".cmti",
                       ".mli", ".ml", ".c", ".h",
                       ".cmx", ".cmo",
                       ".cmxa", ".cma",
                       ".cmxs",
                       ".o", ".a", ".exe"]:
                repo_ctx.symlink(file, lst[0] + "/" + file.basename)

    srcpath = repo_ctx.path(repo_ctx.attr.path).realpath
    dirs = srcpath.readdir()
    for file in dirs:
        [bn, ext] = paths.split_extension(file.basename)
        if ext in [".cmi", ".cmt", ".cmti",
                   ".mli", ".ml", ".c", ".h",
                   ".cmx", ".cmo",
                   ".cmxa", ".cma",
                   ".cmxs",
                   ".o", ".a", ".exe",
                   ".tbl"]:
            repo_ctx.symlink(file, file.basename)

    # repo_ctx.file(subdir + "/BUILD.bazel", repo_ctx.read(build_file))
    # subpath = repo_ctx.path(subdir)
    # print("SUBPATH %s" % subpath)
    # subfiles = subpath.readdir()
    # for subfile in subfiles:
    #     print("subfile %s" % subfile)
    #     repo_ctx.symlink(subfile, "foo/" + subfile.basename)


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
            build_files = attr.label_keyed_string_dict(

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
