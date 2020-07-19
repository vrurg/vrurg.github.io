---
title: "The Metamodel: Introduction To MOP"
logo: /assets/images/Camelia-200px-SQUARE.png
---
In the previous articles I discussed several bits and pieces about Raku
metamodel. I think it is time now to give the subject a little more focus from
the point of view of dealing with it in your Raku code.
<!--more-->

This article may require some deeper understanding of Raku syntax from the
reader. Hope you're getting along well with your new book about Perl6/Raku?

# `HOW` and `.^`

Remember this code?

```
say Int.HOW.^name; # Perl6::Metamodel::ClassHOW
```

I asked to turn _"don't pay attention to `.^name`"_ mode then. Please, turn it
off now! We're going to pay close attention to it!

Apparently I'm not going to repeat the whole [Everything Is An Object. MOP.
](/arfb-publication/02-everything-is-an-object-mop/) article. I would only refer
to the fact that `Int.HOW` gives us the meta-object responsible for class `Int`.
Meta or not, it's an object, right? Hence calling a method on it is possible?

```
say Int.HOW.get_default_parent_type.WHICH; # Any|U140243771192832
```

Yes, possible. Ok! What use in it for us? For example, we can try looking up a
method on our type object:

```
$ raku -e say Int.HOW.lookup("Str");
Too few positionals passed; expected 3 arguments but got 2
  in block <unit> at -e line 1
```

Uh-oh... Houston, how do we make it work?

```
$ raku -e 'say Int.^lookup("Str").WHICH;'
Method|140411629640016
```

One point should now be clear: `TypeObject.^method()` form is a shortcut for
`TypeObject.HOW.method()`. But from the error message above one could conjecture
that there is more about it than just been a shortcut. To understand the error
better let's have a look at the implementation of `lookup`:

```
method lookup($obj, $name) {
    ...
}
```

