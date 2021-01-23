---
title: A New Release Of Cro::RPC::JSON
tags: Raku module asynchronous threaded Cro
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
I don't usually announce regular releases of my modules. But not this time. I
start this new year with the new _v0.1_ branch of
[`Cro::RPC::JSON`](https://github.com/vrurg/raku-Cro-RPC-JSON/tree/v0.1).
Version 0.1.1 is currently available on CPAN (will likely be replaced with
[fez](https://deathbyperl6.com/faq-zef-ecosystem) as soon as it is ready).  The
release is a result of so extensive changes in the module that I had to bump its
`:api` version to 2.

Here is what it's all about.

## Why `Cro::RPC::JSON`

Before I tell about the changes, let me briefly introduce the module itself.

The primary purpose of `Cro::RPC::JSON` is to provide a simple way to use the
same API class for both server-side Raku code and for JSON-RPC calls. For
example, if we have a class for accessing an inventory database of some kind
then it should be easy to use the same class to serve our front-end JavaScript
code:

```
class Inventory {
    ...
    method find-item(Str:D $name) is json-rpc { ... }
    ...
}
```

That's all. The only limitation the module currently imposing on the methods is
accepting simple arguments and returning JSONifiable values, as supported by
[`JSON::Fast`](https://modules.raku.org/dist/JSON::Fast:cpan:TIMOTIMO).
Marshalling/unmarshalling of parameters/return values is considered, but I'm not
certain yet as to how exactly to implement it.

Now, all we need to serve JSON-RPC calls is to add this kind of entry into 
[`Cro`](https://cro.services) routes:

```
# If Inventory is not thread-safe this this line has to be placed inside the
# 'post' block.
my $inventory-actor = Inventory.new;
route {
    ...
    post -> 'api' {
        json-rpc $inventory-actor;
    }
}
```

And that's all.

`Cro::RPC::JSON` also supports code objects as handlers of the RPC requests. But
let me omit this part and send you directly to [the
documentation](https://github.com/vrurg/raku-Cro-RPC-JSON#code-vs-object).
Let's get to the point instead!

## WebSockets Support

A long-planned feature I never had enough time to get implemented. But when the
life itself demands it in a form of an in-house project, where WebSockets are a
natural fit, who am I to disobey the command?

The support comes in a form of implementing both JSON-RPC and asynchronous
notifications support by treating socket as a bi-directional stream of JSON
objects. JSON-RPC ones are recognized by either presence of `jsonrpc` key in an
object; or by treating a JSON array as a JSON-RPC batch. Because the RPC traffic
is prioritized over free-form notifications it means that the latter can only be
represented by JSON objects (and without `jsonrpc` key in them!). No other
limitations implied. I don't consider the constraint as a problem because the
primary purpose of non-RPC objects is to support push notifications. For any
other kind of traffic it is always possible to open a new RPC-free socket.

The use of our actor/API class with WebSockets is as simple as:

```
route {
    ...
    get -> 'api' {
        json-rpc :web-socket, $inventory-actor;
    }
}
```

Note that there is no need to change our `Inventory` class aside of the already
added `is json-rpc` trait. Same code will work for both HTTP/POST and WebSockets
transports! It actually makes it possible to provide both interfaces on the
server side by simply having two route entries – one for each case. Which one to
use would depend on what kind of optimization developer is willing to achieve. I
haven't had time to benchmark, but common sense tells me that where WebSockets
provide less latency and is great for single requests affecting your application
response time on user actions; HTTP/POST would serve better on big
parallelizable requests. For example, we can fill in a big table by requesting
each individual line of it from a server in asynchronous manner over HTTP/POST,
allowing the server to process all requests in parallel.

## Modes Of Operation

The initial v0.0 branch of the module was strictly about HTTP/POST transport and
thus only supported simple "invoke code - get result" mode. The only alternative
provided to a user was the choice between using a class or a code object (see,
for example, [this route
entry](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/63280821cc29235bb1c4d1e21045526590c58e0a/t/lib/Basic-JRPC.rakumod#L10)
from `Cro::RPC::JSON` test suite.

Introduction of asynchronous WebSockets consequently introduced the demand for
additional asynchronousity. If we're about to support push notifications then we
have to somehow react to server-side events too, right? Therefore the module now
provides three different modes of operation: synchronous, asynchronous, and
hybrid. Again, I'd better avoid citing the documentation here. Just single
example for our `Inventory` class:

```
method subsribe(Str:D $notification) is json-rpc("rpc.on") { ... }
method unsubscribe(Str:D $notification) is json-rpc("rpc.off") { ... }
method on-inventory-update is json-rpc(:async) {
    supply {
        whenever $!database.updated -> $update-event {
            emit %(
                notification => 'ItemUpdate',
                params => %(
                    id => $update-event.item.id,
                    status => $update-event.status,
                ),
            ) if %!subsriptions<ItemUpdate>;
        }
    }
}
```

Now, all our client-side JavaScript code needs is to call `rpc.on` JSON-RPC
method with _"ItemUpdate"_ as the argument and start listening for incoming
events. Any item update in the inventory will now be tracked on the client side
automatically.

## Roles And Classes

Don't wanna focus on this, mostly technical fixes like support for parameterized
roles, fixed inheritance and role consumption.

_A note to myself: don't you want to document all this?_

## Error Handling

This was perhaps the biggest nightmare. As it is always with asynchronous code.
But, hopefully, I finally got it done right. For synchronous code and class
method calls the module should now do all is needed to properly handle any
exception leaked from the user code. For JSON-RPC method calls this would mean
correct response produced with `error` key set.

For asynchronous code things are much harder to keep control of. Whereas
HTTP/POST allows to do some guesses and provide some additional error processing
by `Cro::RPC::JSON`, for WebSockets any unhandled exception in any async code
means socket termination. Being rather new to this technology, I spent a lot of
time trying to figure out how to properly respond to a request until realized
that actually there is no solution to this problem. The reason is as simple as
it only can be: if asynchronous user code thrown then the `Supply` it provided
is actually terminated. Since the supply is an integral part of the whole
JSON-RPC/WebSocket processing pipeline, its termination means the pipeline is
disrupted.

# LAST

It's now time to dive into the muddy waters of TypeScript/JavaScript. I have
already tested `Cro::RPC::JSON` with `Vue` framework and `rpc-websockets` module
and it passed the basic tests of calling methods and processing push
notifications.  Will see where this all eventually takes me. After all, this is
gonna be my first production project in Raku.
