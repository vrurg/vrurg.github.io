---
title: Did you know that ...
tags:
    - Raku
    - fact
    - did-you-know
toc: false
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
Let's assume we have a type with multi-component name, like:

```
class Foo::Bar {
}
```

And there is another class `Baz` for which we want it to be coercible into
`Foo::Bar`. No problem!

<!--more-->

```
class Baz {
    method Foo::Bar() { Foo::Bar.new }
}
```

Now we can do:

```
sub foo(Foo::Bar() $v) { say $v }
foo(Baz.new);
```
