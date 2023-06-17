---
title: Nil As No Data
tags:
    - Raku
date: 2020-07-13 13:30:00 -0004
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
In response to [a Wenzel P. P. Peppmeyer post](https://gfldex.wordpress.com/2020/07/06/indicating-absence/)
I have a thing to add.
<!--more-->

The problem of indicating the "no more data" condition is something I dealt with
for a couple of times too. While I do like the last solution from Wenzel post,
the one with the `Failure`, but my approach was different. `Nil` appeals to me
as more appropriate for the task in some cases. For example, while developing
`Concurrent::PChannel` I considered it this way:

> The channel must be capable of transferring any user data. There must be
> no exception for what passes through, no false end-of-data markers. Therefore
> if `poll` method returns a such a marker it has to be something
> indistinctively unique to the module.

My solution, in a simplified form, looked like this:

```
unit module Concurrent::PChannel;
role NoData is export { }
method poll {
    ...;
    $fount ?? $packet !! (Nil but NoData)
}
```

Simple and straightforward! Because `NoData` role belongs to the module it
guarantees the uniqueness of the return value because the module itself would
never mangle with the data injected into the channel. Nor will it push anything
into it. Anyone trying to use `Concurrent::PChannel::NoData` for anything else
but testing method `poll` return value is aware of the consequences. And even
though I myself do not test for falseness of `poll` return value and only check
if the role is applied:

```
if $poll-returned-packed ~~ Concurrent::PChannel::NoData {
    ...
}
```

But from the boolean point of view `Nil but NoData` is a `False` and therefore
conforms to another condition in Wenzel's post.
