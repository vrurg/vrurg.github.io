---
title: Re-release Of Cro::RPC::JSON
tags: Raku module asynchronous threaded Cro
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
For a couple of reasons I had to revamp the module and change it in a
non-backward compatible way. To avoid bumping `api` again and because versions
0.1.0 and 0.1.1 contained a couple of serious enough problems, I considered it
more reasonable to pull out these versions from CPAN. Not the best solution, of
course, but neither one I was fully OK with.

Today I'm releasing version 0.1.2. Aside of version bump this is also the first
version and, actually, my first ever module released into `zef` ecosystem.

The release also got a major new feature. The module now supports JSON-RPC method
call authorization.  [The
documentation](https://github.com/vrurg/raku-Cro-RPC-JSON/tree/v0.1) has it
explained.