If you're curious about the magic behind the triple-dot then my suggestion would
be to get through this article first and then look into
[_src/Perl6/Metamodel/MethodContainer.nqp_](https://github.com/rakudo/rakudo/blob/master/src/Perl6/Metamodel/MethodContainer.nqp#L110)
under the Rakudo compiler source directory
[root](https://github.com/rakudo/rakudo). The filename extension gives a hint
about the source been written in NQP.

But otherwise all we need now is the signature of the method. See the `$obj`
parameter? The method expects Raku invocant  in it. I guess this statement may
not be very clear to you yet. But wait a little! Let me show you a couple of
useful tricks from another area of Raku first.

# Role Mixin

_Skip this section if mixins is nothing new to you._

At this point I expect you to know about roles. Better if the knowledge stems
from a Raku/Perl6 book, but average understanding of non-instantiable entities
like interfaces or abstract classes would be ok too.

The point is Raku supports run-time
[mixins](https://en.wikipedia.org/wiki/Mixin) when a concrete object (i.e. an
instance of a class) can receive additional methods and attributes post factum:

```
my $s = "foo" but role { method foo { say "Wow!" } };
$s.foo;
```

Operator `but` in the example is the _mixin operator_. In two words it does the
following:

1. takes the class of the object on its left hand side
2. creates a new class from it with the role from its right hand side applied
3. [re-blesses](https://docs.raku.org/routine/rebless)  the LHS object into the
   new class

Try the following with the `$s` scalar:

```
say $s.WHICH; # Str+{<anon|1>}|foo
```

And then compare to the bare-bone code:

```
my $s = "foo";
say $s.WHICH; # Str|foo
```

Note the difference in the class names. To make it even more evident, let's give
a name to our role:

```
my $s = "foo" but role FooRole { method foo { say "Wow!" } };
say $s.WHICH; # Str+{FooRole}|foo
```

We can go even further and introspect the roles of the object:

```
say $s.^roles.map: *.^name; # (FooRole Stringy)
```

# Class Meta-methods

Raku allows a class to define a method which belongs not to the class itself,
but to its meta-object. The syntax is simple and rather straightforward:

```
class Foo {
    method foo             { say "foo"      }
    method ^meta-foo($obj) { say "meta-foo" }
}
```

We can introspect the class for the methods it has:

```
say Foo.^methods; # (foo BUILDALL)
```

So, is `^meta-foo` is gone? 

```
say Foo.^meta-foo; # meta-foo
```

Of course, not! Lets add some meat to `^meta-foo` (I'll be skipping the wrapping
`class Foo` for all method variations shown below):

```
method ^meta-foo($obj) {
    say self.WHICH;
}
```

```
Foo.^meta-foo; # Perl6::Metamodel::ClassHOW+{<anon>}|140671913152992
```

See the familiar pattern? The example reveals two important facts at once:

1. `^meta-foo` is invoked on a meta-object instance (notice no `U` is following
   the pipe `|`)
2. the type of the meta-object is a class with a mixin

I think at this point it should be clear that when a meta-method is declared on
a class Raku creates a role which contains all the in-class declared
meta-methods and then mixins this role into the meta-object.

Maybe it's a bit too much of distraction from the article subject, but I hope
nobody minds learning a trick or two along the way of the story. Besides, this
way life of beginners gets easier because I don't force them to distract for
seeking for extra knowledge required here and now.

# Specifics of `.^`

Anyway, I'm now getting back on the main highway. The real reason for
introducing the meta-method here is to introspect it's parameters to demostrate
the meta-object protocol in action. In turn it must clarify a nuance which I
often saw people to be confused with. The cause of it is the transition from the
world of user-land Raku into the world of Raku metamodel. Me myself once or twice
made a mistake by explaining `$obj.^foo`  as `$obj.HOW.foo($obj.HOW)`! I didn't
tell, you never saw this...

What happens in reality is `.^` operator invokes a method on `$obj.HOW` and
unshifts `$obj` as the first parameter of the method `meta-foo`. In code
`$obj.^meta-foo(42)` expands into `$obj.HOW.meta-foo($obj, 42)`. We can
visualize it by transforming the method `^meta-foo` into this:

```
method ^meta-foo($obj, $p) {
    say "Parameter 1: ", $obj.WHICH;
    say "Parameter 2: ", $p;
}
```

Then invoke it:

```
Foo.^meta-foo("the param"); # Parameter 1: Foo|U140697711461624
                            # Parameter 2: the param
```

Another mistake is made sometimes by those already familiar with the metamodel
basics. They assume that `$obj` is a type object because most of the time this
is what the metamodel deals with. But this is not true either. Raku doesn't do
any behind the scenes magic and merely bypasses the invocator of `.^` operator
as-is:

```
Foo.new.^meta-foo(13); # Parameter 1: Foo|140282557516320
                       # Parameter 2: 13
```

Again, note the absence of `U` after `|` signalling about a concrete object.

At his point it feels like a poster styled after
[the agitprop](https://en.wikipedia.org/wiki/Agitprop) would be appropriate:

> Metamodel developer, remember! The behavior of your meta-method may depend on
> the invocator-object being concrete or not!

Oh, those horrible memories of a soviet-born child... Oops, sorry, I'm wandering
away! Never again!

# Applicability Of The Metamethod Call Operator

Remember I once mentioned that `Int.HOW.HOW.WHICH` can't be used? It fails with
`X::Method::NoFound` exception.  In two words I can say that `Int.HOW.WHICH`
works because the `Metamodel::ClassHOW` we see in Raku code is a transformed
representation of the originally written in NQP `Perl6::Metamodel::ClassHOW`.
The former inherits from `Any` class as most other Raku classes do. Therefore it
has common Raku introspection methods I mentioned earlier: `WHICH`, `WHAT`, etc.

By going deeper and asking for `Metamodel::ClassHOW` meta-object we receive an
instance of pure NQP class `NQPClassHOW` which lacks the methods mentioned
above. Hence the exception if we try to call any of those methods on it: they're
not implemented by `NQPClassHOW`. This is where `.^` comes to rescue:

```
say Int.HOW.HOW.^name;
```

The operator doesn't rely on any high-level infrastructure and provides us with
direct access to any meta-method at any level. Due to MOP is standartized across
all layers of the metamemodel, `name` method will always have the first `$obj`
parameter and thus will always be accessible via `.^`.

_Note:_ not all methods of meta-classes are implementing MOP. Some are
considered to be _internal implementation detail_ and may have signatures not
compatible to MOP.

If you ever decide to hack with NQP code then you're likely to realize soon that
NQP doesn't have the meta-method call operator. For this reason my fingers
already trained for typing something like this whenever debugging requires to
find out about an object class name inside metamodel code:

```
nqp::say($obj.HOW.HOW.name($obj.HOW)) if nqp::getenvhash<RAKUDO_DEBUG>;
```

# In Conclusion

Raku clearly distinguish operations on data object and meta-operations. While
this statement may sound as a commonplace, it is tempting to consider, say,
`WHICH` to be a meta-operation when called upon `Int` type object. Even though
in fact `Int`, as any other type object, is considered data in this context.
Generally speaking, it's only the presence of `HOW` or `.^` which "turns"
statements into meta-operations. For example, introspecting a class for its
parents:

```
say Int.^mro.map: *.^name; # (Int Cool Any Mu)
```

_Note the use of `.^name` here. In part, I use it here to get plain type object
names without enclosing braces; e.g. `Cool` instead of `(Cool)`. It just appeals
more to my aesthetics this way._

We can also find out what roles Int consumes:

```
say Int.^roles.map: *.^name; # (Real Numeric)
```

Or what methods and attributes it has:

```
say Int.^methods; # ... This results a long list, try it on your own
say Int.^attributes; # (bigint $!value)
```

And many more things. A lot of information can be found at [the documentation
site](https://docs.raku.org) by searching for word
[_metamodel_](https://www.google.com/search?q=site%3Adocs.raku.org+Metamodel).
But even more pearls are concealed in
[🦋&nbsp;Rakudo](https://github.com/rakudo/rakudo) sources. Just put on your
divebugging equipment and plunge into the code! This article only dips a toe
into the waters of Raku metamodel. The introspection is just a tip of the
iceberg.  Most of it is still hiding in the depths, as the most impatient ones
may have already realized.

Phew, it's time to stop all these metaphors before I get sea sickness...

Simply put, my only task for now was to introduce a reader to the basics of
MOP. Some of the upcoming articles will be based on this one to delve deeper
into the subject. Stay tuned!
