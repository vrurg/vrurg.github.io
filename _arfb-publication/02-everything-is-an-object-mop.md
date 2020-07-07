---
title: Everything Is An Object. MOP.
logo: /assets/images/Camelia-200px-SQUARE.png
---

As this series is not a typical beginner guide it is starting with a non-typical
subject.
<!--more-->

# It Is. Literally.

Raku is a multi-paradigm language meaning that one can implement functional
paradigm, or use reactive programming, or write in ye good olde procedural
style. Yet Raku itself is built with OO approach. In practice it means that when
we say ‘everything is an object’ we literally mean it!

One can ask: if everything is an object then we must be able to invoke
methods on everything? We say: no doubt!

```
say “Hello world!”.WHAT; # (Str)
```

What happens in this snippet is Raku takes an object representing the string
_”Hello world!”_ and invokes method `WHAT` on it. Pretty much no surprise here,
I hope. Same apply to any other data in Raku. For example, `(1,2,3).join(“,”)`
is nothing else but invocation of method `join` on a `List` object. The result
of the operation is an instance of `String`.

Let me digress from the subject for a second. Like many other languages, Raku
uses grouping of series of operators/statements into blocks for different
purposes. The meaning of

```
if $a > $b {
    say "Indeed."
}
```

is basically easy to catch: execute the block if the condition statisfied.
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

Yes, the line _"foo, (Block)"_ we get output by this example is exactly what you
think it is: a block in Raku is actually a `Block` class instance!

Methods like `WHAT` belong to a category of 

# [Introspection](https://docs.raku.org/language/mop) methods

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
method `WHICH`. Its output tells us both about the object type and the kind of
data it represents:

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

As you can see from the example, it is really not easy to indisputably classify
`WHICH`.

Ok, some might be already thinking at this moment: _“Gotcha!  `Int` is a type,
it’s not an object!”_ Know what? I'm of no doubt that you have realized already:
the statement is wrong!

Of course, it _is_ a type! But not only. In Raku it is more correct to use a
term _type object_. Depending on context, `Int` is a type when, say, used in
a variable or parameter declaration. Moreover, up to some extent we could say
that `Int` is an object of type `Int` because:

```
Int.WHAT === Int # True
```

*Note*. `===` here serves as a strict type equivalence operator. Also, in this
example we see that `WHAT` returns the type of its invocant.

However, a type object is more than that! This "more" is revealed with another
introspection method:

```
say Int.HOW.^name; # Perl6::Metamodel::ClassHOW
```

Don't pay attention to `.^name` here, just keep in mind that it gives us the
full class name in a string. Let's pay attention to _what_ name we've gotten
from  method `HOW`. Because it is time for

# Raku Metamodel

At this point it would be really handy if the respected reader knows about Moose
and MOP. But even if not I'll try to make things easy to catch with.

So, where is our type object? Ah, here you are, my little `Int`! And what are
you hiding under your `HOW` method?

```
say Int.HOW.WHICH; # Perl6::Metamodel::ClassHOW|140267043542544
```

Since there is no symbol `U` following the pipe `|` after the class name it is
an instance of `Perl6::Metamodel::ClassHOW`. This instance is called
_meta-object_. `Perl6::Metamodel::ClassHOW` is a _meta-class_. Each type
object in Raku is paired with (or, in other words: it is backed by) its own
meta-object. It is the meta-class which knows how to build a type object. It is
the meta-object which actually does the job.

_Note:_ `Perl6::Metamodel` namespace is imported as just `Metamodel` into
user-level code. Thus, `Metamodel::ClassHOW` is an alias to
`Perl6::Metamodel::ClassHOW` and will be used throughout this series
extensively. Sometimes, when context allows, it might be shortened to just
`ClassHOW`.

Why the complexity? Lets look at things retrospectively.

In the beginning there was a CPU. And the CPU knew about integers. And what
could be done to them was limited.

Then there was high level languages like C++ where integers were not really much
different from what was provided by CPU. But there was classes and ways to
implemented other representations for numeric data types. The compiler knew how
to handle classes, enums, and other data type constructs. And what could be done
to them was limited.

And now there is Raku where compiler knows what meta-class to instantiate in
order to create a new class, enum, etc. And what could be done to them is almost
limitless now!

Ok, I feel that things haven't become much clearer by now. Let's be practical an
do something material. What makes an `Int` – `Int`? Things like:

```
2 + 2 == 4;
say 42/0;
```

Outcomes of these and many other actions we perform on integer objects are
defined by class `Int` (an approximation, but OK for now). Meanwhile, what
happens when we do:

