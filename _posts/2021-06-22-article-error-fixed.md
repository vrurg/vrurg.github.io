---
title: An Error In The Roles Article
tags: Raku publication article role roles error
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
The recently published
[article](/arfb-publication/07-roles-or-when-one-is-many) contained a
factual error, as was pointed out by Elizabeth Mattijsen. I stated that named
arguments do not work in role parameterization but it is not true. Yet, what I
was certain about is that there is clearly something wrong about them. It took a
bit of my time and wandering around Rakudo sources to recover my memories.  The
actual problem about named parameters is less evident and I dedicated [a
section of the
article](/arfb-publication/07-roles-or-when-one-is-many/#a-bit-of-cold-shower)
to explain what is actually going on.

In this post I will share more detailed explanation of what's going on for those
interested in it. If anybody wish to follow me by watching the code open the
_src/Perl6/Metamodel/ParametricRoleGroupHOW.nqp_ file in Rakudo sources. There
we start with method `parameterize`. Remember in the meanwhile, that the code is
NQP meaning it looks like Raku but it lacks many features of it.

At the end of the method we find `nqp::parameterizetype` op. It is described in
[nqp ops
docs](https://github.com/Raku/nqp/blob/master/docs/ops.markdown#-parametric-extensions).
What we must pay attention to is the second parameter of the op which is named
as `parameter_array`. This means one simple thing: the op is only able to
recognize positional parameters.

In the documentation we also find out that for a given set of parameters the op
will return the same type parameterization. Apparently, this is how we make sure
that `R[Int, "ok"]` will remain the same role currying everywhere.

But what happens when named parameters are involved? To make it possible to
dispatch over them `ParametricRoleGroupHOW` does a trick: it takes the slurpy
hash of nameds and uses it as a single positional argument which is appended to
the end of `@args` array of positionals. To be consistent, if there are no nameds
are passed in, `NO_NAMEDS` constant is pushed instead. It is long in text, but
short in the code:

```
nqp::push(@args, %named_args || NO_NAMEDS);
```

Let's say, we parameterize over `R[Int, Str]`. The `@args` array will be
something like:

```
[Int, Str, NO_NAMEDS]
```

No matter how many times we meet `R[Int, Str]` in Raku code, the `@args` array
will remain consistent allowing `nqp::parameterize` to produce a consistent
result.

But as soon as `R[Int, Str, :$foo]` is used the array will look like:

```
[Int, Str, %named_args]
```

where `%named_args` is a slurpy parameter of the `parameterize` method:

```
method parameterize($obj, *@args, *%named_args) {
```

Each time the method is invoked it will be a different hash object, even if the
same named arguments are used! This will effectively make it look like a
different set of arguments for the parameterization code. Evidently, a different
parametrization will be produced too.

It is theoretically possible for the metamodel code to analyze the hash of
nameds, and keep track of them, and re-use a hash if same set of arguments was
previously used... But as I mentioned this in the article, the new dispatching
should be able to handle things in a better and more performant way.
