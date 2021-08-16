load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:types.bzl", "types")

load("//coq/_toolchains:coq_toolchains.bzl", "coq_register_toolchains")

# load("//_debug:utils.bzl", "debug_report_progress")

################################
def _install_coq_templates(repo_ctx):   #, projroot):
    repo_ctx.report_progress("installing templates")
    print("_install_coq_templates")

    ws = "@obazl_rules_coq"

    repo_ctx.template(
        "toolchains/BUILD.bazel",
        Label("//coq/_templates:BUILD.coq_sdk.toolchains"),
        executable = False,
        substitutions = {
            "{sdkpath}": "foo",
            "{projroot}": "projroot" # str(projroot)
        },
    )

    ## this just preps the subdir, later we symlink the tools into this dir
    # repo_ctx.template(
    #     "tools/BUILD.bazel",
    #     Label("//coq/_templates:BUILD.coq_sdk.tools"),
    #     executable = False,
    # )

    # # ##################
    # coq_version = repo_ctx.execute(["ocaml", "-vnum"]).stdout.strip()
    # [coq_major, sep, rest] = coq_version.partition(".")
    # [coq_minor, sep, rest] = rest.partition(".")
    # [coq_patch, sep, rest] = rest.partition(".")

    # repo_ctx.template(
    #     "version/BUILD.bazel",
    #     Label(ws + "//ocaml/_templates:BUILD.ocaml.version"),
    #     executable = False,
    #     substitutions = {
    #         "{VERSION}": coq_version,
    #         "{MAJOR}": coq_major,
    #         "{MINOR}": coq_minor,
    #         "{PATCH}":  coq_patch
    #     },
    # )

# #####################################
def _link_coq_sdk_executables(repo_ctx): ## , opam_root, opam_switch_prefix):

    ## NB: we do not need symlinks if we're using these rules directly with the SDK,
    ## we can instead just use aliases in the BUILD.bazel file

    if repo_ctx.attr.verbose:
        repo_ctx.report_progress("creating coq symlinks")

    # repo_ctx.symlink("bazel-out/darwin-fastbuild/bin/topbin/coqcc", "tools/coqc")
    # repo_ctx.symlink(opam_switch_prefix + "/lib/ctypes", "lib/ctypes/api")

# ##########################################
# def _symlink_tool(repo_ctx, prefix, tool):

#     tool_path = repo_ctx.path(prefix + "/bin/" + tool)
#     if tool_path.exists:
#         repo_ctx.symlink(tool_path, "tools/" + tool)
#     else:
#         if repo_ctx.attr.verbose:
#             print(
#                 "WARNING: could not find {tool} at {path}".format(
#                     tool = tool,
#                     path = tool_path
#                 )
#             )

# ##########################################
# def _symlink_core_tools(repo_ctx, prefix):

#     tool_path = repo_ctx.path(prefix + "/bin/" + "ocamlfind")
#     if tool_path.exists:
#         repo_ctx.symlink(tool_path, "tools/" + "ocamlfind")
#     else:
#         fail(
#                 "ERROR: could not find {tool} at {path}; please run 'opam install {tool}'.".format(
#                     tool = "ocamlfind",
#                     path = tool_path
#                 )
#             )

# ######################################################
# def _symlink_compilers(repo_ctx, opam_switch_prefix):

#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlc")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlc.byte")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlc.opt")

#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlopt")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlopt.byte")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlopt.opt")

# ########################################################
# ## FIXME: parameterize with tool names from BuildConfig file
# def _symlink_extra_tools(repo_ctx, opam_switch_prefix):

#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamllex")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamllex.byte")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamllex.opt")

#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlyacc")
#     ## evidently only one version of ocamlyacc is provided
#     # _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlyacc.byte")
#     # _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlyacc.opt")

#     ## non-core tools
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocaml")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlobjinfo")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlobjinfo.byte")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocamlobjinfo.opt")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "cppo")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "menhir")
#     _symlink_tool(repo_ctx, opam_switch_prefix, "ocaml-crunch")

###############################
def _coq_sdk_impl(repo_ctx):
    print("_coq_sdk_impl")
    repo_ctx.report_progress("Bootstrapping coq sdk repo")
    # if repo_ctx.attr.debug:

    ## we can only get env vars within a repo_ctx, so we do this here:
    # if "COQ_SDK" in repo_ctx.os.environ:

    # projroot = str(repo_ctx.path("@").dirname.dirname.dirname) + "/execroot"
    # print("PROJROOT: %s" % projroot)

    _install_coq_templates(repo_ctx) # , projroot)

    # _link_coq_sdk_executables(repo_ctx) #, opam_root, opam_switch_prefix)

#############################
_coq_sdk = repository_rule(
    implementation = _coq_sdk_impl,
    # configure = True,
    # local = True,
    # environ = [
    #     "COQ_SDK"
    # ],
    attrs = dict(
        verbose = attr.bool(default = False),
        debug   = attr.bool(default = False)
    )
)

##############################
# def configure(debug = False, opam = None): # , **kwargs):
def coq_configure(
        debug    = False,
        verbose  = False):

    """Declares workspaces (repositories) the Coq rules depend on.
        Args:
        verbose: verbose processing
        debug: enable debugging
    """

    print("coq.configure")

    # _coq_sdk(
    #     name = "coq_sdk",
    #     # verbose = verbose,
    #     # debug = debug
    # )

    coq_register_toolchains(installation="host")

    print("coq.configure done")

# See documentation for _filter_transition_label in
# ocaml/_rules/transition.bzl.
# """,
# )

# print("private/repositories.bzl loaded")
