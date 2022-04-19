---
title: A New `will complain` Trait
tags: Raku trait feature
toc: true
#date: 2022-04-18 20:00:00
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
Long time no see, my dear reader! I was planning a lot for this blog, as well as
for the [Advanced Raku For Beginners](/arfb.html) series. But you know what they
say: wanna make the God laugh – tell him your plans!

Anyway, there is one tradition I should try to maintain howerver hard the times
are: whenever I introduce something new into the Raku language an update has to
be published. No exception this time.

**So, welcome a new `will complain` trait!**

The idea of it came to be from [discussion about a
PR](https://github.com/rakudo/rakudo/pull/4840) by @lizmat. The implementation
as such could have taken less time would I be less busy lately. Anyway, at the 
moment when I'm typing these lines
[PR#4861](https://github.com/rakudo/rakudo/pull/4861) is undergoing CI testing
and as soon as it is completed it will be merged into the master. But even
after that the trait will not be immediately available as I consider it rather
an experimental feature. Thus `use experimental :will-complain;` will be
required to make use of it.

The actual syntax is very simple:

```
<declaration> will complain <code>;
```

The `<declaration>` is anything what could result in a type check exception
thrown. I tried to cover all such cases, but not sure if something hasn't been
left behind. See the sections below.

`<code>` can be any `Code` object which will receive a singe argument: the value
which didn't pass the type check. The code must return a string to be included
into exception message. Something stringifyable would also do.

Less words, more examples! 

## Type Objects

```
my enum FOO 
    will complain { "need something FOO-ish, got {.raku}" } 
    <foo1 foo2 foo3>;
```

```
my subset IntD of Int:D 
    will complain { "only non-zero positive integers, not {.raku}" } 
    where * > 0;
```

```
my class Bar 
    will complain -> $val { "need something Bar-like, got {$val.^name}" } {}
```

Basically, any type object can get the trait except for _composables_, i.e. –
roles. This is because there is no unambiguous way to chose the particular
`complain` block to be used when a type check fails:

```
role R will complain { "only R" } {}
role R[::T] will complain { "only R[::T]" } {}
my R $v;
$v = 13; # Which role candidate to choose from??
```

There are some cases when the ambiguity is pre-resolved, like `my R[Int] $v;`,
but I'm not ready to get into these details yet.

## Variables

A variable could have specific meaning. Some like to use `our` to configure
modules (my heavily multi-threaded soul is grumbling, but we're tolerant to
people's mistakes, aren't we?). Therefore providing them with a way to produce
less cryptic error messages is certainly for better than for worse:

```
our Bool:D $disable-something
    will complain { "set disable-something something boolean!" } = False;
```

And why not to help yourself with a little luxury of easing debugging when an
assignment fails:

```
my Str $a-lexical 
   will complain { "string must contain 'foo'" } 
   where { !.defined || .contains("foo") }; 
```

The trait works with hashes and arrays too, except that it is applied not to the
actual hash or array object but to its values. Therefore it really only makes
sense for their typed variants:

```
my Str %h will complain { "hash values are to be strings, not {.^name}" };
my Int @a will complain { "this array is all about integers, not {.^name}" };
```

Also note that this wouldn't work for hashes with typed keys when a key of wrong
type is used. But it doesn't mean there is no solution:

```
subset IntKey of Int will complain { "hash key must be an Int" };
my %h{IntKey};
%h<a> = 13;
```

## Attributes

```
class Foo {
    has Int $.a 
        is rw 
        will complain { "you offer me {.raku}, but with all the respect: an integer, please!" };
}
```

## Parameters

```
sub foo( Str:D $p will complain { "the first argument must be a string with 'foo'" } 
                  where *.contains('foo') ) {}
```

## Merge

By this time all CI has passed with no errors and I have merged the PR. 

## Ukraine

You all are likely to know about the Russia's war in Ukraine. Some of you know
that Ukraine is my homeland. What I never told is that since the first days of
the invasion we (my family) are trying to help our friends back there who fight
against the aggressor. By 'fight' I mean it, they're literally at the front
lines.  Unfortunately, our resources are not limitless. Therefore I would like
to ask for any donations you could make by using the QR code below.

I'm not asking this for myself. I didn't even think of this when I started this
post. I never took a single penny for whatever I was doing for the Raku
language. Even more, I was avoiding applying for any grants because it was
always like "somebody would have better use for them".

But this time I'm asking because any help to Ukrainian militaries means saving
lives, both their and the people they protect.

![PayPal Donate](/assets/images/PayPalQR.png)
