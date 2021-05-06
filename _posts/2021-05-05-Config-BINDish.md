---
title: Config::BINDish Module First Release
tags: Raku module config
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
Soon after [`Test::Async`](http://localhost:4000/2021/04/27/Test-Async-Release)
time has came for the first release of
[`Config::BINDish`](https://modules.raku.org/dist/Config::BINDish:zef:zef:vrurg).
At first, I didn't plan the module whatsoever. Then I considered it as a little
distraction project to get some rest from an in-house one I was working on
lately. But it turned into a kind of a monster which swallowed quite an amount
of my time. Now I hope it's been worth the efforts.

Basically, the last straw which convinced me to eventually put everything else
aside and have this one done was an attempt to develop a model for scalable file
hosting. I was stuck, no approach I was considering was good enough. And I
decided to change the point of view and try to express the thing in terms of a
configuration file. I went on a hunt onto [Raku modules
site](https://modules.raku.org) and came back with a couple of already familiar
options. Of those I decided that
[`Config::TOML`](https://github.com/atweiden/config-toml) would be the best one
for my needs. Unfortunately, very soon I realized that a feature it misses makes
my life somewhat harder than I'd like it to be: there was no way to expand a
string with an option value.

Aside of that, I found myself almost unconsciously writing something like this
to describe the case:

```
file-pool "public" {
    server-url https://s1.local;
    path ...;
}
```

And so on...

A few weeks later I eventually can have this in my config:

```
default-server "A1";
server "A1" {
    url "https://a1.local";
}
server "A2" {
    url "https://a2.local"
}
network "Office" {
    api-url "{/server("{/default-server}")}/api"; # https://a1.local/api
    subnet 192.168.1.0/24;
    default-gw 192.168.1.1;
    ns { 192.168.1.1; 192.168.1.5 }
}
```

Yes, it's not exactly the way they have it BIND9. That's why I call it _BINDish_.
But with a few tweaks it should be possible to parse `named` configs too would
one ever need it.

And for me it's time to spend a week or two on a road and then – back into the
business!