```
Int.new(42)
```

is mostly defined by `Metamodel::ClassHOW`. Let's take our usual specimen for
experimenting, class `Foo`:

```
class Foo {
    has $.foo is default(42); # Declaring an attribute with default value
    method bar { ... }
}
```

A `Foo` instance behavior is determined by the attribute `$.foo` and the method
`bar`. Yet _how_ the attribute and the method are added to the class; _how_ the
`is default` statement is implemented – these things are happening behind the
scenes and are responsibility of `Metamodel::ClassHOW`. This is one of the key
distinctions of Raku from many other languages where all these aspects are
responsibility of compiler/interpreter and are usually hardcoded into them.

The evident question would be: then where is Raku compiler in all this if the
job is done by a meta-class code? It is sitting in between of your syntax
constructs and the metamodel. The compiler instantiates a meta-class when
necessary and supplies the resulting meta-object with data needed to build a
type object. Here is how it all happens, step-by-step:

1. Compiler meets the `class` keyword and determines that classes are now
   handled by `Perl6::Metamodel::ClassHOW`. (NB: this _"now"_ must be
   intriguing!)
1. A new type object is created with the help of the meta-class. This step can
   be split into:

   * a meta-object is instantiated from the meta-class
   * a new type object is created and paired with the meta-object

1. Compiler gives the type object name _Foo_. Actions like this and the
   following ones are normally done by invoking methods provided by
   `Metamodel::ClassHOW` on our newly created meta-object.
1. The type object is set to have the default parent, class `Any`.
1. When attribute declaration is found an instance of `Attribute` class is
   created and added to the type object. (Yes and yes, attributes are objects
   too!)
1. When the method declaration is encountered, an instance of `Method` class is
   created and added to `Foo`.
1. At the end the compiler invokes method `compose` of
   `Perl6::Metamodel::ClassHOW` which finalizes our shiny new class by
   installing the default constructor method if necessary, building the
   inheritance related data structures, etc.
1. The class is now ready for use!

As you can see, despite the process not been of the simplest ones there is no
black magic in it. Just classes building other classes as would robots assemble
other robots from component parts.

Then who is building the builders? That's easy – their meta-builders!

```
say Int.HOW.HOW.^name; # NQPClassHOW
```

We asked `Metamodel::ClassHOW` who is its meta-class and were told that it is
`NQPClassHOW`.

```
say Int.HOW.HOW.HOW.^name; # KnowHOW
```

`NQPClassHOW` is an instance of `KnowHOW`. 

```
say Int.HOW.HOW.HOW.HOW.^name; # KnowHOW
```

And `KnowHOW` defines... itself? Yes, it does. Because this entity is provided
by the lowest level of any Raku code – by the virtual machine executing it. At
this point we're getting into the area of implementation details of the
particular compiler. The next section of the article deals with Rakudo
implementation. For now the thing to remember is that `KnowHOW` is defined as
being the entity through which any other type object in Raku is defined directly
or indirectly, including the `KnowHOW` itself.

`Metamodel::ClassHOW`, apparently, is not the only meta-class in Raku. For
example:

```
enum Bar <a b c>; say Bar.HOW.^name; # Perl6::Metamodel::EnumHOW
module Baz { }; say Baz.HOW.^name;   # Perl6::Metamodel::ModuleHOW
```

Overall, Rakudo has 15 files in its _src/Perl6/Metamodel_ directory with _HOW_
in their names.

To sum up, the set of meta-classes together with API they provide is called
_metamodel_. The way Raku communicates with its metamodel is called _Meta Object
Protocol_ or _MOP_. One is getting served by MOP whenever `.HOW` method or `.^`
form of a method invocation is used.

Even the compiler itself is using MOP for different purposes. For example, it
can test for type constraint at compile time by invoking a method on a
meta-object. Or find a method object on a class. But this subject worth a
dedicated article.

We could say that Raku type system is a layer implemented above Raku Metamodel
using MOP. 

## Surprise Me!

