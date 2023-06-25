---
title: Roles Or When One Is Many
tags: Raku
categories: ["ARFB", "Publications"]
logo: /assets/images/Camelia-200px-SQUARE.png
---
A thing which puts [Raku](https://raku.org) pretty much apart from Perl is that
Raku avoids magic.  There are a couple of places where one could say: "it
happens magically". But a closer look usually reveals rather well-explainable
mechanics behind the behaviors. It's like watching illusionist tricks: we always
know that there are explanations and that they are certainly logical.

Thus, I have a trick for you. Look at the code and tell me: how many roles do
you see here?

```
role R[::T] { has T $.a; }
class C does R[Int] { }
```
<!--more-->

The intuitive answer is, of course,1. And it's true. But a part of the trick
here is substitution of terms: where the word "role" is used the more accurate
term would be "role type object". Now, try to guess the right answer. And, be
sure, it's more than one.

# How's Raku Magic Is Not Magical

One of the greatest virtues of Raku, which I learn to value more and more over
time, is that it does everything to remain logical. Sometimes this doesn't mean
being intuitive. Some behaviours may even confuse beginners at first.  But, when
explained, the logic is usually quite persuasive. The extensive set of
introspection tools, provided by Raku, often helps a lot in understanding it. In
this article I'd try to demonstrate how to use some of the tools in a way a
"magician" demonstrates the devices it is using to turn a single rabbit into
many.

I will also heavily rely on [Rakudo](https://rakudo.org/) implementation of Raku
which is based upon
[NQP](/arfb-publication/02-everything-is-an-object-mop/#rakudo-nqp-runtime-vm-and-implementation-stack),
making it rather easy to look behind the curtain of Raku syntax in some cases.
By the way, this is another reason why the amount of magic in Raku is at
negligible levels. How many of you, my readers, ever looked into the sources of
Perl or whatever is your favourite language? If I answer for myself then it
would be one word: never. Even though C was my language of choice for years. But
now I would insist on you doing `git clone https://github.com/rakudo/rakudo.git`
somewhere under your home directory, where all other projects are kept. Then, as
soon as you get a question, there is a good chance the answer is in a file in
_src/Perl6/Metamodel_ directory of Rakudo project.

# Quadrinity
I had to google this word. "Trinity" is familiar to me since the first Matrix
movie, but not the others from this row. Yes, the word is the answer to the
tricky question. A Raku role is a *quadrinity*. This article will step by step
tell you why.

At this point I'd like to remind that general knowledge of introspection and
Raku metamodel would be very beneficial. Some information can be found in the
previous articles of this [cycle](/arfb.html), some in
[the Raku documentation](https://docs.raku.org).

## Step 1. Multiplicity
Let's start with the most simple introspection:

```
⇒ raku -e 'role R[::T] { }; say R.WHAT'
(R)
```

*Don't be confused with the '⇒' character, it's just my favorite command line
prompt.*

Note that we only use square brackets to declare the role, not to invoke a
method on it. Also note that the role reports itself as just `R`; again, no
square brackets involved.

Next, you probably already know that in Raku it is possible to have different
variants for the same role:

```
⇒ raku -e 'role R[::T] { }; role R { }; say R.WHAT'
(R)
```

We have two declarations but still only using `R` to call `WHAT`.

Let's change the point of view and see how the role is implemented:

```
⇒ raku -e 'role R[::T] { }; say R.HOW.^name'
Perl6::Metamodel::ParametricRoleGroupHOW
```

Notice the `Group` part of the name. Newbies may get confused about the word as
long as they only use one variant of a role. But when they get to the point of
the second example in this section, things are starting to become more clear.
Let me make them more confusing again:

```
role R[::T] { method foo { 42 } }
role R { }
say R.^lookup('foo');
```

What would you expect this code to output? Doing it on a class gives rather
predictable result, according to [the
documentation](https://docs.raku.org/routine/lookup):

```
class Foo { method foo { } };
say Foo.^lookup("foo"); # foo
```

Now, forget this experience. Because for `R` in the above example we will get
`(Mu)` meaning that no method was found!

At this point I'd step back a little. If you read Raku documentation or a book
and done the part about roles and parameterization, one detail might strike you
as something rather familiar. If it's the same "something" I'm going to point at
then you're not mistaken: *parameterization* is about *parameters*; and where
are parameters, then there are signatures! Now this code must be making full
sense of it:

```
role R[Int:D $a, Str:D $b] { ... }
```

The fact that the part of role declaration enclosed by the square brackets is a
signature has another meaning to which I'm going to get back later.

Unfortunately, I'm writing this article a little bit out of schedule and it
should have been done after a couple of more basic subjects are covered. For
this reason I apologize for a small digression following.

### Multi-dispatch
One can find this
[section](https://docs.raku.org/language/glossary#Multi-dispatch) in Raku
documentation. [Another section](https://docs.raku.org/syntax/multi) elaborates
on the syntax and functionality. But I'd like to lightly touch the internal
implementation of the feature. Let's start with a basic declaration:

```
proto foo(|) {*}
multi foo(Int:D $i) {}
multi foo(Str:D $s) {}
say &foo.raku; # proto sub foo (|) {*}
```

As you can see, the  `raku` method reports only the `proto`. Also, if we invoke
`is_dispatcher` method on `&foo` it will return `True`. Ok, but where are the
two `multi` and what happens when we call `foo("bar")`? In two words, Raku will
first find the `proto` method. If it recognizes it as such by inspecting the
return value of `is_dispatcher`, then it takes the list of known candidates by
calling `&foo.candidates`:

```
say &foo.candidates.map(*.raku).join("\n");
# multi sub foo (Int:D $i) { #`(Sub|140560053018928) ... }
# multi sub foo (Str:D $s) { #`(Sub|140560053019072) ... }
```

And then it tries to bind the supplied parameters to signature of each
candidate. Where binding succeeds that candidate is called (or an exception is
thrown if none can be found).

Apparently, in the real life things are somewhat more complicated, but we don't
need to know this yet...

### Back To The Multi-Role
Sometimes I feel weird about not being able to recurse into a sub-subject in
plain text of an article. Just consider the header of this section as a `return`
statement from the previous section... Ah, nevermind!

Well, what was my point about telling the story of multi-dispatching? When we
see that `R.HOW` reports a `Group` in the class name, it is OK to draw a
parallel with the `proto` in multi-dispatching implementation. As a matter of
fact, the type object `R`, on which we invoke the `HOW` method, is an
umbrella-kind of entity, representing all variants of the role under its common
name. And, when one applies `R[Int]` to a class, then the process which actually
takes place is a kind of multi-dispatch, where Raku tries to match the
parameter(s) in square brackets to the signatures of role candidates. And akin
to how we list the candidates of `&foo`, we can also list the candidates of `R`:

```
say R.^candidates.map(*.^name).join(", "); # R, R
```

The only difference is that this time we use a meta-method `.^candidates`.

At this point there is one mystery remains uncovered. Remember the example with
`.^lookup`? Why does it fail to find the method?

The type object backed by `Perl6::Metamodel::ParametricRoleGroupHOW` is not a
role we can actually use. It neither has methods nor attributes. Yet, under
certain circumstances, we may want it to pretend to be a full fledged role. To
do so it chooses one of its candidates as the default one and then re-dispatches
outside requests on it.  When there is a candidate with no signature (as
our `role R {}`), it becomes the implicit default. Otherwise the first declared
signatured candidate becomes one.

Getting back to our example, `R.^lookup('foo')` fails because `role R {}`
doesn't declare a method with the name.

## Step 2. Candidates
Straight to the point, let's introspect the candidates themselves:

```
say R.^candidates.map({ .HOW.^name }).join(", ");
```

This must look almost familiar except that we've added `.HOW` call. Here is what
we get with it:

```
Perl6::Metamodel::ParametricRoleHOW, Perl6::Metamodel::ParametricRoleHOW
```

It also looks familiar except... Yes, there is no `Group` in the class name and
I'd like to welcome our second kind of role! Actually, we know it already. If I
wave my hand like _this_ and distract my spectators with...

Oops, the last sentence was supposed to land in another window! For you, my
audience, I have another line of code:

```
role R {}.HOW.^name.say; # Perl6::Metamodel::ParametricRoleHOW
```

BTW, it's a good example of the ubiquitous Raku concept of everything being an
object. Even a declaration is; and, just for fun of it:

```
{ say "foo" }.^name.say; # Block
```

But I got distracted...

So, what really matters here is that when we declare a role Raku creates an
instance of `Perl6::Metamodel::ParametricRoleHOW` class for us. Each declaration
is backed by a distinct instance of the class which is responsible for holding
every detail of the role type object. For example, to find out if it can be
parameterized one can do:

```
sub is_parameterized(Mu \r --> Bool) {
    ? r.^signatured
}
say is_parameterized(role R[::T] {}); # True
say is_parameterized(role R {}); # False
```

_**Note** that because `signatured` is a method implemented in NQP it doesn't
know about high-level types and returns either `0` or `1`. Sometimes the
situation gets even worse. The `lookup` metamethod I mentioned above actually
returns `nqp::null()` which is a VM-level kind of object. It must never appear
at Raku-land. Therefore the language turns it in `Mu` which is the most basic
Raku class._

There is little to say about `Perl6::Metamodel::ParametricRoleHOW` at this
point. But we will get back to it somewhat later.

## Step 3. Uncertainty
To get closer to our third kind of role we start with the following snippet:

```
role R1[::T Stringy, ::V] { method foo { "stringy" } }
role R1[::T Numeric, ::V] { method foo { "numeric" } }
my \r = role R2[::T] does R1[Int, T] { }
```

Let's introspect `R1`:

```
# We know there is only one role,
# hence .head for prettier output
say r.^roles.map({ .^name ~ " of " ~ .HOW.^name }).head;
# R1[Int,T] of Perl6::Metamodel::CurriedRoleHOW
```

The output reveals two apparent changes. First, the role name now reports its
parameters. Second, the metaobject is now of class
`Perl6::Metamodel::CurriedRoleHOW`. This is another kind of "magic" Rakudo does
behind the scenes which I'm going to disclose in this section.

What is the most  noticeable feature of `R2` declaration in the above example?
The fact that where it consumes `R1` we only know the first parameter whereas
the second one remains a generic. To represent this state of things where our
knowledge about roles is incomplete Rakudo uses _curried_ ones.

From the point of view of origin, the key distinction of curried roles from the
previous two kinds is that there is no way to _declare_ one. A currying can only
be a result of _parameterization_ of a group. And, actually, I'm well aware that
formally group doesn't have a representation in Raku syntax. But as soon as it
comes out as a result of the first role declaration we could say it is produced
with it.  Whereas curryings are created by parameterizations exclusively.

Perhaps somewhat surprisingly, but a currying can also be found in cases where
all parameters are well-known to the compiler:

```
say R2[Str].HOW.^name; # Perl6::Metamodel::CurriedRoleHOW
```

Partly this is because when we use a role like this all we need of it are
perhaps some introspection, type checking, or any other kind of operation which
do not require a concrete object. For example:
```
sub foo(R1[Int, Str] $a) {...}
```

All we need here is `foo` parameter to pass type checking against `R1[Int,
Str]`. And because a currying will do the job for us, Rakudo is using it here:

```
say &foo.signature.params[0].type.HOW.^name;
# Perl6::Metamodel::CurriedRoleHOW
```

This is because:

```
say R2[Str] ~~ R1[Int, Str]; # True
say R2[Int] ~~ R1[Int, Str]; # False
```

But there is one more, primary reason. It will be disclosed in the following
section.

## Step 4. Concreteness
The destiny of any role is to be consumed by a class. _(BTW, punning is not an
exception here.)_ The time has come to consider this final stage:

```
role R1[::T] { }
role R2[::T] { }
role R3 { }
class C does R1[Int] does R2[Str] does R3 { }
```

By introspecting the class we will meet all the old friends:

```
say C.^roles
     .map({ .^name ~ " of " ~ .HOW.^name })
     .join("\n");
# R3 of Perl6::Metamodel::ParametricRoleGroupHOW
# R2[Str] of Perl6::Metamodel::CurriedRoleHOW
# R1[Int] of Perl6::Metamodel::CurriedRoleHOW
```

Interestingly enough, we find a mixture of different kinds of roles here. The
reason for this is floating atop: contrary to `R3` two other roles are
parameterized.

But since I love to confuse the audience, I will tell you this: those are
actually not the roles the class is built from!

Sure thing, this is another manipulation. The full phrase must be using this: _"not the
directly used roles"_.

When we try another approach the picture is going to be quite different:

```
say C.^mro(:roles)
     .map({ .^name ~ " of " ~ .HOW.^name })
     .join("\n");
# C of Perl6::Metamodel::ClassHOW
# R3 of Perl6::Metamodel::ConcreteRoleHOW
# R2 of Perl6::Metamodel::ConcreteRoleHOW
# R1 of Perl6::Metamodel::ConcreteRoleHOW
```

The difference between `.^roles` and `.^mro` is that the former is providing us
with what is used to declare a class; whereas the latter gives us what it is
actually built with.

As the name of `HOW` class implies, we now deal with concrete representation of
the roles. In other words, this is the kind of roles for which _all_ details are
known and they were _specialized_ for this particular class. The emphasis is
there on purpose: the process is called _specialization_; and `specialize` is
the name of the metamodel method which implements it.

I would also remind you about the last sentence of the previous section. The
reason why whenever one uses `R[Int]` or a similar form of role parameterization
they deal with a curried role is because full specialization requires the class
the role is consumed by. Later I will show why.

We can now take a step back and overview the lifecycle of a role:

1. A `Perl6::Metamodel::ParametricRoleGroupHOW` is created.
2. A `Perl6::Metamodel::ParametricRoleHOW` is created and added to the group.
3. A class is declared and `does` the role. The compiler tries to parameterize the role and `Perl6::Metamodel::CurriedRoleHOW` is created if the parameterization is needed; otherwise the original `Perl6::Metamodel::ParametricRoleHOW` is used.
4. The result of the parameterization is added to the class' list of roles.
5. When class is composed all roles added at the previous step are getting specialized with their respective parameters and the class type object. At this point we get role type objects backed by `Perl6::Metamodel::ConcreteRoleHOW` or, in other words, role concretizations.
6. The concretizations are added to the class.
7. Concretizations are applied by migrating their attributes and methods into the class type object.

It worth noting that concretizations are kept as separate entities, apart from
the the roles they're produced from. This is what we observed above by
introspecting with `.^roles` and `.^mro`. They can also be accessed using
`.^concretizations` metamodel method:

```
say C.^concretizations
     .map({ .^name ~ " of " ~ .HOW.^name })
     .join("\n");
# R3 of Perl6::Metamodel::ConcreteRoleHOW
# R2 of Perl6::Metamodel::ConcreteRoleHOW
# R1 of Perl6::Metamodel::ConcreteRoleHOW
```

At this point there are two rather big subjects remain intentionally unclear:
how a role candidate is chosen? and what does specialization do? The first one I
could probably cover more or less in full. The second one is way too complex for
this article, but a few key points are definitely worth mentioning.

## Step 1a. The Choice
Shocking an innocent reader is very popular among media. And though I'm barely a
journalist, to say at least, but as long as I call this text an article - who am
I to break the rules? So, sit tight and hold your brains.

Here we go... Ready or not... The truth is about to be revealed!

_A role is a routine._

Good, here it goes. I said it! I always wanted to say it!

Seriously, as it often turns out about clickbaiting news, this is not fully
true, but there is a point. I'd like you to consider an example:

```
role R {
    say "inside the role";
}
module Foo {
    say "inside Foo";
}
class C {
    say "inside the class";
}
# inside Foo
# inside the class
```

We only see two lines of output what gives us an idea of the class declaration
behaving identically to module. But not the role. Let's add one more line to the
example:

```
R.^candidates[0].^body_block.(C);
# inside the role
```

Why is it so and why I pass `C` as a parameter I will try to answer in the
section on specialization below.

For now I propose to introspect the body block, but first add one more variant
of the role to the above snippet:

```
my \r = role R[::T, ::V Numeric] { }
say r.^body_block.raku;
# multi sub (::$?CLASS ::::?CLASS Mu $, ::T Mu $, ::V Numeric $) { #`(Sub|94052949943024) ... }
```

Does it ring a bell now? The word `multi` before `sub` tells it all, and my job
now is reduced to the minimal required wording.

When the compiler builds a role group it also creates a multi-dispatch routine.
Internally it is called _selector_. Of the every newly added parametric role its
body block (which is actually a `multi sub`) is taken and added to the selector
as a multi-dispatch candidate.  Now, when one writes something like `R[Int,
Str]` in their code the compiler uses multi-dispatch to pick a routine
candidate. Based on the result, it finds the role to which the matching
candidate block belongs.

So, it must now make much more sense when we mention a role signature. Because
it **is** a signature, as a matter of fact. If I to re-word a role declaration `role
R[::T, ::V] {}` in somewhat more human-programmer-readable way, it might look
like:

> Declare a candidate role `R` with body block `sub (::T, ::V) {...}`

### A Bit Of Cold Shower

So far, so good. But there is a catch: named parameters.

**NOTE** that this section describes the implementation of Rakudo compiler
2021.06 release. The situation might change with a future compiler release.

Consider a declaration:

```
role R[Int ::T] { method foo { say "none, Int" } }
role R[Int ::T, Str:D :$desc] { method foo { say "desc:", $desc } }

class C1 does R[Int, desc => "sss"] { }
class C2 does R[Int, desc => "sss"] { }
class C3 does R[Int] { }
class C4 does R[Int] { }
```

First thing to try is to see if roles are chosen correctly:

```
C1.foo; # desc:sss
C3.foo; # none, Int
```

Looks like it. But this is where the good news ends:

```
say C1.^roles[0] =:= C2.^roles[0]; # False
say C3.^roles[0] =:= C4.^roles[0]; # True
```

What the above output means is that as soon as one uses a named parameter the
compiler will be creating a new currying for each new parameterization, despite
of the named argument value passed in. Note how positional-only role candidate
is not affected by the issue.

Whereas the above problem might not be a big deal most of the time, the
following example demonstrates another one, which is more substantial:

```
say R[Int] ~~ R[Int, :desc<sss>]; # True
say R[Int, :desc<sss>] ~~ R[Int]; # True
```

Note how positional-only candidate does the right thing:

```
say R[IntStr] ~~ R[Int]; # True
say R[Int] ~~ R[IntStr]; # False
```

With all this in mind I'd rather advice to avoid named parameters in role
declarations.

Unfortunately, the problem doesn't have a reasonable solution for now because
support for named parameters is not provided by MoarVM implementation of type
parameterization. Was it an oversight, or a deliberate decision - I don't know.
Hopefully, the situation will change when [the new dispatching
mechanism](https://6guts.wordpress.com/2021/03/15/towards-a-new-general-dispatch-mechanism-in-moarvm/)
will arrive to Rakudo, but I'd be giving no promises here. I only believe, up to
my knowledge, that the new dispatching provides ways for a solution to be
implemented.

### A Black Magic Sèance

This section is not really related to the candidate choosing, but I can't stand
not showing you something tricky. Also, in many fiction and fairy tale stories
black magic is something what lets you achieve a goal but with a price tag
attached.  Sometimes the tag is quite a bloody one, but this is not my case
here. And, actually, my goal and the price are the same: I want to intrigue you
with something different.

Here is the spell to cast:

```
use nqp;
my \r = role R[::T, ::V Numeric] { }
class C { }
my \tenv = r.^body_block().(C, Str, Int);
my \ctx = nqp::atpos(tenv, 1);
my \iter = nqp::iterator(ctx);
while iter {
    my \elem = nqp::shift(iter);
    say nqp::iterkey_s(elem), " => ", nqp::iterval(elem);
}
```

As long as the body block is a routine, apparently we can call it ourselves! In
order to understand the remaining lines with all the `nqp::` ops used one would
need to refer to [the NQP ops
documentation](https://github.com/Raku/nqp/blob/master/docs/ops.markdown).

Anyway, the output the "spell" is producing may look like this:

```
::?CLASS => (C)
$?ROLE => (R)
T => (Str)
$?CONCRETIZATION => (Mu)
$?PACKAGE => (R)
::?PACKAGE => (R)
V => (Int)
::?ROLE => (R)
$?CLASS => (C)
$_ => (Mu)
```

In two words, role body block returns an array of two elements. The second
element is a mapping of symbol names into their concrete values. I.e., among the
keys on the left side of the `=>` arrows you can easily spot our `T` and `V`
type captures from the role signature; and compiler constants like `::?CLASS`
and others.

Overall, what the code returns is called internally _type environment_ and
is used in another widely employed mechanism called _generic instantiation_. But
this subject is definitely well beyond this article's purpose. What does worth
mentioning here is that all the symbols included into the environment are
actually role body lexicals. For example, if we add `my FOO = 42` to the body
the above output will have the following line added to it:

```
FOO => 42
```

Also, looking the symbols you can now even better understand why does role
specialization requires a class consuming it. You would probably think about it
next time doing something like:

```
method foo(::?CLASS:D: |) {...}
```

One last thing I'd like to point you at is `$?CONCRETIZATION` symbol which is
not yet documented. It is only available within a role body and role methods and
is bound to role's concretization when it is available. The symbol is mostly
useful for introspection purposes.

##  Step 4a. Specialization
So, we have a candidate. We know the concrete parameters. We know the class
consuming it. Thus, we do know everything to specialize and get a concretization
to eventually incorporate the role into the class consuming it.

As I already mentioned above, specialization is rather complex process. In
Rakudo metamodel implementation it is spread across a couple of source files and
involves some other internal mechanisms like generic instantiation, which I also
hinted about above. I'd better not get into the deep details of it but focus on
the major stages. Those who are really curious can start with method
`specialize` in _src/Perl6/Metamodel/ParametricRoleHOW.nqp_ of Rakudo compiler
sources.

Specializing a new role starts with creating a fresh instance of
`Perl6::Metamodel::ConcreteRoleHOW` and corresponding concrete role type object.
Then body block is invoked to obtain a type environment structure.
I'm going to focus a bit on this. As usual, we take an example first:

```
role R {
    say "inside the role, class is ", ::?CLASS.^name;
    say "class is composed? ", ::?CLASS.^is_composed ?? "yes" !! "no";
}
class C1 does R { }
class C2 does R { }
# inside the role, class is C1
# class is composed? no
# inside the role, class is C2
# class is composed? no
```

What we observe here is that the role body has been invoked twice, it knows the
class it is applied to, and the class is not composed yet (I have some
information about class life cycle in [another
article](/arfb-publication/02-everything-is-an-object-mop/#raku-metamodel)).
Also, as I mentioned it already, the concretization exists at this point:

```
role R {
	say $?CONCRETIZATION.^name; # R
}
```

But it is empty yet:

```
say $?CONCRETIZATION.^attributes.elems; # 0
say $?CONCRETIZATION.^methods.elems;    # 0
```

And, apparently, not composed:

```
say $?CONCRETIZATION.^is_composed ?? "yes" !! "no"; # no
```

All this makes role body a good place to do things needed to be done whenever
the role is actually consumed.

Now, with all the necessary information available, the metamodel finalizes
the specialization by instantiating attributes and methods of the original
parametric or curried role and installing them into the newly created
concretization. For example for this snippet:

```
role R[::T] { has T $.attr }
class C R[Str] { }
```

a copy of `$!attr` attribute object will be created with `Str` in place of
`T`. If we dump attributes of the original role and the concretization we may
see something similar to the following output:

```
role attr: (Attribute|94613946040184 T $!attr)
concretization attr: (Attribute|94613946043184 Str $!attr)
```

When done with attributes and methods any consumed roles are getting
instantiated and specialized. For example, for this declaration:

```
role R1[::T, ::V] does R2[::T] { ... }
```

`R2` will be specialized with whatever is passed in as `T`. The concretization
of `R2` will then be added back to the concretization of `R1`.

And, finally, if there any parent classes added to the role they are
instantiated and added too.

When all the above preparations are done our concretization gets composed.
It is now ready to be added to its consuming class.

And that makes the story end.

# Paying The Debts
It's really relieving to know that long ago given promises were eventually kept.
Unfortunately, to get this subject covered I have jumped over a few other, more
basic ones. For example, it would be beneficial for a reader to get know better
about multi-dispatching, type object composition, and how Rakudo, NQP, and
backend VM are interacting with each other. If I ever write enough articles and
consider making a book out of this material, then the chapter made of this text
will be placed further away from the book beginning.

Anyway, I did my best to keep away from yet untold concepts and hope you found
information here useful.

