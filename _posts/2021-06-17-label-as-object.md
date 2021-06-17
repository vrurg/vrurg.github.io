---
title: Did you know that ...
tags: Raku fact
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
Raku is full of surprises. Sometimes I read something what that me like "oh,
really?". Sometimes I realize than a fact evident for me is not so for others.
<!--more-->

Here is one of the kind.

Do you know that labels in Raku are objects? Take this:

```
FOO: for ^1 { .say }
```

`FOO:` is not a syntax construct to place an anchor in code but a way to
create a `Label` instance:

```
FOO: dd FOO;
BAR: say BAR;
```

Due to its special and even specific nature class `Label` doesn't provide much
of an API. And what is available are methods to interact with loops. These are:

- `next`
- `redo`
- `last`

Feels somewhat familiar, isn't? 

```
FOO: for ^10 {
    .say;
    FOO.last;
}
```

In a way we can say that `last FOO` is [an indirect method
invocation](https://docs.raku.org/language/objects#index-entry-indirect_invocant_syntax),
even though it's not really true as long as the core defines a multi-dispatch
routine `last`, alongside with `redo` and `next` subs. But the corresponding
routine candidates for labels actually do nothing but call [`Label`'s
methods](https://github.com/rakudo/rakudo/blob/4f61a108b1e717a8e05ee861738a412d55be6ed4/src/core.c/Label.pm6).

Once again, objects are just about everywhere in Raku.
