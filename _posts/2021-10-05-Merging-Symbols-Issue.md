---
title: Merging Symbols Issue
tags:
    - Raku
    - module
    - thoughts
toc: true
#date: 2021-05-05 23:00:00
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
_First of all, I'd like to apologize for all the errors in this post. I just
haven't got time to properly proof-read it._

A while ago I was trying to fix a problem in Rakudo which, under certain
conditions, causes some external symbols to become invisible for importing code,
even if explicit `use` statement is used. And, indeed, it is really confusing
when:

```
use L1::L2::L3::Class;
L1::L2::L3::Class.new;
```

fails with _"Class symbol doesn't exists in L1::L2::L3"_ error! It's ok if `use`
throws when there is no corresponding module. But `.new`??

## Skip This Unless You Know What A Package Is

This section is needed to understand the rest of the post. A package in Raku is
a typeobject which has a symbol table attached. The table is called _stash_
(stands for "symbol table hash") and is represented by an instance of
[Stash](https://docs.raku.org/type/Stash) class, which is, basically, is a hash
with minor tweaks. Normally each package instance has its own stash. For
example, it is possible to manually create two _different_ packages with the
same name:

```
my $p1a := Metamodel::PackageHOW.new_type(:name<P1>); 
my $p1b := Metamodel::PackageHOW.new_type(:name<P1>); 
say $p1a.WHICH, " ", $p1a.WHO.WHICH; # P1|U140722834897656 Stash|140723638807008
say $p1b.WHICH, " ", $p1b.WHO.WHICH; # P1|U140722834897800 Stash|140723638818544
```

Note that they have different stashes as well.

A package is barely used in Raku as is. Usually we deal with _packagy_ things
like modules and classes.

## Back On The Track

Back then I managed to trace the problem down to deserialization process within
`MoarVM` backend. At that point I realized that somehow it pulls in packagy
objects which are supposed to be the same thing, but they happen to be
different and have different stashes. Because `MoarVM` doesn't (and must not)
have any idea about the structure of high-level Raku objects, there is no way it
could properly handle this situation. Instead it considers one of the
conflicting stashes as "the winner" and drops the other one. Apparently, symbols
unique to the "loser" are lost then.

It took me time to find out what exactly happens. But not until a couple
of days ago I realized what is the root cause and how to get around the bug.

## Package Tree

What happens when we do something like:

```
module Foo {
    module Bar {
    }
}
```

How do we access `Bar`, speaking of the technical side of things? `Foo::Bar`
syntax basically maps into `Foo.WHO<Bar>`. In other words, `Bar` gets installed
as a symbol into `Foo` stash. We can also rewrite it with special syntax sugar:
`Foo::<Bar>` because `Foo::` is a representation for `Foo` stash.

So far, so good; but where do we find `Foo` itself? In Raku there is a special
symbol called `GLOBAL` which is the root namespace (or _a package_ if you wish)
of any code. `GLOBAL::`, or `GLOBAL.WHO` is where one finds all the top-level
symbols.

Say, we have a few packages like `L11::L21`, `L11::L22`, `L12::L21`, `L12::L22`.
Then the namespace structure would be represented by this tree:

```
GLOBAL
`- L11
   `- L21
   `- L22
`- L12
   `- L21
   `- L22
```

Normally there is one per-process `GLOBAL` symbol and it belongs to the compunit
which used to start the program. Normally it's a _.raku_ file, or a string
supplied on command line with `-e` option, etc. But each
[compunit](https://docs.raku.org/language/glossary#Compilation_unit_or_compunit)
also gets its own `GLOBALish` package which acts as compunit's `GLOBAL` until it
is fully incorporated into the main code. Say, we declare a module in file
_Foo.rakumod_:

```
unit module Foo;
sub print-GLOBAL($when) is export {
    say "$when: ", GLOBAL.WHICH, " ", GLOBALish.WHICH;
}
print-GLOBAL 'LOAD';
```

And use it in a script:

```
use Foo;
print-GLOBAL 'RUN ';
```

Then we can get an ouput like this:

```
LOAD: GLOBAL|U140694020262024 GLOBAL|U140694020262024
RUN : GLOBAL|U140694284972696 GLOBAL|U140694020262024
```

Notice that `GLOBALish` symbol remains the same object, whereas `GLOBAL` gets
different. If we add a line to the script which also prints `GLOBAL.WHICH` then
we're going to get something like:

```
MAIN: GLOBAL|U140694284972696
```

Let's get done with this part of the story for a while a move onto another
subject.

## Compunit Compilation

This is going to be a shorter story. It is not a secret that however powerful
Raku's grammars are, they need some core developer's attention to make them
really fast. In the meanwhile, compilation speed is somewhat suboptimal. It
means that if a project consist of many compunits (think of modules, for
example), it would make sense to try to compile them in parallel if possible.
Unfortunately, the compiler is not thread-safe either. To resolve this
complication Rakudo implementation parallelizes compilation by spawning
individual processes per each compunit.

For example, let's refer back to the module tree example above and imagine that
all modules are `use`d by a script. In this case there is a chance that we would
end up with six `rakudo` processes, each compiling its own `L*` module.
Apparently, things get slightly more complicated if there are cross-module
`use`s, like `L11::L21` could refer to `L21`, which, in turn, refers to
`L11::L22`, or whatever. In this case we need to use topological sort to
determine in what order the modules are to be compiled; but that's not the
point.

The point is that since each process does independent compilation, each compunit
needs independent `GLOBAL` to manage its symbols. For the time being, what we
later know as `GLOBALish` serves this duty for the compiler.

Later, when all pre-compiled modules are getting incorporated into the code
which `use`s them, symbols installed into each individual `GLOBAL` are getting
merged together to form the final namespace, available for our program. There
are even methods in the source, using `merge_global` in their names.

## [TA-TA-TAAA!](https://www.youtube.com/watch?v=pSISidBUang)

_(Note the clickable section header; I love the guy!)_

Now, you can feel the catch. Somebody might have even guessed what it is. It
crossed my mind after I was trying to implement legal symbol auto-registration
which doesn't involve using `QAST` to install a phaser. At some point I got an
idea of using `GLOBAL` to hold a register object which would keep track of
specially flagged roles. Apparently it failed due to the parallelized
compilation mentioned above. It doesn't matter, why; but at that point I started
building a mental model of what happens when merge is taking place. And one
detail drew my special attention: what happens if a package in a long name is
not explicitly declared?

Say, there is a class named `Foo::Bar::Baz` one creates as:

```
unit class Foo::Bar;
class Baz { }
```

In this case the compiler creates a stub package for `Foo`. The stub is used to
install class `Bar`. Then it all gets serialized into bytecode.

At the same time there is another module with another class:

```
unit class Foo::Bar::Fubar;
```

It is not aware of `Foo::Bar::Baz`, and the compiler has to create two stubs:
`Foo` and `Foo::Bar`. And not only two versions of `Foo` are different and have
different stashes; but so are the two versions of `Bar` where one is a real
class, the other is a stub package.

Most of the time the compiler does damn good job of merging symbols in such
cases. It took me stripping down a real-life code to golf it down to some
minimal set of modules which reproduces the situation where a `require` call
comes back with a `Failure` and a symbol becomes missing. The remaining part of
this post will be dedicated to [this
example](https://github.com/vrurg/vrurg.github.io/tree/master/examples/2021-10-05-merge-symbols).
In particular, this whole text is dedicated to [one
line](https://github.com/vrurg/vrurg.github.io/blob/14c8c9552aef62d9cc61865d26928073b1a4cfdd/examples/2021-10-05-merge-symbols/lib/L1/L2/Collection.rakumod#L10).

_Before we proceed further, I'd like to state that I might be speculating about
some aspects of the problem cause because some details are gone from my memory
and I don't have time to re-investigate them. Still, so far my theory is backed
by working workaround presented at the end._

To make it a bit easier to analyze the case, let's start with namespace tree:

```
GLOBAL
`- L1
   `- App
   `- L2
      `- Collection
         `- Driver
         `- FS
```

Rough purpose is for application to deal with some kind of collection which
stores its items with help of a driver which is loaded dynamically, depending,
say, on a user configuration. We have the only driver implemented: File System
(`FS`).

If you checkout the repository and try `raku -Ilib symbol-merge.raku` in the
_examples/2021-10-05-merge-symbols_ directory, you will see some output ending
up with a line like `Failure|140208738884744` (certainly true for up until
Rakudo v2021.09 and likely to be so for at least a couple of versions later).

The key conflict in this example are modules `Collection` and `Driver`. The full
name of `Collection` is `L1::L2::Collection`. `L1` and `L2` are both stubs.
`Driver` is `L1::L2::Collection::Driver` and because it
[imports](https://github.com/vrurg/vrurg.github.io/blob/14c8c9552aef62d9cc61865d26928073b1a4cfdd/examples/2021-10-05-merge-symbols/lib/L1/L2/Collection/Driver.rakumod#L4)
`L1::L2`, `L2` is a class; but `L1` remains to be a stub. By commenting out the
import we'd get the bug resolved and the script would end up with something
like:

```
L1::L2::Collection::FS|U140455893341088
```

This means that the driver module was successfully loaded and the driver class
symbol is available.

Ok, uncomment the import and start the script again. And then once again to get
rid of the output produced by compilation-time processes. We should see
something like this:

```
[7329] L1 in L1::L2         : L1|U140360937889112
[7329] L1 in Driver         : L1|U140361742786216
[7329] L1 in Collection     : L1|U140361742786480
[7329] L1 in App            : L1|U140361742786720
[7329] L1 in MAIN           : L1|U140361742786720
[7329] L1 in FS             : L1|U140361742788136
Failure|140360664014848
```

We already know that `L1` is a stub. Dumping object IDs also reveals that each
compunit has its own copy of `L1`, except for `App` and the script (marked as
_MAIN_). This is pretty much expected because each `L1` symbol is installed at
compile-time into per-compunit `GLOBALish`. This is where each module finds it.
`App` is different because it is directly imported by the script and was
compiled by the same compiler process, and shared its `GLOBAL` with the script.

Now comes the black magic. Open _lib/L1/L2/Collection/FS.rakumod_ and uncomment
[the last line](https://github.com/vrurg/vrurg.github.io/blob/f710d4ab59d66bf15636d59c795a34e8bc51e6b2/examples/2021-10-05-merge-symbols/lib/L1/L2/Collection/FS.rakumod#L7)
in the file. Then give it a try. The output would seem impossible at first; hell
with it, even at second glance it is still impossible:

```
[17579] Runtime Collection syms      : (Driver)
```

Remember, this line belongs to `L1::L2::Collection::FS`! How come we don't see
`FS` in `Collection` stash?? No wonder that when the package cannot see itself
others cannot see it too!

Here comes a bit of my speculation based on what I vaguely remember from the
times ~2 years ago when I was trying to resolve this bug for the first time.

When `Driver` imports `L1::L2`, `Collection` gets installed into `L2` stash, and
`Driver` is recorded in `Collection` stash. Then it all gets serialized with
`Driver` compunit.

Now, when `FS` imports `Driver` to consume the role, it gets the stash of `L2`
serialized at the previous stage. But its own `L2` is a stub under `L1` stub.
So, it gets replaced with the serialized "real thing" which doesn't have `FS`
under `Collection`! Bingo and oops...

## A Workaround

Walk through all the example files and uncomment `use L1` statement. That's it.
All compunits will now have a common anchor to which their namespaces will be
attached.

The common rule would state that if a problem of the kind occurs then make sure
there're no stub packages in the chain from `GLOBAL` down to the "missing"
symbol. In particular, commenting out `use L1::L2` in `Driver` will get our
error back because it would create a "hole" between `L1` and `Collection` and
get us back into the situation where conflicting `Collection` namespaces are
created because they're bound to different `L2` packages.

It doesn't really matter how exactly the stubs are avoided. For example, we can
easily move `use L1::L2` into `Collection` and make sure that `use L1` is still
part of `L2`. So, for simplicity a child package may import its parent; and
parent may then import its parent; and so on.

Sure, this adds to the boilerplate. But I hope the situation is temporary and
there will be a fix.

## Fix?

The one I was playing with required a compunit to serialize its own `GLOBALish`
stash at the end of the compilation in a location where it would not be at risk
of overwriting. Basically, it means cloning and storing it locally on the
compunit (the package stash is part of the low-level VM structures). Then
compunit mainline code would invoke a method on the `Stash` class which would
forcibly merge the recorded symbols back right after deserialization of
compunit's bytecode. It was seemingly working, but looked more of a kind of a
hack, than a real fix. This and a few smaller issues (like a segfault which I
failed to track down) caused it to be frozen.

As I was thinking of it lately, more proper fix must be based upon a common
`GLOBAL` shared by all compunits of a process. In this case there will be no
worry about multiple stub generated for the same package because each stub will
be shared by all compunits until, perhaps, the real package is found in one of
them.

Unfortunately, the complexity of implementing the 'single `GLOBAL`' approach is 
such that I'm unsure if anybody with appropriate skill could fit it into their
schedule.
