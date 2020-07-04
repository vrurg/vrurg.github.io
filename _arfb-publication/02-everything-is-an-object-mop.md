---
title: Everything Is An Object. MOP.
tags: Raku publication
---

As this series is not typical beginner guide it is starting with a non-typical
subject.
<!--more-->

# It Is. Literally.

Raku is a multi-paradigm language meaning that one can implement functional
paradigm, or use reactive programming, or write in classical procedural style.
Yet Raku itself is implemented utilizing OO approach heavily. In practice it
means that when we say ‘everything is an object’ we literally mean it!

One could say that if everything is an object then we must be able to invoke
methods on it? Apparently, yes:

```
say “Hello world!”.WHAT; # (Str)
```

What happens in this snippet is Raku takes an object represented by the string
_”Hello world!”_ and invokes method `WHAT` on this object. Pretty much no
surprise here, I hope. Same thing happens to any other data in Raku. For
example, `(1,2,3).join(“,”)` is nothing else but invocation of method `join` on
a `List` object. The result of the operation is an instance of `String`.

Let me digress from the subject for a second. Like many other languages, Raku
uses grouping of series of operators/statements into blocks for different
purposes. Meaning of

```
if $a > $b {
    say "Indeed."
}
```

is basically easy to understand: execute the block if the condition statisfied.
Similarly:

```
say "foo"; { my $bar = "bar"; say $bar; }
```

would result in lines _foo_ and _bar_ be printed, but for the second `say` we
create a new scope for a purpose. (_And, yes, `my` declares a new variable._)

Now, let me modify the last example just a little and show you the first Raku
trick explaining why the digression:

```
say "foo, ", { my $bar = "bar"; say $bar; }.WHAT;
```

Yes, the line _foo, (Block)_ we get from this example is exactly what you think
it is: a block in Raku is actually a `Block` class instance!

Methods like `WHAT` belong to a category of 

# Introspection methods

The methods of this group are there to help us reveal the internal structure of
an object. On the personal level, they're one of numerous reasons why I _love_
Raku. For one reason or another sometimes it is necessary to analyse a value aka
object we have somewhere. In case of a reverse-engineering we're likely to know
nothing about the object and with introspection we're able to recover most if
not all of the information and data needed. Similarly, introspection is often 
handy for debugging if by accident an object of wrong type happens at wrong
location.

Within the group the methods could be roughly separated into two basic groups:
type introspection and data introspection. I say "roughly" because there is
method `WHICH`. The output of it tells us both about object type and kind of
data the object represents:

```
my Int $a;
say $a.WHICH; # Int|U140214497563424
$a = 42;
say $a.WHICH; # Int|42
```

Note the difference. The first `say` tells us that the subject of method `WHICH`
is a type `Int`. In Raku it kind of means _`$a` is undefined_. (_I hope to get
back to this "kind of" thing in one of the later articles._) The second `say` 
tells us that the object is a concrete value _42_ of type `Int`. 

As you can see from the example, it is really not easy to definitely classify
`WHICH`. Yet, this example demonstrates the principle I'm trying to explain
here. Because I know what some of you might be thinking about at this moment:
_“Gotcha!  `Int` is a type, it’s not an object!”_ Know what? I'm of no doubt
that you realized already: the statement is wrong!

Oh, yes! It _is_ a type! But not only. Raku has a thing which is correctly to be
named a _type object_. Depending on context, `Int` is a type when, say, used in
a variable or parameter declaration. Moreover, we could say that `Int` is an
object of type `Int` because:

```
Int.WHAT === Int # True
```

*Note*. `===` here serves as a strict type equivalence operator. Also, in this
example we see that `WHAT` returns the type of its invocant.

And yes, it is an object. The only "gotcha" is what kind of object it is and
what it instantiates. As I've shown above, `WHAT` actually tells us nothing
useful here. It is another method we need: 

```
say Int.HOW.^name; # Perl6::Metamodel::ClassHOW
```

