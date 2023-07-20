---
title: Did you know that...
date: 2023-07-04T21:24:07.715Z
tags: ['did-you-know', 'fact', 'Raku']
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
Once, long ago, coincidentally a few people were asking the same question: _how do I get a method object of a class?_

<!--more-->

Answers to the question would depend on particular circumstances of the code where this functionality is needed. One
would be about using MOP methods like `.^lookup`, the other is to use method name and indirect resolution on invocant:
`self."$method-name"(...)`. Both are the most useful, in my view. But sometimes declaring a method as `our` can be
helpful too:

```
class Foo {
    our method bar {}
}
say Foo::<&bar>.raku;
```

Just don't forget that this way we always get the method of class `Foo`, even if a subclass overrides method `bar`.