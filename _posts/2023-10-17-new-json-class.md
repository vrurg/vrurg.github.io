---
title: A New JSON::Class Module. All New.
date: 2023-10-17
tags: ["Raku", "JSON", "serialization", "module"]
header:
  teaser: /assets/images/Camelia-200px-SQUARE.png
---
This will be a short one. I have recently released a family of `WWW::GCloud` modules for accessing Google Cloud services. Their REST API is, apparently, JSON-based. So, I made use of the existing [`JSON::Class`](https://raku.land/zef:jonathanstowe/JSON::Class). Unfortunately, it was missing some features critically needed for my work project. I implemented a couple of workarounds, but still felt like it's not the way it has to be. Something akin to [`LibXML::Class`](https://raku.land/zef:vrurg/LibXML::Class) would be great to have...

There was a big "but" in this. We already have [`XML::Class`](https://raku.land/?q=XML%3A%3AClass), `LibXML::Class`, and the current `JSON::Class`. All are responsible for doing basically the same thing: de-/serializing classes. If I wanted another JSON serializer then I had to take into account that `JSON::Class` is already taken. There are three ways to deal with it:

1. Branch the current `JSON::Class` and re-implement it as a backward-incompatible version.
2. Give the new module a different name.
3. Implement own version and publish it under my name.

The first two options didn't appeal to me. The third one is now about to happen.

I expect it to be a stress-test for Raku ecosystem as, up to my knowledge, it's going to be the first case where two different modules share the same name but not publishers.

As a little reminder:

* To use the old module one would have to have `JSON::Class:auth<zef:jonathanstowe>` in their dependencies and, perhaps, in their `use` statement.
* The new module will be available as `JSON::Class:auth<zef:vrurg>`.

There is still some time before I publish it because the documentation is not ready yet.

Let's 🤞🏻.
