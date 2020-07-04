<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#ppx_archive"></a>

## ppx_archive

<pre>
ppx_archive(<a href="#ppx_archive-name">name</a>, <a href="#ppx_archive-archive_name">archive_name</a>, <a href="#ppx_archive-compile_strict_sequence">compile_strict_sequence</a>, <a href="#ppx_archive-debug">debug</a>, <a href="#ppx_archive-deps">deps</a>, <a href="#ppx_archive-dump_ast">dump_ast</a>, <a href="#ppx_archive-flags">flags</a>, <a href="#ppx_archive-keep_locs">keep_locs</a>,
            <a href="#ppx_archive-link_strict_sequence">link_strict_sequence</a>, <a href="#ppx_archive-linkall">linkall</a>, <a href="#ppx_archive-linkopts">linkopts</a>, <a href="#ppx_archive-mode">mode</a>, <a href="#ppx_archive-msg">msg</a>, <a href="#ppx_archive-no_alias_deps">no_alias_deps</a>, <a href="#ppx_archive-opaque">opaque</a>, <a href="#ppx_archive-opts">opts</a>,
            <a href="#ppx_archive-preprocessor">preprocessor</a>, <a href="#ppx_archive-short_paths">short_paths</a>, <a href="#ppx_archive-srcs">srcs</a>, <a href="#ppx_archive-strict_formats">strict_formats</a>, <a href="#ppx_archive-strict_sequence">strict_sequence</a>, <a href="#ppx_archive-warnings">warnings</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| archive_name |  -   | String | optional | "" |
| compile_strict_sequence |  -   | Boolean | optional | True |
| debug |  -   | Boolean | optional | True |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| dump_ast |  -   | Boolean | optional | True |
| flags |  -   | List of strings | optional | ["-strict-sequence", "-strict-formats", "-short-paths", "-keep-locs", "-g", "-no-alias-deps", "-opaque"] |
| keep_locs |  -   | Boolean | optional | True |
| link_strict_sequence |  -   | Boolean | optional | True |
| linkall |  -   | Boolean | optional | False |
| linkopts |  -   | List of strings | optional | [] |
| mode |  -   | String | optional | "native" |
| msg |  -   | String | optional | "" |
| no_alias_deps |  -   | Boolean | optional | True |
| opaque |  -   | Boolean | optional | True |
| opts |  -   | List of strings | optional | [] |
| preprocessor |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| short_paths |  -   | Boolean | optional | True |
| srcs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| strict_formats |  -   | Boolean | optional | True |
| strict_sequence |  -   | Boolean | optional | True |
| warnings |  -   | String | optional | "@1..3@5..28@30..39@43@46..47@49..57@61..62-40" |


<a name="#ppx_binary"></a>

## ppx_binary

<pre>
ppx_binary(<a href="#ppx_binary-name">name</a>, <a href="#ppx_binary-deps">deps</a>, <a href="#ppx_binary-linkall">linkall</a>, <a href="#ppx_binary-linkopts">linkopts</a>, <a href="#ppx_binary-message">message</a>, <a href="#ppx_binary-mode">mode</a>, <a href="#ppx_binary-opts">opts</a>, <a href="#ppx_binary-ppx">ppx</a>, <a href="#ppx_binary-srcs">srcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| linkall |  -   | Boolean | optional | True |
| linkopts |  -   | List of strings | optional | [] |
| message |  -   | String | optional | "" |
| mode |  -   | String | optional | "native" |
| opts |  -   | List of strings | optional | [] |
| ppx |  PPX binary (executable).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| srcs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a name="#ppx_library"></a>

## ppx_library

<pre>
ppx_library(<a href="#ppx_library-name">name</a>, <a href="#ppx_library-compile_strict_sequence">compile_strict_sequence</a>, <a href="#ppx_library-debug">debug</a>, <a href="#ppx_library-deps">deps</a>, <a href="#ppx_library-dump_ast">dump_ast</a>, <a href="#ppx_library-keep_locs">keep_locs</a>, <a href="#ppx_library-link_strict_sequence">link_strict_sequence</a>,
            <a href="#ppx_library-linkopts">linkopts</a>, <a href="#ppx_library-mode">mode</a>, <a href="#ppx_library-msg">msg</a>, <a href="#ppx_library-no_alias_deps">no_alias_deps</a>, <a href="#ppx_library-opaque">opaque</a>, <a href="#ppx_library-opts">opts</a>, <a href="#ppx_library-preprocessor">preprocessor</a>, <a href="#ppx_library-short_paths">short_paths</a>, <a href="#ppx_library-srcs">srcs</a>,
            <a href="#ppx_library-strict_formats">strict_formats</a>, <a href="#ppx_library-strict_sequence">strict_sequence</a>, <a href="#ppx_library-warnings">warnings</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| compile_strict_sequence |  -   | Boolean | optional | True |
| debug |  -   | Boolean | optional | True |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| dump_ast |  -   | Boolean | optional | True |
| keep_locs |  -   | Boolean | optional | True |
| link_strict_sequence |  -   | Boolean | optional | True |
| linkopts |  -   | List of strings | optional | [] |
| mode |  -   | String | optional | "native" |
| msg |  -   | String | optional | "" |
| no_alias_deps |  -   | Boolean | optional | True |
| opaque |  -   | Boolean | optional | True |
| opts |  -   | List of strings | optional | [] |
| preprocessor |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| short_paths |  -   | Boolean | optional | True |
| srcs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| strict_formats |  -   | Boolean | optional | True |
| strict_sequence |  -   | Boolean | optional | True |
| warnings |  -   | String | optional | "@1..3@5..28@30..39@43@46..47@49..57@61..62-40" |


<a name="#ppx_module"></a>

## ppx_module

<pre>
ppx_module(<a href="#ppx_module-name">name</a>, <a href="#ppx_module-args">args</a>, <a href="#ppx_module-data">data</a>, <a href="#ppx_module-deps">deps</a>, <a href="#ppx_module-doc">doc</a>, <a href="#ppx_module-impl">impl</a>, <a href="#ppx_module-intf">intf</a>, <a href="#ppx_module-linkall">linkall</a>, <a href="#ppx_module-linkopts">linkopts</a>, <a href="#ppx_module-mode">mode</a>, <a href="#ppx_module-module_name">module_name</a>, <a href="#ppx_module-msg">msg</a>, <a href="#ppx_module-ns">ns</a>,
           <a href="#ppx_module-opts">opts</a>, <a href="#ppx_module-ppx">ppx</a>, <a href="#ppx_module-warnings">warnings</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| args |  PPX cmd args.   | List of strings | optional | [] |
| data |  PPX data deps, e.g. headers   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| doc |  Docstring   | String | optional | "" |
| impl |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| intf |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| linkall |  -   | Boolean | optional | True |
| linkopts |  -   | List of strings | optional | [] |
| mode |  -   | String | optional | "native" |
| module_name |  Allows user to specify a module name different than the target name.   | String | optional | "" |
| msg |  -   | String | optional | "" |
| ns |  Namespace string; will be used as module name prefix.   | String | optional | "" |
| opts |  -   | List of strings | optional | [] |
| ppx |  PPX binary (executable).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| warnings |  -   | String | optional | "@1..3@5..28@30..39@43@46..47@49..57@61..62-40" |


<a name="#ppx_test"></a>

## ppx_test

<pre>
ppx_test(<a href="#ppx_test-name">name</a>, <a href="#ppx_test-deps">deps</a>, <a href="#ppx_test-message">message</a>, <a href="#ppx_test-mode">mode</a>, <a href="#ppx_test-ppx">ppx</a>, <a href="#ppx_test-srcs">srcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| message |  -   | String | optional | "" |
| mode |  -   | String | optional | "native" |
| ppx |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| srcs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


