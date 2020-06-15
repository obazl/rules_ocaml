genrule(
    name = "{PPX}",
    visibility = ["//visibility:public"],
    message = "Preprocessing sources...",
    tools = [{TOOL}],
    srcs = ["{SRC}.mli", "{SRC}.ml"],
    outs = ["pp_{SRC}.mli", "pp_{SRC}.ml"],
    cmd = "$(location {TOOL})"
    + " --cookie 'library-name=\"LIB_NAME\"'"
    + " -dump-ast"
    + " --impl $< > \"$@\";"
    # + " $< > \"$@\";"
)
