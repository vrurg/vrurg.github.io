---
title: Runtime vs. Compilation, Or Reply \#2
tags: Raku coercion reply role
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
The friendly battle continues with [the next post from
Wenzel](https://gfldex.wordpress.com/2020/12/27/assumed-predictability/) where
he considers different cases where strict typechecking doesn't work. The primary
point he makes is that many decisions [Raku](https://raku.org) makes are
run-time decisions and this is where static typechecking doesn't work well. This
is true.  But this doesn't change the meaning of [my previous
post](https://vrurg.github.io/2020/12/26/Coercion-Return-Values).

First of all, let's make clear difference between compile time decisions and
run-time decisions. Basically, when we write something like:

```raku
sub foo(Int:D $x) {...}
```

semantically it means:

```raku
sub foo($x) { 
    die "oopsie!" 
        unless $x ~~ Int && $x.defined; 
    ... 
}
```

There is nothing magical in it. The difference between the two snippets is
apparently about the performance as compiler can do much more optimizations
related to static typing of the first case, than it is able with the second
variant. This is pretty much clear. What's not is that if we declare a
parameterized role we often end up with run-time code produced by the compiler.

```raku
role R1[::T] {
    sub foo(T $x) { ... }
    sub bar(Int:D $x) { ... }
}
```

Here `foo` will do a lot of extra work at runtime because the compiler doesn't
know what type `$x` will have. So, when it comes to:

```raku
class C1 does R1[Str(Int:D)] { ... }
```

Then something like `C1.bar(pi)` will throw after a simple `pi ~~ Int:D` check.
But `C1.foo(pi)` case will result in the signature binding code to do extra
steps to resolve `T`, and then a few more operations before actually throwing a
bad parameter type exception.

So, eventually, where one would expect things to be done at compile time,
they're not. Hopefully, this is a good example of the dualistic nature of Raku
which is balancing between static and dynamic approaches.

Let's see what it leads us to.

# Submethods As Non-inheritable Properties

Though in general Raku design tries to stick to [Liskov substitution
principle](https://en.wikipedia.org/wiki/Liskov_substitution_principle),
submethods are a special case which breaks it intentionally. Anyone utilizing
a submethod must remember this. Moreover, I'd say that a submethod must not be
invoked directly without a really good reason to do so! If one do call a
submethod they must either make sure that call is done on the submethod's class,
or use `.?` operator to prevent their code from throwing:

```raku
class Foo {
    submethod foo { ... }
}

class Bar is Foo { }

sub foo(Foo $v) {
    with $v.?foo {
        ...
    }
}

sub bar(Foo $v) {
    if $v.WHAT === Foo {
        $v.foo;
    }
}
```

To my own point of view, the most useful use case for submethods is iteration
over a class' MRO order to call submethods on classes where they're
defined.  There is a special method on `Mu` which implements this behavior –
[`WALK`](https://vrurg.github.io/2019/12/16/new-role-of-roles-in-raku#a-method-to-walk-them-all).
It is not documented yet, unfortunately. But it's
[specced](https://github.com/Raku/roast/blob/master/S12-introspection/walk.t).
Partially, its functionality is implemented with
[`.+`](https://docs.raku.org/language/operators#methodop_.+) and
[`.*`](https://docs.raku.org/language/operators#methodop_.*) operators.

# `FALLBACK`

I'd rather skip this case. Except for one note to be made: somehow it reminds me
about the ways of TypeScript when it comes to type matching. I.e. we'd need to
match an object's content against our constrains.

Anyway, `FALLBACK` implementation is so much about runtime processing that I see
no problem here whatsoever. Moreover, I'd rather avoid this kind of design
pattern in a production code, unless it is tightly wrapped in a very small and
perfectly documented module.

# Role Or Class As a Function

This last case is perhaps the most interesting one because here what we can do
about it right away:

```raku
subset Pathish of Any:D where Str | IO::Handle;

role Filish[*%mode] is IO::Handle {
    multi method COERCE(IO:D(Pathish) $file) {
        self.new(:path($file)).open: |%mode
    }

    multi method CALL-ME(Pathish:D $file) {
        IO::Handle.new(:path($file)).open: |%mode
    }
}

sub prep-file(Filish[:r, :!bin]() $h, Str:D $pfx) {
    $h.lines.map($pfx.fmt('%-10s: ') ~ *)».say;
}

sub prep-file2($path, Str:D $pfx) {
    my $h = Filish[:r, :!bin]($path);
    $h.lines.map($pfx.fmt('%-10s: ') ~ *)».say;
}

prep-file($?FILE, "Str");
prep-file($?FILE.IO, "IO");
prep-file($?FILE.IO.open(:a), "IO::Handle");
prep-file2($?FILE, "Str-2");
```

This is slightly extended example from the previous post. I have only added
`CALL-ME` method and `prep-file2` sub. Apparently, the only significant
difference with Wenzel's code snippet is that invocation of `Filish` has been
moved from the signature into the function body. I think this is perfectly OK
because one way or another it's a runtime thingie.

# `LEAVE {}`

Just to sum up the above written, Wenzel is right when he says that coercion is
about static type checking. It indeed is. For this reason it ought to be strict
because this is what we expect it to be.

It is also true that there're cases where only run-time checks make it possible
to ensure that the object we work with conforms to our requirements. And this is
certainly not where coercion comes into mind. This is a field of dynamic
transformations where specialized routines is what we need.
