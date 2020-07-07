---
title: "Containers And Symbols"
---

I’m not going to be original anyway and gonna start with the most traditional example around:

```
my $foo = “Hello world!”;
say $foo;
```

It shouldn’t be to hard to see that what’s done is a variable declared and then
it is printed to the console (`say` is like `print` but always appends a new
line at the end).

Let’s bring a little useless fun into this snippet. First, start with a couple
of additional lines:

```
my $foo = “Hello world!”;
my $bar = $foo;
$bar ~= “ This is Raku!”
say $foo;
```

Keeping in mind that `~=` is a string append operator, what output do we expect
here? Apparently, it’s

> ```  
> Hello world!  
> ```  

again. So far, so good! But try adding a single colon:

```
my $foo = “Hello world!”;
my $bar := $foo;
$bar ~= “ This is Raku!”
say $foo;
```

and the output becomes:

> ```  
> Hello world! This is Raku!  
> ```  

`:=` is called _binding operator_ and the rest of this chapter I’m going to deal
with explaining of what’s going on in the above example.

# Variables? Not Really.

Even though I used term _variable_ above that wouldn’t be fully correct one to
use. Normally a variable is considered to be a mutable entity. But more
importantly, it is expected to be a name given to a value in memory. In Raku
this is not really a case. Consider, for example:

```
my $foo := 42;
++$foo; # Error: attempt to modify immutable value
```

Not that other languages don’t support immutable variables, but the way things
work in Raku makes it more appropriate to use another term: _symbol_. In other
words, a Raku compiler deals internally with _symbols_ bound to _objects_. The
nature of a object defines how the symbol can be used in a particular context
and wether it can be used at all.

What a symbol is from the point of view of Raku compiler? It is an entry in a
symbol table. Or, in other words, the compiler just knows that such thing as
`$foo` exists. At run time the code also knows what it is bound to. If we
declare a constant:

```
constant FOO = “The Answer!”;
```

it would also be registered as a symbol. Or a subroutine:

```
sub bar { say $foo; }
```

which would get installed as a symbol `&bar` bound to a `Sub` object.

“Good”, you’d say, “but what makes the difference between `$foo = 42` and `$foo
:= 42`?”

# Containers

There is way in Raku to ask what object we get when requesting a symbol. For
example:

```
say $foo.WHAT; # (Int)
```

would tell us that the value behind `$foo` has type `Int`. The braces around the
`Int` in the output is a convention in Raku to denote a type object name.

_Note:_ The [previous article](/arfb-publication/02-everything-is-an-object-mop)
covers some aspects of object introspection in Raku.

Note that in the example above I didn’t specify how exactly `$foo` was
initialized: with assign ( `=` ) operator or binding ( `:=`). This is because
there is no visible difference between the two from the point of view of
`.WHAT`. But we do know that the difference exists! After all, you asked me this
question explicitly at the end of the previous section!

```
my $foo := 42;
my $bar = 42;
say $foo.VAR.WHAT; # (Int)
say $bar.VAR.WHAT; # (Scalar)
```

`.VAR` is what gives us the object our symbol is bound to. `.WHAT` tells us the
type of it. And where binding results in evident `Int` type, assignment
produces a `Scalar` which is something special in Raku. It is a _container_
meaning that objects of this type are supposed to contain a value. Containers
have special support by Raku. In particular, `Scalar` is so transparent that
there is no other way of getting hold of it other than with `.VAR`. And even then
some operations on it would end up applied to the value stored by it! Besides,
there is really no legitimate Raku-only way to create a `Scalar` manually. The
normal state of the things is when it is created for us by the compiler when
necessary. In the example above, this is what happens when `$bar` is declared.

At this point I can give more clear definion of the difference between the
assignment and binding operators when used outside of a symbol declaration:

* the binding operator `:=` is handled by the compiler directly by associating
  (binding) a symbol with an object
* the assignment `=` tells the compiler to generate code which would take the
  value from operator's right hand side and store it into the container on the
  left hand side

_Note_ that in the latter case if the object bound is not capable of storing
something our program will terminate with a error. Roughly, this is what happens
when we try `$foo := 42; ++$foo;` because `++` acts similarly to `=` and tries
storing `43` back to `$foo`.

