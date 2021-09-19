OcamlArchiveProvider = provider(
    doc = """
    OCaml archive provider.

If we're building an archive, we have components and their deps; if
we're importing a pre-built archive, we will not have components, but
we may have deps, which conceptually are subdeps. """,

    fields = {
        "files": "depset",
        "archive": "same as in DefaultInfo for ocaml_archive",
        "components": "direct deps, i.e. archive components; used when archive depends on archive",
        "subdeps": "component deps.",

        ## obsolete
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
    # fields = {
    #     "archives": "Depset of archive files.",
    #     "deps": "Depset of archive deps (components) excluding the archive files themselves. To be added to depgraph but not command line."
    # }
)