Don't pay attention to `.^name` here, just keep in mind that this way we get
the full class name in a string. What is important for us now is _what_ name
we got. Because it is time for

# Raku Metamodel

At this point it would be really handy if the respected reader know about Moose
and MOP. But even if not I'll try to make things easy to grasp.

So, where is our type object? Or, here you are, my little `Int`! But what are
you? An instance of `Perl6::Metamodel::ClassHOW` (or just
`Metamodel::ClassHOW`, as imported into the main Raku namespace). What it
actually means?

The basics tells us that an object is an instance of a class. The class defines
object behavior whatever it means; and _yes_ I know other object systems exist,
but we're now talking about _this_ one! Because `Int`, as any other class in
Raku, is an instance of `Metamodel::ClassHOW` it means that `ClassHOW` actually
defines how a class behaves in Raku!

_Note:_ classes implementing other type objects are called _meta-classes_.

Really, this might be confusing at first. Think of it in terms that `Int`
defines what an integer number is capable of; `Str` defines how strings behave.
`ClassHOW` defines how type objects `Int` and `Str` act and what makes them
objects of the same kind.

Ok, I feel that things haven't become much clearer by now. Let's be piratical an
do something material. What makes an `Int` – `Int`? Things like:

```
2 + 2 == 4;
say 42/0;
```

Outcomes of these and many other actions we perform on integer objects are
defined by class `Int` (an approximation, but ok for now). Meanwhile, what
happens when we:

```
Int.new(42)
```

is defined by `Metamodel::ClassHOW`. Let's take our usual specimen, class `Foo`:

```
class Foo {
    has $.foo is default(42); # Declaring an attribute with default value
    method bar { ... }
}
```

`Foo` behavior is defined by the attribute `$.foo` and the method `bar`. But
_how_ the attribute and the method are added to the class; _how_ the `is
default` statement is implemented – these things are happening behind the scenes
and are responsibility of `Metamodel::ClassHOW`.

Some may already ask: where is compiler in all this if the job is done by a
meta-class? It is sitting in between of your syntax constructs and the metamodel
and supplies an instance of a meta-class with data necessary to build a type
object. Here is what it looks like step-by-step:

1. Compiler meets `class` keyword and determines that classes are now handled by
   `Perl6::Metamodel::ClassHOW`.
1. An instance of the meta-class is created. This is our type object. It can do
   nothing really useful yet.
1. Compiler gives the type object name _Foo_. Actions like this and the
   following ones are normally done by invoking methods provided by
   `Metamodel::ClassHOW` on our newly created type object.
1. The type object is set to have the default parent, class `Any`.
1. When attribute declaration is found an instance of `Attribute` class is
   created and added to the type object. Yes and yes, attributes are objects
   too!
1. When method is encountered, an instance of `Method` class is created and
   added to `Foo`.
1. At the end the compiler invokes method `compose` of
   `Perl6::Metamodel::ClassHOW` which finalizes our shiny new class by
   installing the default constructor method if necessary, building the
   inheritance related data structures, etc.

As you can see, despite the process not been of the simplest ones there is no
black magic in it. Just classes building other classes as robots building
other robots.

Who is building the builders? That's easy – their-meta builders!

```
say Int.HOW.HOW.^name; # NQPClassHOW
```

So, we asked `Metamodel::ClassHOW` who is its metaclass and was told that it is
`NQPClassHOW`.

```
say Int.HOW.HOW.HOW.^name; # KnowHOW
```

`NQPClassHOW` is an instance of `KnowHOW`. 

```
say Int.HOW.HOW.HOW.HOW.^name; # KnowHOW
```

And `KnowHOW` defines... itself? Yes, it does. Because this type object is
provided by the lowest level of any Raku code – by the virtual machine our code
was compiled into. At this point we getting into the area of implementation
details of the particular compiler. I'll dedicate a small section to Rakudo
implementation next. For now the thing to remember is that `KnowHOW` is defined
as being the entity through which any other type object in Raku is defined
directly or indirectly, including the `KnowHOW` itself.