At this point we can get back to the first example, where the binding operator
is first seen:

```
my $bar := $foo;
```

Because binding is handled by the compiler directly, the code it produces
doesn’t go deep but takes what `$foo` points at and binds it to `$bar`. In our
case it happens to be a `Scalar` object. As a result of this binding we end up
with `$foo` and `$bar` actually referencing the same things! Therefore, when we
append a string, we alter the scalar container content and the modification is
then available via either of the two symbols! Simply put, `$foo` and `$bar`
became aliases for the same scalar.

To demonstrate the difference between a symbol and a container, let me use
another example:

```
my $foo = “this is foo”;
my $bar = “this is bar”;
my $baz := $foo;
say $baz; # this is foo
$foo := $bar;
say $foo; # this is bar
say $baz; # this is foo
```

At the first glance it could be counter-intuitive for a beginner. We bind `$baz`
to `$foo`, next we bind `$foo` to `$bar` – then why `$baz` did not change?
Exactly for the reason that the compiler binds a symbol to a container (to an
object in general), not to another symbol. Thus, `$bar` remains bound to the
container with the string _”this is foo”_ while `$foo` is re-bound to the
scalar containing _”this is bar”_.

# More Containers And Interactions

`Scalar` is not the only container type provided by Raku. Consider this code
snippet:

```
my @a = [1, 2];
my %h = a => 1, b => 2;
say @a.VAR.WHAT; # (Array)
say %h.VAR.WHAT; # (Hash)
```

The `Array` and `Hash` are container types too. There is one specific container
type named `Proxy`, but I better leave it for another article.

One important property of containers is that they may contain each other. For
example:

```
my $a = [1, 2];
say $a.WHAT;      # (Array)
say $a.VAR.WHAT;  # (Scalar)
say $a;           # $[1, 2]
```

Mind the `$` sign before the opening square bracket in the last line. It signals
that the array is containerized in a scalar. This is important to know because
depending on context Raku might handle the array differently. A situation when
this happens often comes as a surprise even to not so beginners:

```
my @a;
my $foo = [1, 2];
@a = $foo;
say @a.elems; # 1
```

Oops, we found a bug?! Of course not. Because when the assignment to `@a`  finds
a scalar on the right hand side it considers it as a single value. Printing `@a`
would result in:

```
[$[1, 2],]
```

When array-to-array assignment is required it could be achieved in several ways
(remember, TIMTOWTDI!). One is to use de-containerization operator:

```
@a = $a<>;
```

`<>` takes the value out of the scalar containing it and returns as the
statement result. 

Other ways are not related to our subject here and I’m willing not to focus on
them.

# Why containers?

The concept of containers may seem confusing at first. But a deeper look into it
reveals that it allows to solve many problems and provide features which
otherwise would be hard to implement.

Let’s consider an example. Raku provides a concept of _trait_ which is a part of
a symbol declaration which somehow affects the object the symbol is bound to.
Again, I won’t be going deeper into traits now, just provide an example of one
of them, `is default`:

```
my $foo is default(42);
say $foo; # 42
```

Without the container concept this kind of behavior would require deep support
from the compiler which would have to track all possible uses of `$foo` and
handle the cases when a value is requested from uninitialized variable.
Instead, the trait is applied to the container object. Now whenever the scalar
is requested for a value it first consults with its internal state and returns
the default value unless already once assigned to something non-`Nil`.
Similarly, a couple of other traits operate via the functionality provided by
`Scalar`.

Another interesting aspect of using containers is parameter passing. With a
great deal of simplification, I could say that Raku always passes parameters by
reference. This way positive performance impact is achieved when big objects are
passed as function arguments; but it makes all function arguments immutable by
default.  In rare cases when we want to re-use an argument later `is copy` trait
could be applied to it similarly as we’ve done with `is default` to `$foo`
above. `is copy` wraps the argument object into a scalar for us and binds the
argument symbol to the scalar. Voilá! We have a mutable thing! Similarly, `is
rw` trait binds function parameter to argument’s container allowing modification
of the original value on the caller side.

# Where next?

Raku documentation project provides much [more in-depth
details](https://docs.raku.org/language/containers).
