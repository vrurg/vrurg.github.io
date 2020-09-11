---
title: "Proxy Container"
logo: /assets/images/Camelia-200px-SQUARE.png
---
## The Start, Part 1
I was going to start this article differently. But today, as I'm writing these
lines, [a new ticket about
`Proxy`](https://github.com/rakudo/rakudo/issues/3822) has been opened on
[Rakudo issue tracker](https://github.com/rakudo/rakudo/issues). And once again
I was amazed how coincidental some coincidences are!
<!--more-->
There was also some good about the ticket: it gave me the subject I was missing
for a few days to make this article accomplished.

## The Start, Part 2
So far the mainline of this series was focused on the metamodel and MOP. Things
are likely to remain this way until the end of the project, but I can't avoid
interesting topics from other language areas. This time the plan is to elaborate
on `Proxy` container, mentioned earlier in [Containers And
Symbols](https://vrurg.github.io/arfb-publication/03-containers-and-symbols/).

## The Purpose
[The official documentation](https://docs.raku.org/type/Proxy) for the class is
rather succinct but you should read it first unless have done so already. My own
definition of `Proxy` purpose winds down to the following: it provides means of
controlling and manipulating objects fetched from or stored into a container. To
start with, I would borrow an example from the documentation:

```
sub double() is rw {
    my $storage = 0;
    Proxy.new(
        FETCH => method ()     { $storage * 2    },
        STORE => method ($new) { $storage = $new },
    )
}
my $doubled := double();
$doubled = 4;
say $doubled;           # 8
say $doubled.VAR.^name; # Proxy
```

The last line is added to the example to make it clear what is different
comparing to the following code:

```
my $doubled = 4;
say $doubled.VAR.^name; # Scalar
```

## The Use
You likely have noticed already the use of anonymous methods as values of
`Proxy` constructor profile keys in the above example. The reason for this
approach is `Proxy`  instance passing itself as the first argument to the
`FETCH` and `STORE` code objects.

Wether you knew it already or not, but a `method` is an instance of `Method`
class which inherits directly from `Routine`. And a `sub` is an instance of
`Sub` class which also inherits from `Routine`. Other than been of different
classes they share almost every aspect of their implementation. What actually
tell one from another is that method's first argument is implicit and it's the
object the method is called upon. Apparently, the argument is what `self`
lexical is then bound to. Thus, `method` and `sub` are more about the way of
using a code object than about what the object is. A good demo for this would be
this code:

```
sub foo($self) {
    say $self.WHICH;
}
"42".&foo
```

Here `foo` is invoked as a method of a string object `"42"`. The `.&` invocation
syntax is almost equivalent to the `foo("42")` form where `"42"` is implicitly
passed on to `foo`. The snippet can be rewritten to use a `method` declaration:

```
my &foo = method { say self.WHICH };
"42".&foo;
```

The result is the same except for one less parameter in `&foo` signature.

Getting back to `Proxy`, use of anonymous methods makes `FETCH` and `STORE` code
objects behave as if they're methods of a `Proxy` instance. Does it provide us
with any advantages? Not really. Partly, because `Proxy` is a very simplistic
class with no really useful public methods but `new`. Partly due to specifics of
`Proxy` behavior I'll talk about later in this text.

It can make a little difference in a case of subclassing:

```
class FooProxy is Proxy {
    has $!storage;
    method foo { say "foo" }
}
```

But the thing to be always remembered is that we're dealing with a _container_
here. Containers are highly transparent entities. Thus, even though `self`
points back to a `Proxy` instance, any attempt to invoke a method on it would
result in reading from the container and, consequently, in calling `FETCH` and
eventually invoking the method on its return value:

```
my $p := FooProxy.new(
        FETCH => method () { 42 },
        STORE => method ($v) { say self.foo; }
    );
$p = 12; # No such method 'foo' for invocant of type 'Int'
```

For this reason I would discourage anyone from using `self` within `FETCH` or
otherwise the routine is very likely to end up with an infinite recursion.

There is a legit question though: how does one access the method `foo` of
`FooProxy` from above? Apparently, via `self.VAR.foo` as we normally do with
containerized stuff. Also worth noting that within methods of `FooProxy` it is
totally safe to reference attributes with `$!storage` syntax. Yet, any direct
use of `self` brings us back into the pitfall of using the container itself;
even if a private method is invoked with `self!private()` despite of the
invocation syntax akin to referencing a private attribute.

And to get over with this subject, for those of you who doesn't like wordy code,
`FETCH` and `STORE` are not obliged to be `method` declarations. After all, Raku
is about
[TIMTOWTDI](https://en.wikipedia.org/wiki/There%27s_more_than_one_way_to_do_it).
The uniformity of internal conventions let us have things done differently from
syntax point of view while preserving the semantics:

```
Proxy.new(
    FETCH =>            { $storage * 2 },
    STORE => -> $, $new { $storage = $new },
)
```

or, if we'd need to to use the `FooProxy` class:

```
FooProxy.new(
    FETCH => { $storage * 2 },
    STORE => { $^a.VAR.foo($^b) }
    # STORE => -> \proxy, $new { proxy.VAR.foo($new) }
)
```

Though I personally not a big fan of using [self-declared formal positional
parameters](https://docs.raku.org/language/variables#Twigils) this way. Pointy
blocks are my favorites most of the time, as shown in the comment.

## The Pitfalls
`Proxy` is expensive. Or, rather: it is **expensive**. At the very beginning of
this article I have mentioned a ticked. It is about `FETCH` been called multiple
times under certain circumstances. Unfortunately, I expect same kind of tickets
to be opened again and again in the future. Sometimes Raku's real complexity is
so well hidden behind the curtain that it causes a confusion in inexperienced
developers. Let's see how it happens with an example:

```
my $p := Proxy.new(
        FETCH => { say "FETCH"; 42 },
        STORE => -> $, $v { }
    );
say $p;
```

Do you find anything criminal in this code? Likely not. Until it's been ran:

```
FETCH
FETCH
FETCH
FETCH
FETCH
FETCH
FETCH
42
```

"Wow, wow, slow down!" – isn't it the first impression one gets when see this
for the first time? I was there, felt the same! Back then my thinking was that
one day I'll grow up, become a big and strong Raku developer and get it fixed!
Not that I'm _so_ much grown up by now, but at least I know that the problem is
not about too many calls to `FETCH` been made but in our assumptions.

At the first glance  `say $p` looks like a perfectly atomic operation. But, in
fact, it is not. Far from it! The argument it takes is actually gets passed
through a number of stages. To mention just a few:

1. `say` is a `multi sub`. In order to determine what candidate to choose Raku
   needs to know the types of its arguments. Therefore it reads from `$p` to
   find a candidate with matching signature.
2. to stringify `$p` `say` invokes method `gist` on it. 
3. `gist` itself is a `multi`, so we get the dispatcher involved again.
4. etc.

Depending on a chosen candidate, an argument could also become the subject for
testing by additional parameter constraints like definedness or alike.
Apparently, this would result in extra calls of `FETCH`. And, in fact, there is
no way we could optimize away all those reads. Once we consider the situation
carefully it becomes evident that it is the dynamic nature of `Proxy` which
doesn't let us to skip a read or two; or even eliminate almost all of them
altogether reducing the total count to one. Because sometimes the side effects
of `FETCH` or `STORE` are what really matters. The most simple case I can come
up with is when we need `Proxy` exactly for the reason of counting the number of
references to a variable in our code.

Contrary to the static `Scalar` which would always return same value until is
assigned with a new one, `Proxy` is unpredictable about it's value too.
Therefore the compiler can't make any assumptions about it and ought to generate
a call to `FETCH` for _any_ reference to the container. Maybe at some point a
way to hint the compiler about possible changes in the return value would be
invented and implemented and this would make additional optimizations possible.
Though such hinting would only make sense under the obligation of producing no
side-effects by the `FETCH`/`STORE` code. Until then we should just keep in
mind this peculiarity of proxies.

Does it make proxies harmful? Yes, sometimes. And yet, sometimes they're
indispensable and even irreplaceable. It means just one thing: to use or not to
use a proxy should be carefully considered.

The above mentioned ticket refers to a situation where a `Proxy` masks a network
operation behind it. While being rather critical performance degradation cause
if used in a straightforward way, it could be very handy if the object it gets
from the network is cached. In this case it would even pay back by speeding up
operations while keeping the code tidy by hiding something like
`$server.fetch('key_foo')` behind a simple `$key_foo` variable.

Another approach would be implementation of lazy operations where a symbol could
be bound to a `Proxy` and, when and if eventually referenced, get its value and
then re-bound to either the value itself or to a `Scalar` containing it. In this
case we only pay the performance price once in the life time of the symbol. And
if obtaining the initial value is an expensive operation on its own then use of
a proxy would pay back again by postponing it to the moment when it is really
necessary possibly sparing on code initial setup time; or even eliminating the
initialization of the symbol altogether if it remains unused.

## The End
It is really amazing how much does it take to describe such a simple class as
`Proxy`! Did you know that its implementation is just about 33 lines long
including a comment? But to comprehend the full power of the concept it takes us
to the neighboring areas of the Raku language. This pattern I often find myself
following to: no matter what subject is being studied, a couple of adjustent
subjects would get involved. Consider it another remarkable feature of Raku: it
would hardly let one get bored easily.

