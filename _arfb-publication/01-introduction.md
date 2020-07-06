---
title: Introduction
toc: false
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---

I'm starting a series of articles devoted to Raku for beginners. But...
<!--more-->

... this series is not about Raku basics. Instead here one can find information
about how Raku works from inside-out. I plan to talk about things which are
often either not on the surface, or not well-documented yet, or totally hidden
behind the scenes for any other reason.

You may ask why is it for beginners then? Let me correct myself a little: the
audience is expected to be Raku beginners. Otherwise I expect a reader to
already know such programming concepts as object orientation, memory management,
common language constructs, etc. Say, I expect the following code snippet to be
understood on the level "well, we declare a class, instantiate it and call a
method which outputs something and sums its arguments; looks like the result of
the sum is returned!":

```
class Foo {
    method foo(Int $a, Int $b) {
        say "Hello!";
        $a + $b
    }
}
my $foo = Foo.new.foo(42, 13);
say $foo;
```

If you have trouble understanding the above example then my reccomendation would
be to visit [Amazon](https://www.amazon.com/s?k=perl6+book) or any other online
or offline book store first and start with one of the great books about Perl6.
And if the language history is also _terra incognita_ for you, don't get
confused here. The language once started as Perl6 but was renamed to Raku in
October 2019.

For those who feel the bravery to dive deep into the language internals, I
promise to do my best in starting with simpler concepts. Each next article would
be getting to more complicated concepts as gradual as possible.

As a matter of fact, the series just've started by telling about Perl6 and Raku
and how they're the same. It is now time to tell about Rakudo. 

In the modern world of programming it is now common place for a language to be
its implementation.  Perl is the `perl` command, Ruby is `ruby`, etc. Not that
this statement is totally true. After all, JavaScript has several different
implementations. But in general it's not rare to see people mixing up a command
with the language it compiles.

From the start Raku was developed with possibility of many implementations in
mind. Even though at the moment I'm writing these lines the language is only
implemented by Rakudo compiler, it is still not considered to be _the compiler_.
And I would like to ask you, my reader, to remember this difference: though
Rakudo implements Raku, Rakudo is not _the_ Raku. On practice it means one very
important thing: sometimes I might write about implementation details which are
specific to Rakudo. A new compiler might have the very same things implemented
differently in the future. Whenever I'll be writing about such specifics will
try to remember to leave special notes about this.

And as I don't want to get people bored from the start, this is perhaps the best
moment to call it a day. Buckle up and let's drive!

# One More Thing

Use the [documentation](https://docs.raku.org/), Luke! Because it is and will
always be The Power. But as no Power can be ubiquitous there're will always be
a story to tell!
