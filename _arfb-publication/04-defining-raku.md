---
title: Defining Raku
logo: /assets/images/Camelia-200px-SQUARE.png
---
When I’m writing texts like this one I always imagine a curious and vigilant
person who spots the gaps in my story, would those be intentional or not. Today
this perisher annoys me by demanding explanations on the following (a quote):

> You repeated for several times that Rakudo is not Raku itself, it’s just an
> implementation. Ok, then how do we know that the code Rakudo executes is
> actually Raku? Where can I find the precise definition of Raku?  

The problem is: it’s the darn right question to ask! Because to the surprise of
many, Raku doesn’t have a formally written textual specification. Such thing
just doesn’t exists and never existed before.

# The History Of Perl6

Unfortunately, I wasn’t there when Perl6 was born. Neither I was there when it
was designed. After all, I’m a late comer. But some pieces I read about. Of them
the most relevant to our subject are the initial design papers, named
[Apocalypses](https://raku.org/archive/doc/apocalypse.html) and
[Synopses](https://design.raku.org). They were probably the closest thing to be
ever called Perl6 Standard.

But they weren’t. In fact, some of the syntax constructs or the behaviors
proposed in the papers were never implemented or their final shape is different
from initial ideas. This is normal as the life brings corrections to our
expectations. But imagine the corrections are to be made formally; imagine the
amount of work needed to find all related places in the papers, correct them
accordingly, make sure that the correction does fully conform with the final
implementation of a feature or a construct – and it is a two-way road! All of
this is to be done by a handful of volunteers with their daytime jobs,
families, and possibly other duties!

Besides, any textual standard would suffer from fuzziness of a human language.
It’s been long time since I last programmed in C++, but I still remember the
“fun” of making code compatible with a couple of different brands of compilers,
each claiming to be 100% following the specification!

In Raku we use another way. We have

# Roast

It is a [test suite](https://github.com/Raku/roast). And it defines what Raku
language is. Any compiler passing tests in Roast is considered to be
implementing Raku or a subset of it if failing some tests.

Let me be a bit emotional here, but I consider the idea to be a fantastic one!
By not being a multi-language expert nor a historian of the programming, I can
easily miss another case like Roast. But to the best of my knowledge no other
language took this path.

The advantages of using a test suite as the language specification lies in part
in the ease of maintaining it. Instead of codifying a standard in a textual
form, and letting a compiler developers to deal with it, and discussing what
interpretation of the spec is correct, we simply add a test and say: if a
compiler passes it then it implements the particular spec.

_And it is never too much to remind that I simplify things here by skipping some
irrelevant details which may obscure the main point._

Of course, use of Roast is not only about joy. The two problems I can think of
right away are:

- the structure of the test suite
- ease of finding necessary information

The first one lies in the fact that Roast directory structure is based upon
synopses, mentioned above. The first few lines of `ls` output in the suite root
dir have this look:

```
S01-perl-5-integration/
S02-lexical-conventions/
S02-lists/
S02-literals/
S02-magicals/
S02-names/
S02-names-vars/
S02-one-pass-parsing/
S02-packages/
S02-types/
S03-binding/
S03-buf/
S03-feeds/
```

Really, it’s not something very intuitive unless you know the backstory. I don’t
consider the problem a big one as it’s rather easily fixable with sufficient
amount of spare time on someone’s hands... Oh, wait, what spare time? Anyhow,
it’s still a minor issue.

The nature of the other problem is intrinsic to the approach itself. Whichever
classification we’d choose for grouping tests, many of them are hard to fit into
a single category. Thus finding the right one might sometimes turn into a little
quest of combining one’s intuition with `grep` output.

Luckily, alongside with Roast, Raku has brilliant and ever evolving
[documentation](https://docs.raku.org) project which is able to cover most of
one’s needs in looking for information about Raku syntax and core API.

Speaking of myself, when it comes to choosing between unambiguity of the
specification and its searchability – the first wins univocally!

# The Core

In a previous article I mentioned that the compiler in Raku is responsible for
syntax. By then I was talking about OO and Metamodel. But the statement could
pretty much be extended to everything in the language _(still, remember about
simplifications!)_. Yet, syntax alone makes like... er... well... not the
biggest part of Raku specs. By browsing Roast one would quickly realize that
most of it is about testing core classes and their interfaces. Sometimes what
looks like a syntax test implies testing of a core class at the same time! For
example, if we write something like:

```
my @a = 1..42;
is @a.elems, 42, “Array initialized from a Seq”;
```

then we test all the syntax constructs of declaring a symbol, defining a
sequence, and assignment; and the same time we test `Array` and `Seq` classes
under the hood. Oh, and `Array` is not even that much “under” as we implicitly
invoke `.elems` method! By replacing the method invocation with `+@a` we turn
the test in fully-implicit one.

Lets sum up what we know so far. The compiler does the syntax. The metamodel
does the type system. What does the classes? To answer this question _(yes, my
boring imaginary friend!)_ I need to step back a bit and get into some technical
details.

As I expect the reader to know about scoping, I’d start from this simple snippet
of a little Raku program:

```
use v6;
say “Who cares?”;
```

The code itself is not relevant, ignore it. It’s the scope which we care about.
The initial intention of a beginner is to consider the program scope to be the
topmost one. Yes, “oops” applies here!  But before I explain the "oops", let me
show you a Raku's feature used in some code examples below:

```
my $foo;
{
    my $bar;
    say MY::.keys;
    say OUTER::.keys;
}
```

`MY` and `OUTER` here are pseudo-packages. We call them _pseudo_ because they do
not represent a real package but point at the current lexical scope and the
outer one. `::` postfix gives us a `Hash`-like object containing symbol table of
the package it is applied to. Because it's a hash `keys` method will return all
symbol names from the table (see [Hash
documentation](https://docs.raku.org/type/Hash)).

Now, as I hopefully made the basics clearer, here is what the output of the
example looks like:

> ```  
($*DISPATCHER $bar $_)  
($*DISPATCHER $_ $foo)  
```  

Never mind `$*DISPATCHER` and `$_`, they're pre-installed by the compiler and
are out of the scope of this article.

Last thing to mention about Raku syntax before we get back to the point of this
section is that `::` allows to reference symbols in packages using fully
qualified names. In our example we can gain access to `$foo` using fully
qualified name notation: `$OUTER::foo`. Though this particular line make not
much sense in the context of my example since `$foo` is visible inside the block anyway, but it makes
a lot more sense in many other cases. One of them you'll see later in this article.
Another one lets us introspect the outer of our outer with `OUTER::OUTER`
notation. Correspondigly `OUTER::OUTER::` would return the
symbol table of the scope two steps away from the current one!

We're now ready for a discovery! Let's find out what's the above mentioned
"oops" is all about. For this we start with  a one-liner: `use v6.d; say
OUTER::OUTER::.keys`. It can be tried directly from your shell command line:

```
$ raku -e 'use v6.d; say OUTER::OUTER::.keys'
(&infix:«(<+)» &infix:<≽> CORE-SETTING-REV &await $=pod $¢ $_ $/ $! &infix:<≼> &infix:«(>+)»)
```

Add one extra pair of `OUTER::OUTER::`: `use v6.d; say
OUTER::OUTER::OUTER::OUTER::.keys` - to see even longer list of symbols! Raku
would even have to truncate the list for you for make it more appealing.

Among the symbols printed you may find some already familiar ones like `Int`,
`Str`, `mkdir`, `shift`, etc., etc.  

More precision could now be added to Raku definition: it is a syntax with a
library providing the core API. For the latter single word _core_ is often used.
Evidently, the symbols we've discovered are part of the core. 

I'm sure by this moment any beginner would still have more questions than
anwers. That's because we still need more pieces of the puzzle. So, let's move
on to the next one.

# Setting

_This section is somewhat of a digression from the main line. But it is
necessary for understanding the later parts of this article._

Roughly speaking, a _setting_ is a lexical context in which a script or a module
is wrapped. The setting provides default symbols available to user code but
installed by some external means, not by the code itself.

The following pseudo-code schematically demoes what's said above:

```
{ # Setting
    ...
    class Int { ... }
    class Str { ... }
    ...
    sub say(...) { ... }
    sub print(...) { ... }
    ...
    { # User code
        use v6;
        my Int $foo = 42;
        print $foo, ": ";
        say "Report to my setting! ";
    }
}
```

It is now time to introduce one more term extensively used in Raku: _compunit_
which is short of _compilation unit_. In the pseudo-code above compunit is the
_User code_ section. Similarly, the following being put in a `.rakumod` module
file would be considered a compunit too:

```
unit module Foo;
...
```

For our purpose it is sufficient to state that any file of Raku code is a
compunit, would it be a script or a module.

_Note:_ In the previous section I used pairs of `OUTER::` to reach the setting
symbol teable. This is because Rakudo installs an additional empty lexical scope
between a compunit and its setting. The purpose of the scope is technical and
not relevant to our subject. The pseudo-code example above doesn't reflect this
fact.

It would also worth noting that a setting is not necessarily about what compiler
installs for you by default. For example, theoretically Rakudo allows use of a
custom made setting (which could be pre-compiled by the user). For example,
Rakudo distribution contains _RESTRICTED_ setting which is installed under
`<your_Rakudo_path>/share/perl6/runtime/RESTRICTED.setting.<backend_extension>`.
It's source is very simple and easy to grok and can be found in
`src/RESTRICTED.setting` under Rakudo sources root. The purpose of it is to
restrict certain unsafe features like socket and file handles, filesystem
manipulations, external processes.

Unfortunately, while writing this section I realized that the support of custom
setting is currently broken in Rakudo. Though I have a guess as to how to get it
fixed.

Anyway, I have one more subject on my hands to cover:

# Language Version

As it is mentioned in
[Introduction](https://vrurg.github.io/arfb-publication/01-introduction/),
Rakudo is not the Raku. It is as bothersome on this as I am myself. Every time
when asked for the version it tells you that:

```
This is Rakudo version 2020.06 built on MoarVM version 2020.06
implementing Raku 6.d.
```

This section I devote not to `2020.06` in the first line of output but to `6.d`
in the second line. To much of a surprise to many, it's only the second version
of Raku as the first one is actually `6.c` and it is the version Perl6 got when
was proclaimed released in 2015.

From the very beginning Raku was designed with backward compatibility in mind.
First it was about maintaining Perl6 compatibility with Perl5. Then it gradually
evolved into ways of being backward compatible to older Raku code while allowing
breaking changes on major version transitions.

Generally speaking, the problem of being backcompat to previous versions doesn't
have an ideal solution. One way or another, it is often a matter of choosing
plain bad tradeoffs out of a set horrible ones. But when chosen, the rules are
to be spoken out load, clear, and be followed with no exceptions. This is where
Raku does do the right thing. The rules I currently want to focus upon are:

1. A compunit must be able to proclaim the language version it is willing to be
   compiled with.
2. The version is persistent throughout the compunit.
3. A compiler is not introducing intended regressions into support of an older
   language version.

I did use version declaration previously in an example above:

```
use v6.d;
```

This explicitly tells the compiler that the compunit following the pragma is
expected to be ran against Rakudo version `6.d`. More practical example

```
use v6.c;
unit module Only6c;
``` 

have the meaning of module `Only6c` to unlikely be compatible with any other
Raku version. But this doesn't pose a risk of being incompatible with a script
running under `6.d` due to the second rule: the script's compunit will have its
`6.d` while the module it imports will have its `6.c`:

```
use v6.d;
use Only6c;
Only6c::foo(42); # No problem!
```

The only problem possible with this approach is when a Raku version is
considered too old and voted to be dropped out of compiler's support. But this
kind of situation is not expected to happen in any near future. And even then
the solution will depend on factors we don't know yet about.

# The Core Settings

Phew, it's a long way we've made so far! But it's getting close to the finish
eventually! Time for the last three sections to finally join together to form a
new abstraction.

In a way, we're getting back into the end of _The Core_ section. But this time
we already know about Raku settings and versions. Now, when I say that
`OUTER::OUTER::` in the example points at the _core setting_ it would make much
more sense. Besides, the example includes `use v6.d` pragma which allows me to
say that this is the core setting of Raku v6.d! With the next pair of
`OUTER::OUTER::` we get a symbol table of v6.c core setting. And then there is
nothing beyond this point.

Using the pseudo-code approach used in _Setting_ section, we can depict the
relations between a compunit code and the core settings like this:

```
{ # v6.c core
    ...
    { # v6.d core
        ...
        { # compunit
            ...
        }
    }
}
```

If the compunit is declared to be v6.c only, then the picture would lack v6.d
core scope:

```
{ # v6.c core
    ...
    { # compunit
        ...
    }
}
```

From Rakudo implementation point of view the situation looks like this:

1. When Rakudo is built:
    1. Cores are being compiled as a part of Rakudo. Each core is given
       `CORE.<rev>` alias where `<rev>` is a language revision: _c_, or _b_, or
       _e_.
	2. `CORE.c` is compiled as having no setting.
	3. `CORE.d` is compiled with `CORE.c` as its setting.
    4. `CORE.e` is compiled with `CORE.d` as its setting.
      
       The last two items is how core settings form the lexical nesting.
2. At user code compile time:
	1. Compiler determines compunit's  language version.
    2. A core implementing the required version is set as the compunit setting.

Remember `OUTER::OUTER::` pointing at _v6.d_ core setting scope resulted in much
shorter list of symbols than the one pointing at _v6.c_ scope? Doesn't it make
sense now? Because _6.d_ is mostly compatible with its predecessor it is only
requires to override a couple of symbols to implement specification of _6.d_! It
can be illustrated with an example:

```
{ # kind of CORE.c
    sub foo { say "foo.c" };
    sub bar { say "bar.c" }
    foo;
    bar;
    { # kind of CORE.d
        sub foo { say "foo.d" };
        { # kind of compunit
            foo;
            bar;
        }
    }
}
```

The first outer scope of our "compunit" simulates the way `CORE.d` redefines
some of the symbols provided by `CORE.c`.

Routines are not the only entities which could be overridden. Any symbol defined
in a later version core overrides what's defined in earlier versions. Apparently
this stems from the rules of lexical scoping. For example, classes are
registered as symbols and consequently are not exception of the overriding rule!
In the upcoming Raku v6.e we're going to see new versions of `Grammar` and
`PseudoStash` classes.

_This is perhaps the time to recall [Everything Is An Object.
MOP.](/arfb-publication/02-everything-is-an-object-mop) article in its part on
type objects. The situation described above is a good demo that in Raku it's not
the name which defines a class but the type object the name refers to in a given
scope._

## Namespaces

So far I was referencing core symbol tables either via `OUTER` pseudo-package
definition, or just by using build-time aliases `CORE.<rev>`. But in Raku a core
can be referenced directly using `CORE` pseudo-package. `say CORE::.keys`
statement would come up with output very similar to what we saw with `OUTER`
above. Except that where `OUTER` gives exactly one lexical scope, `CORE`
flattens down all symbol tables of all core scopes available to the compunit. If
for a reason one needs direct access to a particular core setting then in _6.e_
it is will be provided with specific `CORE::v6<rev>` sub-packages; i.e. _6.d_
core symbols are represented by `CORE::v6d` package.

Here is when such kind of access is useful. As I noted earlier, `Grammar`
classes of Raku _6.c_ and Raku _6.e_ are different. It means that if we declare
a module as a _6.e_ code:

```
use v6.e.PREVIEW;
unit module Foo;
sub is-grammar($g) is export {
    $g === Grammar ?? "grammar" !! "no idea";
}
```

And a script written in _6.c_ tries using the function from `Foo`:

```
use v6.c;
use Foo;
say is-grammar(Grammar.new);
```

the output will be _"no idea"_! Which must be of no surprise for you now.

_Tip:_ Try `use v6.e.PREVIEW; say Grammar.^language-revision; say
Int.^language-revision;` one-liner if curious.

But what if we must handle both versions of `Grammar`? This is where the
versionized namespaces come to rescue:

```
sub is-grammar($g) is export {
    $g === CORE::v6c::Grammar || $g === CORE::v6e::Grammar 
        ?? "grammar" 
        !! "no idea";
}
```

# Versions And Roast, And The End

I apologize for the longevity of this writing. But the subjects I cover here are
so much bound together that it's hard to separate one from another. But I
promise you this to be the end of the story!

The perisher from the article beginning is already having at least one more
question: how language versions are specced? This brings us back to the roast.
Or, more precisely, to its repository.
[Raku/roast](https://github.com/raku/roast) contains few branches of the
interest for us:

- `master` which defines currently developed Raku _6.e_
- `6.c-errata`
- `6.d-errata`

The latter two are considered semi-immutable branches and nothing but bug fixes
are allowed into them. For a compiler to claim to be implementing a Raku
language version it is mandatory to pass the corresponding branch. For example,
no Rakudo release is made without a run against both `-errata` branches to
ensure no regression is introduced and any code with `use v6.c` or `use v6.d`
pragma will continue to run on the newly released compiler.

Besides, the `master` branch also has many tests for explicit language
versioning and for interaction of cross-version code. This ensures that code
written long ago and perhaps even barely maintained would still be of use for
projects written with newer Raku versions.

With all written in mind, my own definition of Raku is: _it is syntax
accompanied with a core library satisfying the roast test suite_. If a compiler
conforms to the definition then we say _it implements Raku_. Thus the code
compiled by it without errors is written in Raku.
