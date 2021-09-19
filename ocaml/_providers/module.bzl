OcamlModuleProvider = provider(
    doc = "OCaml module provider.",
    # fields = module_fields
    fields = {
        "sigs": "sig deps, not included in 'deps' or 'subdeps'",
        "files": "depset",
        "deps": "transitive closure of self and deps",
        "subdeps": "deps without self",

        ## obsolete:
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
)

PpxModuleProvider = provider(
    doc = "OCaml PPX module provider.",
    # fields = module_fields
    fields = {
        "files": "depset",
        "sigs": "sig deps, not included in 'deps' or 'subdeps'",
        "deps": "transitive closure of self and deps",
        "subdeps": "deps without self",

        ## obsolete:
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
)
