---
title: A Long Promised Article About Roles
tags:
    - Raku
    - publication
    - article
    - role
    - roles
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
A while ago I promised a couple of people an article about Raku roles. To be
frank, it was a long time ago. The plan was to cover a number of other subjects
needed to better understand a few concepts behind the role model implementation
in Rakudo.

Unfortunately, it turned out to be one of those perfect examples of the
principle: "wanna make the God laugh? tell him your plans!" But promise is
promise and a few days ago the WTF mood took me over, all actual tasks were
pushed back, and my note-taking app was ready for a new draft.

So, welcome [Roles Or When One Is Many](/arfb-publication/07-roles-or-when-one-is-many/)
of the [Advanced Raku For Beginners](/arfb.html) cycle!

As it often happens, writing an article ends up with a bug found in Rakudo. Of
course, this time is no exception. While consulting with metamodel code I found
this comment:

```
# Pass along any parents that have been added, resolving them in
# the case they're generic (role Foo[::T] is T { })
```

I never used the construct before and decided to give it a try. Apparently, it
didn't work. My first thinking was that it is rather useless because a class
consuming such role can simply do, for example:

```
class C does Foo[Int] is Int { }
```

I don't really see a big problem here. But if we slightly change the role
declaration:

```
role Foo[::T Numeric] is T { }
```

It would make more sense. Of course, the above declaration of `C` is still
possible, but the whole thing lacks elegance.

Thus, the time for a new PR has come. 
