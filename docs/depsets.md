# bazel depsets

Are an incredible PITA.  Very poorly documented.

What I think I have discovered:

Constructor: there are some legacy parameters, going forward there are three: direct, transitive, and order.

Ignoring order for the moment.  The [docs](https://docs.bazel.build/versions/master/skylark/lib/globals.html#depset) say this:

direct	- A list of direct elements of a depset.
transitive	- sequence of depsets.  A list of depsets whose elements will become indirect elements of the depset.

But it doesn't always work that way.  Example:

opam_directs     = [depset([Label("@opam//pkg:eqaf")])]
opam_transitives = [depset([Label("@opam//pkg:eqaf")])]

Looks like a list of depsets to me. But no. Try to assign:

  opam_depset = depset(
    direct     = opam_directs,
    transitive = opam_transitives
  )

Result: "cannot add an item of type 'Label' to a depset of 'depset'" - this is referring to the transitive bit.

Try:      transitive = [opam_transitives]
Result: expected type 'depset' for 'transitive' element but got type 'list' instead

Howsabout:      transitive = opam_transitives[0]
Result: in call to depset(), parameter 'transitive' got value of type 'depset', want 'sequence of depsets or NoneType'

Let's try:      transitive = depset(opam_transitives)
Nope:  in call to depset(), parameter 'transitive' got value of type 'depset', want 'sequence of depsets or NoneType'

Sheesh.          transitive = [depset(opam_transitives)]
Yay! That works.  But look at what it is, using print:

    [depset([depset([Label("@opam//pkg:eqaf")])])]

That is, a sequence of depsets of a sequence of depsets of a sequence
of Labels. That's what the syntax suggust to me, at least.

This works too:  [depset(depset())]
Which prints as: [depset([])]

In fact, you can nest depsets as deep as you want:

[depset(depset(depset(depset())))]  =>  [depset([])]

 [depset(depset(depset(depset(depset("foo")))))] => cannot union value of type 'string' to a depset

Another obscure error message, thanks.

[depset(depset(depset(depset(depset(Label("//foo/bar:baz"))))))] => same, cannot "union" label to depset

Let's start over. This worked:  [depset([depset([Label("@opam//pkg:eqaf")])])]

Look at the brackets.

crash:  depset(depset(depset(depset(depset(Label("//foo/bar:baz"))))))
ok:     [depset([depset([depset([depset([depset([Label("//foo/bar:baz")])])])])])]

Compare:

    [depset([depset([depset([depset([depset()])])])])] => prints to same string

    [depset(depset(depset(depset(depset()))))] => prints to [depset([])]


  opam_depset = depset(
    direct     = [depset([depset([Label("//alpha/beta:foo")])])],
    transitive = [depset([depset([Label("//alpha/beta:bar")])])]
  )

prints as:

depset([depset([Label("@obazl_rules_ocaml//alpha/beta:bar")]), depset([depset([Label("@obazl_rules_ocaml//alpha/beta:foo")])])])

with to_list():

[depset([Label("@obazl_rules_ocaml//alpha/beta:bar")]), depset([depset([Label("@obazl_rules_ocaml//alpha/beta:foo")])])]

Note that one depset level has been removed from the transitive one, beta:bar.

This works:

  opam_depset = depset(
    direct     = [depset([Label("//alpha/beta:foo")])],
    ### transitive = [depset([Label("//alpha/beta:bar")])]
  )

So does this:

  opam_depset = depset(
    ###direct     = [depset([Label("//alpha/beta:foo")])],
    transitive = [depset([Label("//alpha/beta:bar")])]
  )

But this breaks with "cannot add an item of type 'Label' to a depset of 'depset'"

  opam_depset = depset(
    direct     = [depset([Label("//alpha/beta:foo")])],
    transitive = [depset([Label("//alpha/beta:bar")])]
  )

Adding another depset level to the transitive attrib works, but not the direct one:

OK:

  opam_depset = depset(
    direct     = [depset([Label("//alpha/beta:foo")])],
    transitive = [depset([depset([Label("//alpha/beta:bar")])])]
  )

Nope:

  opam_depset = depset(
    direct     = [depset([depset([Label("//alpha/beta:foo")])])],
    transitive = [depset([Label("//alpha/beta:bar")])]
  )

cannot add an item of type 'Label' to a depset of 'depset'

You can add other data types to a depset.  A list of strings:

[depset(depset(depset(depset(depset(["foo", "bar"])))))] => prints to  [depset(["foo", "bar"])]

But a single string won't work: "cannot union value of type 'string' to a depset".

Ditto for numbers: a list of ints works, but not a single int.

Depsets can contain structs.