I love this quote from
[Ratatouille](https://www.imdb.com/title/tt0382932/?ref_=nv_sr_srsg_0)! Because
what's the point of a good something unless it brings joy and perhaps some fun?

I've mentioned one direct and evident use for MOP and it's introspection. But
the metamodel is way more than only this! Remember I wrote above limitless
possibilities? My first steps with Raku was writing
[`AttrX::Mooish`](https://github.com/vrurg/raku-AttrX-Mooish) module which
implements such attribute properties as:

- laziness
- value filtering
- value change triggers

And all of it is totally transparent for user code! For example:

```
class Foo {
    has $!foo; # A private attribute
    method bar { say $!foo }
}
Foo.new.bar; # (Any)
```

But with:

```
use AttrX::Mooish;
class Foo {
    has $!foo is mooish(:lazy); # A private attribute
    method !build-foo { 42 }
    method bar { say $!foo }
}
Foo.new.bar; # 42
```

Sure, the module is heavily utilizing MOP to achieve its goals.

Another great example is [`OO::Monitors`](https://github.com/jnthn/oo-monitors).
If you ever wrote any multi-threaded code then the importance of proper locking
should be obvious. Imagine a big data structure implemented as a class and prone
to concurrency errors. The class has dozens of methods and most if not every of
them must be protected with locking like this (in pseudo-code):

```
method modify_xyz(...) {
    $.global-lock.lock;
    ... # The implementation
    $.global-lock.unlock;
}
```

Boring, boring boilerplates... Instead one can import the module and use keyword
`monitor` instead of `class`:

```
use OO::Monitors;
monitor Foo {
    method modify_xyz(...) {
        ... # The implementation
    }
}
```

Job done, no more than one thread would have access to a class instance at a
time! Use it in a concurrent environment and be worried no more.

One more exam... Er... No, no! It's better to stop now. Or this article alone
would become a size of a good book! But I plan to write about compiler
interaction with user code, where a lot of magic is possible, some day.

# Rakudo, NQP, Runtime VM, And Implementation Stack

Since Rakudo is so far the only Raku implementation, it worth spending a few
minutes considering its basic principles.

First of all, Rakudo sits on the top of an implementation stack which includes,
from bottom up:

1. A runtime VM responsible for executing the compiled code. Usually the VM is
   called _a backend_. Most commonly this would be _MoarVM_ which was designed
   from the scratch to be _the_ Rakudo backend by implementing a lot of Raku
   concepts directly in the VM.

   But aside of MoarVM Rakudo also supports two other backends: Java VM and
   JavaScript. Both backends actually lack some of the features already provided
   with MoarVM. In both cases this is explainable by insufficient resources
   Rakudo core team can put into the projects. Besides, not all features can be
   implemented with JavaScript which, for example, cannot do proper
   multi-threading.
1. NQP compiler built atop of a backend. NQP is a simplified subset of Raku. Its
   name stands for _Not Quite Perl_ and was born long ago when Raku was Perl6
   still. NQP has a couple of key properties:

   - being a simpler subset of Raku it works much faster
   - it can compile itself
   - it is powerful enough to build any other compiler
1. Rakudo is implemented in NQP with a few touches of C/Java/JS code to
   implement a couple of low-level Raku-specific features.

From the perspective of Raku metamodel the information useful for us is the fact
that Rakudo implementation of the metamodel is actually also written in NQP. And
whenever you invoke a method of `Perl6::Metamodel::ClassHOW` – you actually
refer to a method written in NQP and belonging to a NQP class. This is possible
because in Rakudo one way or another any type object is backed by a VM object.

Let me skip all the details of this and focus on a very interesting use case
stemming from this fact: if we implement another language atop of the same
VM+NQP stack any type or object implemented by that language could be used by
Raku code!

For example, if somebody takes the duty of implementing Python in NQP then a lot
of Python code could instantly become available to any Raku code without a
recompilation/translation needed! This makes Rakudo implementation stack unique
up to some extent.

_Actually, even in this Raku follows the
[TIMTOWTDI](https://en.wikipedia.org/wiki/There%27s_more_than_one_way_to_do_it)
principle of Raku and several
[`Inline::`](https://modules.raku.org/search/?q=inline) modules provide ways of
incorporating code from other languages by other means._

# Before We Finish

Let me repeat myself: this series is only an introduction to Raku. Its purpose
is to give good starting points and hopefully make you interested in Raku a
little more than you were before started reading this publication. But in
neither way it is comprehensive enough! Moreover, it only scratches the surface
of Raku OO model. To some aspects of it I'll return in future articles. Some other are
better be found in [the documentation](https://docs.raku.org). Sometimes even
referencing to Rakudo [sources](https://github.com/rakudo/rakudo) could be
helpful!

In either case, don't worry if something is unclear at the moment! Raku is in
fact a big and complex language (though surprisingly simple to start with!
Especially with a good book at hand). Even some experienced developers working
with it for years sometimes get surprised with it! But isn't it great to have a
chance of learning something new in what may seem to be so familiar?

Be bold and have fun!
