#############################
def _bazelize_repo(repo_ctx):

    repo_ctx.file(
        "WORKSPACE.bazel",
        content = "\n".join([
            "##  GENERATED FILE - DO NOT EDIT",
            "workspace( name = \"{ws}\" )".format( ws = repo_ctx.name )
        ])
    )

    root_build_file = repo_ctx.path("BUILD.bazel")
    if not root_build_file.exists:
        root_build_file = repo_ctx.path("BUILD")
        if not root_build_file.exists:
            repo_ctx.file(
                "BUILD.bazel",
                content = "## GENERATED FILE - DO NOT REMOVE"
            )

    ## run 'obazl' helper pgm to generate BUILD.bazel files
    # xr = repo_ctx.execute(["obazl", "--bazelize", "--repo", repo_ctx.name, "-o", "."])

###############################
def impl_ocaml_repository(repo_ctx):

    debug = True
    # if (ctx.label.name == "zexe_backend_common"):
    #     debug = True

    if debug:
        print("OCAML_REPOSITORY TARGET: %s" % repo_ctx.name)
        print("urls: %s" % repo_ctx.attr.urls)

    if repo_ctx.attr.url:
        if repo_ctx.attr.urls:
            fail("Only one of url and urls allowed.")
        _url = repo_ctx.attr.url
    else:
        if repo_ctx.attr.url:
            fail("Only one of url and urls allowed.")
        _url = repo_ctx.attr.urls[0]

    ## FIXME: iterate over urls list

    rc = repo_ctx.download_and_extract(
        url         = _url,
        sha256      = repo_ctx.attr.sha256,
        stripPrefix = repo_ctx.attr.strip_prefix,
        allow_fail  = False
    )
    print("download_and_extract rc: %s" % rc)
    if not rc.success:
        fail("download_and_extract failed with rc: {rc} for {url}".format(
            rc = rc.success, url = _url)
             )
    else:
        print("downloaded and extracted %s" % _url)

    root_ws_file = repo_ctx.path("WORKSPACE.bazel")
    if not root_ws_file.exists:
        root_ws_file = repo_ctx.path("WORKSPACE")
        if not root_ws_file.exists:
            _bazelize_repo(repo_ctx)

#####################
ocaml_repository = repository_rule(
    implementation = impl_ocaml_repository,
    doc = """Creates a repository containing a Coq library""",
    attrs = dict(
        # rule_options,
        sha256 = attr.string(
            doc = """String; optional

Same as http_repository sha256 attribute.
            """,
        ),

        strip_prefix = attr.string(
            doc = """String; optional

Same as http_repository strip_prefix attribute.
            """,
        ),

        url  = attr.string(
            doc = """String; optional

Same as http_repository url attribute.

WARNING: if you have successfully downloaded once, and then you change the URL (say, to bump the version), you must also change (or remove) the sha256! Bazel caching is based on file content (sha256), not URL. Try just removing the sha256 first, Bazel will then tell you the actual sha256 needed.
            """,
        ),

        urls = attr.string_list(
            doc = """List of strings; optional

Same as http_repository urls attribute.

WARNING: if you have successfully downloaded once, and then you change the URL (say, to bump the version), you must also change (or remove) the sha256! Bazel caching is based on file content (sha256), not URL. Try just removing the sha256 first, Bazel will then tell you the actual sha256 needed.
            """,
        ),

        workspace_file = attr.label(
            doc = """Label; optional

Same as http_repository workspace_file attribute.
            """,
        ),

        _rule = attr.string( default = "ocaml_repository" ),
    ),
)