`Metamodel::ClassHOW` apparently, is not the only meta-class in Raku. For
example:

```
enum Bar <a b c>; say Bar.HOW.^name; # Perl6::Metamodel::EnumHOW
module Baz { }; say Baz.HOW.^name;   # Perl6::Metamodel::ModuleHOW
```

Overall, Rakudo has 15 files in its _src/Perl6/Metamodel_ directory with _HOW_
in their names.

In the aggregate, the set of meta-classes together with API they provide is
called _Meta Object Protocol_ or _MOP_. One is getting served by MOP whenever
`.HOW` method is used or `.^` form of a method invocation.

To sum things up, we could say that Raku type system is a layer implemented
above Raku Metamodel using MOP. And talking about layers, this brings us up to
the subject of

# Rakudo, NQP, Runtime VM, And Implementation Stack

Since Rakudo is so far the only Raku implementation, it worth spending a few
minutes considering the basics principles used to implement it.

First of all, Rakudo sits on the top of an implementation stack which includes:

1. A runtime VM responsible for executing the compiled code. Usually the VM is
   called _a backend_. Most commonly this would be `MoarVM` which was designed
   from the scratch to be _the_ Rakudo backend by implementing a lot of Raku
   concepts directly in the VM.

   But aside of `MoarVM` Rakudo also supports two other backends: Java VM and
   JavaScript. Both backends actually lack some of the features already working
   with `MoarVM`. In both cases this is explainable by insufficient resources
   Rakudo core team can put into the projects. Besides, not all features can be
   implemented with JavaScript which, for example, cannot do proper
   multi-threading.
1. NQP compiler built atop of a backend. NQP is a subset of Raku. Its name
   stands for _Not Quite Perl_ and was born long when Raku was Perl6 yet.
   NQP has two key properties:

   - being a subset of Raku it works much faster
   - it can compile itself
   - it is powerful enough to build any other compiler
1. Rakudo is implemented in NQP with a few touches of C/Java/JS code to
   implement a couple of low-level features.

In the perspective of Raku metamodel the information useful for us is the fact
that Rakudo implementation of the metamodel is actually also written in NQP. So,
when you call a method of `Perl6::Metamodel::ClassHOW` – you actually call a
method written in NQP and belonging to a NQP class. This is possible because
in Rakudo one way or another any type object is backed by a VM object. Let me
skip all the details of this and focus on a very interesting use case stemming
from this fact: if we implement another language atop of the same VM+NQP stack
any type or object implemented by that language could be used by Raku code!

For example, if somebody takes the duty of implementing Python in NQP then a lot
of Python code would instantly become available to any Raku code without a
recompilation/translation needed! This makes Rakudo implementation stack unique
up to some extent.

_Actually, even here Raku follows the 
[TIMTOWTDI](https://en.wikipedia.org/wiki/There%27s_more_than_one_way_to_do_it)
principle of Raku and several [`Inline::`](https://modules.raku.org/search/?q=inline)
modules provide ways of incorporating code from other languages._

# Before We Finish

Let me repeat myself: this series is only an introduction to Raku. It's purpose
is to give good starting points and hopefully make you interested in Raku a
little more than you were before started reading the publication. I'm saying this
because the subject of this article is really not something we usually start
with when teach somebody to a new programming language. But that's why this
article is limited to the very basics of Raku OO model. This is ok as long as
this [adivise](/arfb-publication/01-introduction/#one-more-thing) is followed.
In particular, [the section about MOP](https://docs.raku.org/language/mop#index-entry-Introspection)
in the documentation is a good followup to read. Don't worry if you don't
undertstand all of it at this moment. Raku is really big and complex language
(though surprisingly simple to start with! espcially with a good book at hand).
Even some experienced developers working with it for years sometimes find new
aspects of it they didn't knew about previously!

Be bold and have fun!
