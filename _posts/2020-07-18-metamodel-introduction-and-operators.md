---
title: "Metamodel Introduction Article. Operators"
date: 2020-07-18 10:47:00 -0004
tags:
    - Raku
    - publication
    - article
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
I'm publishing [the next article](/arfb-publication/05-the-metamodel-introduction-to-mop/)
from [ARFB](/arfb/) series. This time rather short one, much like a warm up
prior to the main workout.

But I'd like to devote this post to another subject. It's too small for an
article yet still worth special note. It was again inspired by [one more
post](https://gfldex.wordpress.com/2020/07/18/deboilerplating/) from Wenzel P.P.
Peppmeyer. Actually, I knew there going to be a new post from him when found [an
error report](https://github.com/rakudo/rakudo/issues/3799) in Rakudo
repository. And this is the subject of the report which made me write the post.

In the report Wenzel claims that the following code results in incorrect Rakudo
behaviour:

```
class C { };
my \px = C.new;
sub postcircumfix:«< >»(C $c is raw) {
    dd $c;
}
px<ls -l>;
```

And that either the operator redefinition must work or the error message he gets
is _less than awesome_:

> ```
> ===SORRY!=== Error while compiling /home/dex/projects/raku/lib/raku-shell-piping/px.raku
> Missing required term after infix
> at /home/dex/projects/raku/lib/raku-shell-piping/px.raku:9
> ------> px<ls -l>⏏;
>     expecting any of:
>         prefix
>         term
> ```

Before I tell why things are happening as intended here, let me notice two
problems with the code itself which I copied over as-is since it doesn't work
anyway. First, the `postcircumfix` sub must be a `multi` and in Wenzel's post it
is done correctly. Second, it must receive two arguments: first is the object it
is applied to, second is what is enclosed into the angle brakets.

So, why won't it work as one might expect? In Raku there is a class of syntax
constructs which look like operators but in fact they're syntax sugars. There
may be different reasons why is it done so. For example, the assignment operator
`=` is done this way to achieve better performance. `< >` makes what is inclosed
inside of it a string or a list of strings. Because of this it belongs to the
same category, as quotes `""`, for example. Therefore, it can only be
implemented properly as a syntax construct. When we try to redefine it we break
the compiler's parsing and instead of a postcircumfix it finds a pair of _less
than_ and _greater than_ operators. Because the latter doesn't have rhs
statement hence the error we see.

And you know, it was really useful to make this post as I realized that closing
of the tickat was preliminary and that such compiler behavior is still incorrect
because the attempt to redefine the op should prbably not result in bad parsing.
