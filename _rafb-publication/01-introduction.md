---
title: Introduction
toc: false
tags: Raku publication
---

I'm starting a series of articles dedicated to Raku for beginners. But...
<!--more-->

What these series are not about is Raku basics. Instead here one could find
information about how Raku works from inside-out. I plan to talk about things
which are often either not on the surface, or not well-documented, or totally
hidden behind the scenes.

You may ask why is it for beginners then? Let me correct myself a little: this
publication is for beginners in Raku. Otherwise I expect a reader to have basic
understanding of programming concepts such as object orientation, memory
management, common language constructs, etc. Say, I expect the following code
snippet to be understood one the level "well, we declare a class, instantiate it
and call a method which outputs something and sums its arguments; looks like the
result of the sum is returned!":

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
be to visit [Amazon](https://www.amazon.com/s?k=perl6+book), or any other online
of offline book store and start with one of the great books about Perl6. And if
the history of the language is also totally new for you, don't get confused here. 
The language once started as Perl6 but was renamed to Raku in October, 2019.

For those who feel the bravery to dive deep into the language internals, I
promise to do my best in starting with simpler concepts. Each next article would
be getting to more complicated concepts as gradual as possible.

Actually I've started already by telling you about the Perl6 and Raku and how
they're the same. It is now time to tell about Rakudo. 

In the modern world of programming it is now common place for a language to be
its implementation.  Perl 5 is `perl` command, Ruby is `ruby`, etc. Not that
this statement is totally true. After all, JavaScript has several different
implementations.

Raku from the beginning was developed with possibility of many implementations
in mind. Even though for the moment I'm writing these lines it is only
implemented by Rakudo compiler, it is still not considered to be _the compiler_.
And I would like to ask you, my reader, to remember this difference: though 
Rakudo implements Raku, Rakudo is not _the_ Raku. On practice it means one very
important thing: sometimes I might write about implementation details which are
specific to Rakudo. A new compiler might have the very same things implemented
differently in the future. Whenever such case would be encountered in this
series I'll be trying to remember about leaving special warnings.

And as I don't want make people bored from the start, this is perhaps the best
moment wrap it up. Buckle up and let's drive!
