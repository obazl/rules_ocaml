CoqLibraryProvider = provider(
    doc = "Provides collection of coq_sublibrary",
    fields = {
    }
)

CoqSublibraryProvider = provider(
    doc = "Provides *.vo outputs",
    fields = {
        "plugins": "Depset of coq_sublibrary modules",
        "vo": "Compiled from .v module",
        "vio": "Compiled from .v module",
        "vos": "Compiled from .v module",
        "vok": "Compiled from .v module",
        # etc.
    },
)
