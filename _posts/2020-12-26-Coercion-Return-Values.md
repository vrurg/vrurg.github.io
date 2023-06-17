---
title: On Coercion Method Return Value
tags:
    - Raku
    - coercion
    - reply
    - role
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
As Wenzel P.P. Peppmeyer continues with his great blog posts about Raku, he
touches some very interesting subjects. His [last
post](https://gfldex.wordpress.com/2020/12/25/coercive-files/) is about
implementing DWIM principle in a module to allow a user to care less about
boilerplate code. This alone wouldn't make me writing this post but Wenzel is
raising a matter which I expected to be a source of confusion. And apparently I
wasn't mistaken about it.

Here is the quote from the post:

> The new coercion protocol is very useful but got one flaw. It forces me to
> return the type that contains the COERCE-method. In a role that doesn’t make
> much sense and it forces me to juggle with IO::Handle.

Basically, the claim winds down to the following snippet:

```raku
role Foo {
    multi method COERCE(Str:D $s) {
        $s.IO.open: :r
    }
}
sub foo(Foo() $v) {
    say $v.WHICH;
}
foo($?FILE);
```

Trying to run it one will get:

> ```
> Impossible coercion from 'Str' into 'Foo': method COERCE returned an instance of IO::Handle
> ```

Let's see why the error is legitimate here.

The short answer would be: coercion, though relaxed in a way, uppermost is a
type constraint.

The longer answer is: the user expects `Foo` in `$v` in `sub foo`. I propose to
do a little thought experiment which involves adding a method to the role `Foo`.
For example, we want to pad text in the file with spaces. For this we implement
`method shift-right(Int:D $columns) {...}` in role `Foo`. Then we use the method
in our `sub foo`:

```raku
sub foo(Foo() $handle) {
    ...
    $handle.shift-right(4);
    ...
}
```

Do I need to elaborate on what's gonna happen when `$handle` is not `Foo`?

Here is the version of the role as I would do it:

```raku
subset Pathish of Any:D where Str | IO::Handle;

role Filish[*%mode] is IO::Handle {
    multi method COERCE(IO:D(Pathish) $file) {
        self.new(:path($file)).open: |%mode
    }
}

sub prep-file( Filish[:r, :!bin]() $h, 
               Str:D $pfx ) 
{
    $h.lines.map($pfx.fmt('%-10s: ') ~ *)».say;
}

prep-file($?FILE, "Str");
prep-file($?FILE.IO, "IO");
prep-file($?FILE.IO.open(:a), "IO::Handle");
```

Note the use of coercion to implement coercion. The idea is to take anything,
what could be turned into an `IO` instance.

Also, I forcibly re-open any `IO::Handle` because the source could have
different open modes from what I expect to be the result of the coercion. In my
example I'm intentionally passing a handle opened in _append_ mode into a `sub`
expecting a _read_ handle.

I'd like to finish with a note that here we have a good example of
[Raku](https://raku.org)
allowing DWIM code semantics without breaking its predictability.
