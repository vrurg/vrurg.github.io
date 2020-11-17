---
title: The Report On New Coercions
tags: Raku MOP core
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
The Merge of [PR 3891](https://github.com/rakudo/rakudo/pull/3891) completes my work on new implementation of coercion
in Rakudo. When I was starting with it my only intention was about to find a task to distract me from some problems I
was having at the time (nothing serious yet bothersome and stressful). There was no concrete plans on my hands, so I
picked one of the oldest tickets in Rakudo issue tracker. It was 
[issue #1285](https://github.com/rakudo/rakudo/issues/1285) 
which looked quite promising as I already had some knowledge about parameterized roles internals. No doubts, I noticed
Jonathan's comment stating:

> there's no reason this can't be made to work at some point in the future. It's just not entirely trivial to get there.

Ok, I said to myself, he is a busy men for whom time is even pricier luxury than it is to me. I can probably do it in a
week or two!

It's always easy to guess what comes next: I was a way too naïve one; but this is for the better, as it turns out.

Anyway, back to the business. As the information about what's been done by the merge is spread across commits, [related
problem-solving ticket](https://github.com/Raku/problem-solving/issues/227), and the PR itself, I'm intended to gather
and summarize here all information about the changes for further use by those who plan to formalize it in the
documentation or use in their code.

# Types

The old coercion type object is a kind of ephemeral thing. You get one when declare something like `Foo(Bar)`, but there
is no much use in it and it is barely available for user disposal. Basically, all support of coercions was focused on
handling parameters up to the point where `Parameter` class had special attributes for this; and parameter binding code
was actually implementing the functionality. A coercion type object existed and was backed by `Metamodel::CoercionHOW`,
but it was actually and mostly re-delegating to `Mu`.

## The New Coercion Type

The new coercion type objects are in a way resemble definites (`Foo:D` notation backed by
[`Metamodel::DefiniteHOW`](https://github.com/rakudo/rakudo/blob/master/src/Perl6/Metamodel/DefiniteHOW.nqp)).  First of
all, aside of being _coercives_ they're _nominalizables_ (**NB** both terms are part of [_archetypes_ concept of
MOP](https://github.com/rakudo/rakudo/blob/master/src/Perl6/Metamodel/Archetypes.nqp)). Roughly saying, for those who is
not familiar with this concept, a _nominalizable_ type is one which wraps around another type and implements additional
properties. Consider, for example, `subset Foo of Int` or `Int:D`. For both of them `.^nominalize` method will return
`Int`. Moreover, the general plan is to have all nominalizables fully transparent when nested. In other words,
`Foo:D.^nominalize` will result in `Int` too even though it is a definite atop of a subset.

Same applies to the new coercions. Whichever one you use, would it be `Int(Rat)` or `Int:D(Str)` – both nominalize into
`Int`. In the second case it is done indirectly, via nominalization of the target type `Int:D`.

A coercion could also be of a _generic_ archetype too. This happens when it is defined via a type capture:

```
role R[::T] {
    method foo(T(Str) $v) {
        say "V: ", $v.WHICH;
    }
}
R[Int].new.foo("42");       # V: Int|42
my \how := R.^candidates[0].^lookup('foo').signature.params[1].type.HOW;
say how.^name;              # Perl6::Metamodel::CoercionHOW 
say how.archetypes.generic; # 1
```

Contrary to the old implementation, new coercions delegate to their nominal type:

```
class Foo {
    method foo {
        say "here we go!";
    }
}
Foo().foo; # here we go!
```

Previously, the `.foo` line would result in _No such method 'foo' for invocant of type 'Foo(Any)'_.

Now, lets try the following:

```
Foo().new; # You cannot create an instance of this type (Foo(Any))
```

The reason for this to fail would become clear if we add `say self.^name` to the method `foo` and try the previous
example again. We would see than that the method invocant is not `Foo`, as some may expect it, but it's the coercion
`Foo(Any)` itself. So, what actually happens when we invoke `new` is that it tries to instantiate `Foo(Any)` and fails
the same way as it would do with `Int:D.new` or `UInt.new`.

At some point I was even considering making it possible to unwrap nominalizables and make it possible to create
instances of their nominalization indirectly. But this feature has a great potential of confusing a Raku programmer,
especially inexperienced one, and be helpful in concealing potential problems in code. So, the idea was dropped.

_I'm thinking of adding a new smiley alongside with `:U` and `:D` – `:C` which would stand for coercion types. This
would allow declarations like `method new(::?CLASS:C:) { ... }`. But it's not certain if there is really any value in
such addition aside of allowing a user to instantiate coercions manually. Besides and most likely this would also
require changes to multi-dispatch implementation._

Another outcome of coercions being a first-class type objects is that they currently support sensible smartmatching:

```
Int ~~ Int(Str)  # True
Str ~~ Int(Str)  # True
Num ~~ Int(Str)  # False
Int(Str) ~~ Int  # True
Int(Str) ~~ Str  # False
```

There could be a confusion though when one tries `Int ~~ Int:D()` which results in `True`. To explain why it's a correct
outcome, lets try to be more specific with `Int ~~ Int:D(Str)` example. This one results in `False` as expected. Now, if
we get back to the first one, we'd need to mentally unwrap `Int:D()` into it's verbose form and note that it actually
stands for `Int:D(Any)`. Apparently, `Int ~~ Any` and thus it can be accepted by the coercion.

## Coercion Protocol

I could've stopped there. But since I was on the track already, it was hard to get around two other problem-solving
tickets: [#22](https://github.com/Raku/problem-solving/issues/22) and
[#137](https://github.com/Raku/problem-solving/issues/137). To give a quick introspection into the tickets, I'd say that
both are discussing different aspects of the following problem:

```
class Foo {...}
sub bar(Foo(Int) $v) {...}
```

The old coercions require a method named after the target type to be implemented by the constraint type. Unfortunately,
this makes the above coercion impossible because there is no way we can provide a method for each and every 3rd party
class wishing to be a coercion target. Think of all possible variations of `Object` class defined in public and private
modules!

Skipping all the discussions and intermediate variants, here is what I came up with eventually.

First of all, the coercion protocol is implemented by `Metamodel::CoercionHOW::coercion()` method. It means that the
protocol is now publicly available. `say Str(Rat).^coerce(3.14).raku` will now give you a string.

The protocol itself consist of the following steps:

- First we look up a method named after the target type on the constraint type. This is the behavior we always had. The
  interesting part, by the way, is that this method supports compound class names with both the old and the new
  implementation:

  ```
  class A::B { }
  class Foo { method A::B { A::B.new; } }
  sub foo(A::B(Foo) $v) { say $v.raku }
  foo(Foo.new); # A::B.new
  ```

- If there is no method found at the first step then the protocol looks for `COERCE` method on the target type which
  signature would accept the value we're trying to coerce.

  ```
  class IntContainer {
      has Int:D $.value is required;
      proto method COERCE($) {*}
      multi method COERCE(Int:D $i) { self.new: :value($i) }
      multi method COERCE(Str:D $s) { self.new: :value($s.Int) }
  }
  sub foo(IntContainer(Any) $v) { say $v }
  foo(42);   # IntContainer.new(value => 42)
  foo("13"); # IntContainer.new(value => 13)
  foo(pi);   # Impossible coercion from 'Num' into 'IntContainer': no acceptable coercion method found
  ```

  Note that we don't have a candidate for `Num`, thus the last error.

- If no acceptable `COERCE` found then the protocol falls back to the target type nominalization `new` method and tries
  to find a candidate in the same way as it was trying for `COERCE`.

  ```
  class IntContainer {
      has Int:D $.value is required;
      multi method new(Numeric:D \v) { self.new: :value(v.Int) }
      proto method COERCE($) {*}
      multi method COERCE(Int:D $i) { self.new: :value($i) }
      multi method COERCE(Str:D $s) { self.new: :value($s.Int) }
  }
  sub foo(IntContainer(Any) $v) { say $v }
  foo(42);   # IntContainer.new(value => 42)
  foo("13"); # IntContainer.new(value => 13)
  foo(pi);   # IntContainer.new(value => 3)
  ```

Let me elaborate on some interesting and important details of the protocol.

### Return Values

The above code snippets provide the correct ways of implementing `COERCE` method. The key point I'm referring to in here
is the use of `self` to instantiate the resulting object. Let me show you why this is important:

```
class Foo { method COERCE($) { Foo.new } }
class Bar is Foo { }
sub bar(Bar() $v) { say $v.raku }
bar("oops"); # Impossible coercion from 'Str' into 'Bar': method COERCE returned an instance of Foo
```

Hopefully, the error message makes the situation clear: the coercion expected a `Bar` (or, for that matter, a subclass
of `Bar`) instance but got `Foo` instead. Apparently, `Foo !~~ Bar` and this is clearly an error. It is rather easy to
overlook such situation while developing a class because most of the time what we test would be something like:

```
class Foo { method COERCE($) { Foo.new } }
sub bar(Foo() $v) { say $v.raku }
bar("oops"); # Foo.new
```

It is also important to remember that no matter which way we've got our coerced value, it is always a subject for
typechecking. Therefore, something like `method Bool { 1 }` is an error too.

### Exception throwing

Coercion errors are checked by `^coerce` method. If anything goes wrong it throws `X::Coerce::Impossible` exception. If in the
above throwing example we replace `bar("oops")` with `Bar().^coerce("oops")`, the outcome would be the same.

In a rare situation, when the class `X::Coerce::Impossible` is not available for the metaclass code, instead of throwing
the exception object it would just die with `nqp::die` opcode. But this case is unlikely to be of any interest for
anyone but core developers.

### Submethods

Coercion protocol doesn't imply a limitation on use of either methods or submethods for its implementation. But
depending on which one is used it's behavior may have different outcomes. Consider this example:

```
class C1 {
    method COERCE(\v) {
        say "C1::COERCE";
        self.new
    }
}
class C2 is C1 {
    submethod COERCE(\v) {
        say "C2::COERCE";
        C2.new;
    }
}
class C3 is C2 { }

sub c1(C1()) { }
sub c2(C2()) { }
sub c3(C3()) { }

c1(1); # C1::COERCE
c2(2); # C2::COERCE
c3(3); # C1::COERCE
```

The difference is apparent for anybody with clear understanding of submethods. For anyone alse my advise would be to
stick with [multi-]methods. Yet, note the use of `C2.new` in the submethod. It is safe to be done that way for the exact
reason of the submethod not ever be called for any other target but `C2`. Anyway, I would insist on using `self` even
within a submethod because, if at some point you decide to convert it into a method, this simple approach may spare you
minutes or even who knows how many hours of locating the error.

# Scalars

Briefly:

```
my Int(Str) $v;
$v = "42";
say $v.WHICH; # Int|42
```

Same applies to attributes:

```
class Foo {
    has Int(Str) $.value;
}
```

This is done via `Scalar` functionality and consequently available anywhere a containerization is used:

```
my Str() %h;
%h<foo> = pi;
say %h<foo>.WHICH; # Str|3.141592653589793
```

# Bugs

One I found while writing this post:

```
sub factory(::T) {
    my sub (T $v) { say $v.WHICH }
}
factory(Int(Str))("42"); # Str|42
```

The other version of this example works as expected:

```
sub factory(::T) {
    my sub (T(Str) $v) { say $v.WHICH }
}
factory(Int)("42"); # Int|42
```

Another problem is caused by the order of things in parameter binding code. I expected this bug to be there, but did not
feel ready to mangle with it. So, consider this intentional but temporary situation:

```
class Foo {
    method COERCE(Any:U \v) { self.new }
}
sub foo(Foo:D() $v) { say $v.WHICH }
foo(Int); # Parameter '$v' of routine 'foo' must be an object instance of type 'Foo:D(Any)', not a type object of type 'Int'.  Did you forget a '.new'?
```

Perhaps, to fix it would be sufficient to move the coercion block higher in `src/Perl6/bootstrap.c/BOOTSTRAP.nqp`,
`bind_one_param` subroutine? Not sure. Maybe some of you, reading this, can have a look and find the right solution. I
mean, one way or another, but the definedness check must be done _after_ coercion, not before. Unfortunately, I feel
like requiring some rest of this subject and taking care of some other tasks I was postponing all these weeks.

# Coercing Into Enumerations

This works now:

```
enum E <a b c>;
sub foo(E:D(Int) $v) {
    say "Got: ", $v, " of ", $v.^name;
}
foo(1);
```

# Better Handling Of Undefined Numerics

This was a side effect of getting `Int() == 0` to work as it is specced (a long boring story, not worth telling). Now
for code like `Int == 0` instead of

```
Invocant of method 'Bridge' must be an object instance of type 'Int',
not a type object of type 'Int'.  Did you forget a '.new'?
```

one would see a more user-friendly variant:

```
Use of uninitialized value of type Int in numeric context
```

# END {...}

28 commits and 31 changed file. Hours and hours of compilations and spectesting - I praise my recently bought HP Z840
workstation with 28 cores/56 hyperthreads, it spared me a lot of time. It was the distraction I needed. Perhaps even too
much of it. 🙂 It's now time to move on to something different. More articles in [Advanced Raku For Beginners](/arfb),
perhaps?  Will see...
