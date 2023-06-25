---
title: "Metamodel: Archetypes"
description: ""
# date: 2023-06-22T20:31:48.474Z
# preview: ""
tags: ["Raku", "MOP"]
categories: ["ARFB", "Publications"]
toc: true
logo: /assets/images/Camelia-200px-SQUARE.png
---
One of the prominent features of the Raku language is its extensive type system. This doesn't mean the vast number of
the standard classes and roles but it is about _the system_ where these two are not the only kind of types allowed. Is
it still unclear what we're talking about? Then let's have a look at a fundamental concept of the metamodel.

# On The Surface

The first things that pop up in minds of OO programmers would be classes and, next to them,
roles[^role_kinds]. I'm not even sure if a role is even considered being a type in every language where the concept
exists. It would be interesting to hear from the readers, who are better familiar with the area.

A newbie could be confused at first to find out that in Raku `Foo:D()` isn't a class `Foo` with some syntax bells and
whistles attached, but a type object on its own. And that trying something like `Foo:D().new` would result in an
exception thrown because this particular type cannot produce concrete objects.

Let's list some type kinds we have, just of the top of my head:

- class
- role
- enum
- subset
- [type smiley](https://docs.raku.org/syntax/Type%20Smiley)
- [coercion](https://docs.raku.org/language/typesystem#Coercion)

What is common among them? The fact that any object can be typematched against them. And this is basically it. Can we
instantiate a type? I.e. can we create a concrete object out of it? The apparent "yes" goes for
classes[^class_not_always_instantiable]. One could argue that `role Foo {}.new` would create an instance of `Foo`, but
in reality this line hides [auto-punning](https://docs.raku.org/language/typesystem#Auto-punning) behind it, meaning
that we end up having a class `Foo` which we then instantiate.

For the remaining type kinds instantiation would simply fail[^enum_create].

It's hard to tell what other publicly visible properties we can use to show the differences between the kinds. All one
needs to know is what behaviors they provide and care about nothing else otherwise.

# Categorizing Independently

The one who does care is the compiler. Because it needs to know exactly what does it deal with, can a type be used here
or there, which "buttons" are to be pushed to get what a user is asking for. This where a question pops up: how to let
the compiler do its job in a best possible way?

To complicate the situation a bit let's not forget that Raku's metamodel allows a developer to create their own type
object by introducing a new metamodel class[^and_new_syntax]. Therefore the most straightforward approach where we just
take the metamodel object and check what type is it would only work for the limited set provided by the CORE itself.
Forget about an independent type – inherit from the existing `Metamodel::ClassHOW`, `Metamodel::SubsetHOW`, etc.

There is another solution which comes to mind and which is looking very promising at the first glance: we introduce
roles that would be responsible for marking or even implementing certain properties of the metaobjects. Unfortunately,
there is at least one case where this solution would complicate the code required to handle a type object. This isn't a
big problem if we consider the compiler alone, but the run-time is in the risk zone too because on many occasions it has
to solve similar tasks. It's too early to get into the details now, but we will return to this matter later when it
comes to nominalizables.

Raku's answer to these challenges is the _archetypes_ concept. It could be wound down to the following definition:
archetypes is a set of flag-style properties where raising a flag on a metamodel object signals about it's ability to
implement corresponding functionality.

Technically archetyping is implemented by
[`Metamodel::Archetypes`](https://github.com/rakudo/rakudo/blob/2023.05/src/Perl6/Metamodel/Archetypes.nqp) class, which
is a container for a few boolean attributes – one per each archetype. Corresponding methods provide read only access for
the attributes:

```
say class Foo {}.^archetypes.nominal;         # 1
say (subset Bar of Any).^archetypes.nominal;  # 0
```

By using them the compiler (or run-time code) doesn't need to know if a type in a certain context has this or that
metaclass behind it as often it's OK to know if the class has appropriate archetype.

## Available Archetypes

Let's get to the point and enumerate the archetypes we have. As a matter of fact, this is what this text is created for
in the first place!

### `nominal`

The most simple and straightforward archetype which barely needs much explanation.

Part of being a nominal means that a value can be produced with this type. At the first glance it is not applicable to
roles, but since one can always do `Role.new` things start making sense again[^even_though_the_pun].

[^even_though_the_pun]: Even though it's done via punning.

### `generic`

A generic type is the one which serves as a placeholder where the concrete type is not known at the compile time.
Generics are useless as such and any attempt to directly use them as method invocators most often ends up with some kind
of error.

The form of generic that'd be immediately familiar is a type capture:

```
sub foo(::T) {
    say T.^name;
}
foo(Bool); # Bool
```

In this example when `foo` is called our runtime _instantiates_ the generic type `T` with `Bool`. Many entities of the
Raku language are capable of generic instantiation by implementing `instantiate_generic` method[^undocumented]. The
process itself is sometimes tricky and has a number of pitfalls. A couple of them still remain unresolved,
unfortunately.

In a day to day activities it should be nearly to impossible to cross ways with a generic type wandering free in the
wild. But we can entrap one by modifying the `sub foo` a little:

```
sub foo(::T, T $v) {}
say &foo.signature.params[1].type.^name;     # T
say &foo.signature.params[1].type.HOW.^name; # Perl6::Metamodel::GenericHOW
```

There is only one specific requirement to a generic: its metaobject must have `instantiate_generic` method.

### `coercive`

Type objects of this archetype must be capable of coercing values into instances of other types. The primary requirement
to the coercive metaclasses is to implement method `coerce`.

### `definite`

Type objects of this archetype are representing definedness of a value. In rakue these are type smiley, created with
either `:D` or `:U`.

### `nominalizable`

Types of this kind cannot produce values but they know how to produce a nominal type. The nominalizables Raku provides
out of the box are the smileys, subsets, and coercions. By simplifying things down, we can say that all three are kind
of wrappers around other types. Say, `Str:D` is a definite wrapper over `Str`.

The other property they have in common is implicitly described in the previous paragraph. Have you noticed that "other
types" locution has been used instead of "nominal types"? This is because Raku allows to wrap one nominalizable into
another like in the following case:

```
subset Foo of Int();
say Foo:D.^base_type; # (Foo)
```

This complicates compiler's and runtime code quite noticeably. In many cases it is insufficient to know that a definite
represents a subset, but very important not to miss the coercion deeper inside it! Finding this out would require a
number of checks to be performed:

1. is a type nominalizable?
2. what kind of nominalizable it is?
3. since we now know how to get its wrapee then repeat from step 1.

Also take into account that these checks are to be done not once somewhere and by the compiler alone, but in many places
and often times by the run-time code too.

The solution for this is _nominalizable transparency_ where properties of underlying types are available on their
wrappers. Surely, it applies to the archetypes too:

```
say Foo:D.^archetypes.coercive; # 1
```

Remember though that not every archetype is subject for nominalizable transparency. It only works with `coercive`,
`definite`, and `generic` because these affect analysis of nominalizables.

Let's tweak the example from the `generic` section above and observe these mechanics in action:

```
sub foo(::T, T:D() $v) {}
my $type = &foo.signature.params[1].type;
say "NAME    : ", $type.^name;                 # NAME    : T:D(Any)
say "Coercive: ", $type.^archetypes.coercive;  # Coercive: 1
say "Definite: ", $type.^archetypes.definite;  # Definite: 1
say "Generic : ", $type.^archetypes.generic;   # Generic : 1
```

_At this point it should be more clear as to why the archetypes concept works better than the idea with roles, mentioned
above. But I'll leave it for the concluding section of this article._

### `inheritable`

A type object possesses this archetype if it can be inherited from. In the Raku core we mean classes and native types
here.

### `inheritablizable`

Whenever a type cannot be inherited from but it knows how to produce something `inheritable`. Think of roles in first
place: a role can produce a pun of itself which can be subclassed.

### `composable`

Let me simply quote [the
comment](https://github.com/rakudo/rakudo/blob/297a1ec354df6722cf049ffb20f21af7bb61dd34/src/Perl6/Metamodel/Archetypes.nqp#L23-L25)
to this archetype:

```
# Can this be composed (either with flattening composition, or used
# as a mixin)?
```

First of all, don't associate the term "composed" with the method `compose`[^meth_compose], that can be found on each
`HOW`-class. Being `composable` doesn't mean "to have the method `compose`". There is a relation, but it is not that
direct.

Bearers of this archetypes are expected to be capable of serving as a source of methods, and attributes available for
adoption by other types. Think of roles, in first place: any composable must behave well anywhere where otherwise a role
would be used.

The word "flattening" in the above citation could be confusing at first. It means that when roles are composed into
another type the lists of methods and attributes for adoption are getting flattened down. No exception made for
indirectly consumed roles, like in `role R1 does R2 does R3 {}` case where `R2` and `R3` are the indirect ones.

### `composalizable`

This archetype cannot be composed in directly. But it knows how to produce something that can. We currently have only
one such type: enumeration.

```
enum Maybe <No Yes Dunno>;
class Foo does Maybe { }
say Foo.^roles; # ((Maybe))

my $foo = Foo.new: Maybe => Dunno;
say $foo.No;    # False
say $foo.Yes;   # False
say $foo.Dunno; # True
```

Unless I'm missing something, for this archetype the only requirement is to have method `composalize` on the metaobject:

```
say Maybe.^composalize.HOW.^name; # Perl6::Metamodel::ParametricRoleHOW
```

### `parametric`

This is another kind of 'incomplete type', in "addition" to the `generic` above. But contrary to the latter, parametrics
are types on their own. The big difference is that sometimes parametrics may require additional bits before it can be
used. Though sometimes they may not.

The most familiar kind of incomplete parametric is, once again, a role:

```
role R[::T] {}
```

But even non-parameterized version of it `role R {}` is still a parametric type.

### `augmentable`

This marks types that can be augmented. There is barely a lot to be added to this definition.

# Let's Wrap It Up

To be honest, in the past it took me some time before I got to understanding the concept of archetyping. Though no
wonder because it was my first year with Raku in general. But the memories of how baffling it used to be are still
alive. Hopefully, the information here would help somebody spend less time roaming over the source code while
deciphering the intentions of its creators.

Just one topic I'd like to get back to before we call it a day.

It is possible that the example of nominalizables is not fully convincing and the idea of dynamic mixing in of
corresponding archetype-representing roles into the metaobject would still look appealing. Here is how I see it: perhaps
it would work, but doesn't necessarily makes sense.

I never spent enough time to mind-model this case. If there is sufficient bravery in someone to give this approach a try
– I'd be interested in seeing the experiment outcomes. And if they are great – don't blame the inventors of the current
approach. Look at the historical context: back then Perl6 was under-optimized. A lot of operations that we consider
rather cheap nowadays, including type matching which got significant gains with the introduction of new-disp, were major
performance killers back then. It's hard to recall now where I read about it, but mixins were among those costly ops.

---
{:footnotes}

[^role_kinds]: Or interfaces, or whatever other terms languages can use.

[^class_not_always_instantiable]: One could point at `Nil` which can't be instantiated because `Nil.new =:= Nil`.
    But this is just a trick `Nil`'s `new` method does. It is currently possible to create an instance of `Nil` with
    `bless` or `CREATE` methods. Though I've no idea what use could it has.

[^enum_create]: For enums it is also possible to do `enum FOO <...>; say FOO.bless.WHICH;`. But this would be about
    punning too and is likely to produce something rather unexpected at first. Yet, we have instances of enums in a
    form of pre-existing objects, but there is no legal way to create one manually.

[^undocumented]: Please, tell no one I shared this method name with you! It's undocumented, and unspecced, and not
    guaranteed to stick around forever.

[^meth_compose]: Will be discussed in the next article of the series.

[^and_new_syntax]: And, perhaps, some new syntax to use it. But this subject goes far beyond this article's scope.