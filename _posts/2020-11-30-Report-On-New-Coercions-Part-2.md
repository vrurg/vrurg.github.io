---
title: The Report On New Coercions Part 2
tags:
    - Raku
    - MOP
    - core
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
I didn't expect my [previous report](/2020/11/16/Report-On-New-Coercions) to have a continuation, but here it goes. When the initial implementation of new coercions was merged, I started checking if there're any tickets in the issue tracker which can now be closed. One of them, [#2446](https://github.com/rakudo/rakudo/issues/2446), is related to coercions but still needed a fix. As long as I was looking into the ticket, it was becoming clear to me that the time has come for an itch I had had for quite some time already.

Let me explain. A while ago I noticed [an inconsistency](https://github.com/Raku/problem-solving/issues/3) in how nominalizables are handled with respect to a container default value. An example from the above referenced problem-solving issue illustrates the problem:

```
my Int:D $a = 0; 
say $a.VAR.default.^name; # Int
my Int $a where {True};
say $a.VAR.default.^name, " of ", $a.VAR.default.HOW.^name; # <anon> of Perl6::Metamodel::SubsetHOW
```

The more I was studying the problem and learning about Raku metamodel, the more I was convinced that nominalizable types must be transparent. Indeed, Raku currently defines three nominalizable type objects: definite, coercion, and subset. All three serve as kind of wrappers around other types, providing additional functionality, applying constraints, etc. But one way or another there is always a nominal type inside. Eventually this is going to be the type our code will interact with.

_Apparently, a nominalizable could also be wrapped around a generic. But this situation should be considered temporary as at some point the generic will be replaced with something tangible._

Actually, one can say that a nominalizable is a way to make sure that the value we get conforms to our requirements. Otherwise, it is the value and its type which are the primaries here.

Let's consider somewhat ugly example:

```
subset S of Int:D(Str) where * > 0;
my S $foo = "13";
```

It utilizes all three nominalizables at once. But  nevertheless, it is correct to say that `$foo` is a scalar of type `Int` in first place.

Back then I'd produced a partial fix for subsets. But the feeling that the fix is incomplete and more generic solution is necessary remained with me since then. So, I was looking forward to implementing full transparency of nominalizables, including the MOP level.

## Metamodel Transparency
### Archetypes
Let's look at the above subset example again and try to imagine what Raku complier must do to make it work as expected? First of all, we expect it to coerce from a string into an integer. Because it's a kind of wrapping one nominalizable into another, the compiler must first unwrap them all in order to find out that there is a coercion lurking deep inside. Now, imagine an assignment to `$foo` inside of a tight loop and what would it cost to do unwrapping at each iteration.

Generally speaking, sometimes compiler mustn't even care what particular type object it is dealing with right now. Knowing its archetypes would be sufficient. Therefore if `S.HOW.archetypes.coercive` provides us with a true value then it's all the compiler needs to handle the type properly. What's really good is that archetypes of a type object are defined only once at its construction stage and remain immutable afterwards. All we need is to borrow those we consider transient ones from the type object the nominalizable wraps around. For now I'm talking about the following three archetypes:

- definite
- coercive
- generic

For example:

```
role R[::T] {
    method foo(T() $v) { }
}
my $how = R.^candidates[0].^lookup('foo').signature.params[1].type.HOW;
say "HOW     : ", $how.^name;
say "Coercive: ", $how.archetypes.coercive;
say "Generic : ", $how.archetypes.generic;
```

This snippet now prints:

```
HOW     : Perl6::Metamodel::CoercionHOW
Coercive: 1
Generic : 1
```

Which makes full sense because until the role is specialized the parameter `$v` do have a coercive generic type. As soon as the roles gets consumed with a nominal type as its argument:

```
class C does R[Int] { }
$how = C.^concretizations[0].^lookup('foo').signature.params[1].type.HOW;
say "- Specialized";
say "HOW     : ", $how.^name;
say "Coercive: ", $how.archetypes.coercive;
say "Generic : ", $how.archetypes.generic;
```

The parameter type is still a coercive, but not generic anymore.

```
HOW     : Perl6::Metamodel::CoercionHOW
Coercive: 1
Generic : 0
```

So, with the latest PRs merged, Rakudo compiler has the necessary shortcuts to know exactly how to handle a type object it currently deals with. Now the following works with no excessive overhead on introspecting variable's type:

```
subset OfCoercive of Int(Str);
my OfCoercive $v;
$v = "42";
say $v.WHICH; # Int|42
```

### Wrappee

Another property of nominalizable transparency is that whenever possible it nominalizes to its nominal type.

```
class C2 { method foo { say "foo!" } }
subset OfC2 of C2();
OfC2.foo; # foo!
```

But what if we need to know nominalizable's immediate wrappee type, would it be a nominal or another nominalizable? I.e. for `subset Foo of Int()` it would be coercion `Int()`. The catch here is that metaclasses of all three nominalizable types has different methods to report this information back:

- `.^base_type` for a definite
- `.^refinee` for a subset
- `.^target_type` for a coercion

In the real life it means that one would have to have a conditional branch for each kind of type object. No doubt, this is not particularly good. Therefore I decided to add one more role, `Perl6::Metamodel::Nominalizable`, and make each nominalizable metaclass consume it to provide standardized interface. To work correctly, the role requires each consuming metaclass to define additional methods `nominalizable_kind` and `!wrappee`. The former method is expected to return a string, describing type object's function. For the three basic nominalizables the strings are *'coercion'*, *'definite'*, and *'subset'*. One could argue that the kind is already provided by `archetypes`. But the point is:

1. there is no `subset` archetype and there is no need for it
2. third-party developers can implement their own nominalizables with no individual archetypes
3. the string is used to implement `.^wrappee` method which uses it to find the correct nesting and fetch the wrappee with the above mentioned `!wrappee`

The `.^wrappee` method can be invoked with or without named arguments. When there are no nameds, it would return the immediate wrappee of its nominalizable type object. For example, for `OfCoercive.^wrappe` it's going to be `Int(Str)`.

If a named argument is specified then the method tries to find the closest nested wrappee whose kind is the same, as the key of the argument. For example, for subset `S` from the example above, `S.^wrappee(:definite)` will result in `Int:D`.

The method could also be called with more than one named argument. In this case the first matching is returned. I.e. `S.^wrappee(:coercion, :definite)` would give us `Int:D(Str)`.

## Throwing an exception
This section is not directly related to nominalizables, but it's about another itch I had for quite a long time. I mention it here because it was also scratched as a part of my work on nominalizables.

One of a quite annoying problems linked to the fact that the metamodel is written in NQP is that there is no easy way to throw a specialized Raku exception object from metamodel code. For this reason most of the error reporting utilizes plain `nqp::die("Some error message")` approach. Apparently, for Raku code exceptions thrown this way appear as featureless `X::AdHoc` instances.

There is a way though to let metamodel throw a specific Raku exception. It is implemented by setting `P6EX` compiler symbol which is bound to a hash where keys are full exception names and the values are code stubs which actually produce and throw corresponding exceptions. See [src/core.c/Exception.pm6](https://github.com/rakudo/rakudo/blob/e8ab5272f23fe1f225bc5dce707ef620b5e65a09/src/core.c/Exception.pm6#L2977) for the implementation details.

A typical use of the symbol in MOP code would then look something like this (copied from `SubsetHOW.pm6`:

```
my %ex := nqp::gethllsym('Raku', 'P6EX');
if nqp::existskey(%ex, 'X::NYI') {
    %ex{'X::NYI'}('Subsets of native types');
}
else {
    nqp::die("Subsets of native types NYI");
}
```

The problems I see here are:

- too much of boilerplate for both declaring an exception and using it
- exception declaration has to be done kind of twice: with the class and with a `P6EX` hash entry
- a user of the exception code stub must remember the order of parameters which, most likely, will be used as named arguments for exception constructor

I decided to take another approach. Rakudo implementation of metamodel has `Perl6::Metamode::Configuration` class which is never gets instantiated and used as a namespace to hold a few global configuration parameters. For example, it allows to register standard classes like `Perl6::Metamodel::Configuration.stash_type()`, `.submethod_type()`, etc.

My solution provides a way for Raku code to register the standard exception package `X`, and a method to lookup an exception class in the package and throw an instance of it. If either the `X` package is not registered, or the exception class cannot be located, then the method falls back to `nqp::die` with a plain text message provided by the caller. The method is called `throw_or_die` and it's typical use looks like this snippet from [`Perl6::Metamodel::Nominalizable`](https://github.com/rakudo/rakudo/blob/e8ab5272f23fe1f225bc5dce707ef620b5e65a09/src/Perl6/Metamodel/Nominalizable.nqp#L23):

```
Perl6::Metamodel::Configuration.throw_or_die(
    'X::Nominalizable::NoWrappee',
    "Can't find requested wrappee on "
        ~ $*ORIG-NOMINALIZABLE
        ~ ": reached a nominal type "
        ~ $my_wrappee.HOW.name($my_wrappee),
    :nominalizable($*ORIG-NOMINALIZABLE),
    :kinds(%kind_of),
);
```

So, now if one needs to use a Raku exception in NQP code then the following steps should be taken:

1. Declare a new exception class in `Exception.pm6` under the `X` namespace.
2. The `Perl6::Metamodel::Configuration.throw_or_die` used with full exception name, an error message to be used with `nqp::die` if the exception class is missing, and with named parameters to be passed over to the exception constructor.

So, basically that's all. With this method in place, I hope the situation with error reporting by MOP classes will improve noticeably as time goes by.

## `done`

At this moment I consider my work on coercions and nominalizables done. I mean, apparently there will be bugs to fix. Perhaps some more optimizations. But otherwise I need a break and wish to switch to another task.

In this post I didn't mention that `Metamodel::SubsetHOW` got `instantiate_generic` method and is now ready for something like:

```
role R[::T] {
    my subset RS of T;
    method foo(RS $v) {...}
}
```

No, this doesn't work yet. To implement generic subsets and their un-generalization we need to do much more, than it worth it in the light of upcoming `RakuAST`. The problem with this example is that it's rather easy to be done for the signature binding. But then the outcome of `$v ~~ RS` in method's body wold be unpleasantly surprising.

But otherwise I'm happy to have all this work done and see people already starting to use the new semantics.

