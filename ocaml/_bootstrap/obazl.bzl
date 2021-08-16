# load("@bazel_skylib//lib:paths.bzl", "paths")
# load("@bazel_skylib//lib:types.bzl", "types")

# load("//ppx/_bootstrap:ppx.bzl", "ppx_repo")

# load("//coq/_toolchains:coq_toolchains.bzl", "coq_register_toolchains")

# load("//ocaml/_toolchains:ocaml_toolchains.bzl", "ocaml_register_toolchains")

# load("//ocaml/_debug:utils.bzl", "debug_report_progress")

# load("//opam:_opam.bzl", "opam_configure")

################################################################
def _get_tools_obazl(repo_ctx):
    print("fetching tools_obazl")

    tool_path = "/Users/gar/bazel/obazl/tools_obazl"

    ## for dev:
    repo_ctx.symlink(tool_path, "./")

    #### for prod:
    # tools_obazl = "https://github.com/obazl/tools_obazl/archive/refs/heads/main.zip"

    # repo_ctx.download_and_extract(
    #     tools_obazl,
    #     "./",
    #     stripPrefix = "tools_obazl-main"
    # )

################################
def _install_obazl_templates(repo_ctx):
    repo_ctx.report_progress("installing obazl templates")

    # repo_ctx.template(
    #     "BUILD.bazel",
    #     Label(ws + "//ocaml/_templates:BUILD.ocaml"),
    #     executable = False,
    #     substitutions = {
    #         "{sdkpath}": opam_switch_prefix,
    #         "{projroot}": str(projroot)
    #     },
    # )

###############################
def _obazl_repo_impl(repo_ctx):
    repo_ctx.report_progress("Bootstrapping obazl repo")
    if repo_ctx.attr.debug:
        print("_obazl_repo_impl")

    ## we can only get env vars within a repo_ctx, so we do this here:
    # if "OPAMSWITCH" in repo_ctx.os.environ:
    #     if repo_ctx.attr.build_name:
    #         fail("ocaml_configure: $OPAMSWITCH not compatible with 'build' arg")

    _get_tools_obazl(repo_ctx);

    _install_obazl_templates(repo_ctx)

#############################
_obazl_repo = repository_rule(
    implementation = _obazl_repo_impl,
    configure = True,
    # local = True,
    environ = [
        "OBAZL_OPAM_VERIFY",
        "OPAMSWITCH",
        "CAML_LD_LIBRARY_PATH"
    ],
    attrs = dict(
        verbose = attr.bool(default = False),
        debug   = attr.bool(default = False)
    )
)


##############################
def obazl_configure(
        debug    = False,
        verbose  = False):

    """Configures obazl tools

    Args:
      verbose: verbose
      debug: enable debugging
    """
    print("obazl_configure")

    _obazl_repo(name="obazl",
                verbose = verbose,
                debug = debug)
