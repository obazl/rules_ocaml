# bootstrap opam repo within bazel

see [opam-boot](https://github.com/avsm/opam-boot)

`opam init`: " The init command initialises a local "opam root" (by
default, ~/.opam/) that holds opam's data and packages. This is a
necessary step for normal operation of opam. The initial software
repositories are fetched, and an initial 'switch' can also be
installed, according to the configuration and options. These can be
afterwards configured using opam switch and opam repository."

Note that an opam repo is a collection of small "opam" files, each
containing metadata describing dependencies and build commands. To
build a package, opam obtains from the opam file a URL from which to
download the package sources.

So it starts by fetching repo(s). That means it is dependent on some kind
of networking software on the local system (wget, git, etc.). So
that's a hermeticity issue.

However opam can be configured to use a user-supplied command for
downloading.  So we could e.g. build wget and tell opam to use that.
"OPAMFETCH specifies how to download files: either `wget', `curl' or a custom command where variables %{url}%, %{out}%, %{retry}%, %{compress}% and %{checksum}% will be replaced. Overrides the 'download-command' value from the main config file."

Another way around this would be to install a repo locally ahead of time,
and tell opam to use that.  Apparently this is not an unusual use-case.

"Defining your own repository, either locally or online, is quite
easy: you can start off by cloning the official repository if you
intend it as a replacement, or just create a new directory with a
packages sub-directory, and a repo file containing at least an
opam-version field. See the packaging guide if you need help on the
package format." (https://opam.ocaml.org/doc/Usage.html)

In principle, we could use Bazel facilities to download/configure an
opam repo within a Bazel repository (@opam-repository), then run opam
to configure an opam root and switch, also within a Bazel repo (@opam).

Commands:

* `opam switch list-available`

e.g.

```
ocaml-base-compiler                    4.12.0 Official release 4.12.0
```

## opam init

Takes two direct args, ADDRESS of a repo and NAME of the repo. The
`--root` sets the root directory for the installation.

So the user can specify a repo address. Examples:

* `opam init --root=. --bare --no-setup`
* `opam init --root=./.opam --bare --no-setup`
* `opam init --root=. --compiler=ocaml-base-compiler.4.12.0`

* `opam init ${HOME}/obazl/opam/opam-repository -k local --root=. --compiler=ocaml-base-compiler.4.12.0`

NB: init starts by fetching the repo; this can take a while.


`opam init` flags:

* `-k`, `--kind` kind of repo; 'local' for local repo.

* `--bare` "Initialise the opam state, but don't setup any compiler
  switch yet."

* `--root=.` - set opam root to current dir.  Use this for all commands?

* `-c PACKAGE`, `--compiler=PACKAGE` "Set the compiler to install
  (when creating an initial switch)"

* `--config=file`

shell stuff:

* `--no-setup` - "Do not update the user shell configuration to setup
  opam. Also implies --disable-shell-hook, unless --interactive or
  specified otherwise."

* `--disable-shell-hook`

* `--no-opamrc` "Don't read `/etc/opamrc` or `~/.opamrc`: use the
  default settings and the files specified through `--config` only"

* `--json=FILENAME` "Save the results of the opam run in a
  computer-readable file. If the filename contains the character `%',
  it will be replaced by an index that doesn't overwrite an existing
  file. Similar to setting the $OPAMJSON variable."

* `--quiet`

* `--strict` "Fail whenever an error is found in a package definition
  or a configuration file. The default is to continue silently if
  possible."

* `-y, --yes` "Answer yes to all yes/no questions without prompting.
  This is equivalent to setting $OPAMYES to "true".

env vars:

* OPAMLOGS logdir sets log directory, default is a temporary directory
  in /tmp

* OPAMROOT see option `--root`. This is automatically set by `opam env
  --root=DIR --set-root`."

Import:

`$ opam switch import FILE`

## Timings

Bare init just downloads opam-repository:

```
$ time opam init --root=. --bare --no-setup --yes
[NOTE] Will configure from built-in defaults.
Checking for available remotes: rsync and local, git.
  - you won't be able to use mercurial repositories unless you install the hg command on your system.
  - you won't be able to use darcs repositories unless you install the darcs command on your system.


<><> Fetching repository information ><><><><><><><><><><><><><><><><><><><>  🐫
[default] Initialised
opam init --root=. --bare --no-setup --yes  4.38s user 21.00s system 75% cpu 33.632 total
```

With compiler:

```
$ time opam init --root=. --no-setup --no-opamrc --compiler=ocaml-base-compiler.4.12.0 --yes
449.17s user 149.46s system 316% cpu 3:08.98 total
```

Space: 542 MB



