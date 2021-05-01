---
title: Test::Async v0.1.1 Release
tags: Raku module asynchronous threaded test
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
This had to be a decent release announcement with a little bit of bragging about
the new features in [`Test::Async`](https://github.com/vrurg/raku-Test-Async).
But it wouldn't be me unless I screw up in a way.  Apparently, this time a have
a little story to tell. But first, the announce itself.

# v0.1.0 and v0.1.1

## Tool Call Stack And Achoring

Versions of [`Test::Async`](https://github.com/vrurg/raku-Test-Async) prior to
v0.1.0 were using a _tool caller_ concept for reporting problems and setting
context for `EVAL`-based tests. The information was stored in two attributes on
a test suite object: one for a `CallFrame`, and another for a
`Stash`/`PseudoStash`. Everything was fine until I realized that if a test tool
invokes another test tool then the caller gets overwritten (what a groundbreaking
discovery, isn't it? 🤦). For example:

```raku
method is-my-structure-correct(...) 
    is test-tool 
{
    ...
    self.is-deeply: ...;
    # At this point tool caller is pointing at the line above.
    # Therefore, proclaim will not report the
    # original location in a .rakutest file.
    self.proclaim: False, ...; 
}
```

BTW, I call this kind of test tools _compound_ ones.

The solution was to replace _tool caller_ with _tool call stack_. Now
`is-deeply` and any other correctly implemented tool must push what it considers
as its caller location to the stack and pop it back when done.

But this is only a part of the problem. What if instead of `is-deeply`, which is
rather simple one, our tool would use `throws-like`, another compound one and
implemented around a subtest? Not only `throws-like` would be reporting it's
invocation site when fails, but it will use incorrect context when tested code
supplied in a string form.

Ok, an example would serve better than a thousand words. Again, here is a
compound test tool:

```raku
method my-compound-test(Str:D $code, ...) 
    is test-tool 
{
    ...
    self.throws-like: ...;
    ...
}
```

And there is a test file with something like:

```raku
subtest "Complex one" => {
    my $obj = MyClass.new;

    my-compound-test q<$obj.must-throw-my-exception>, ...;
}
```

This *will* throw. Though not with *my exception*, but with
[`X::Undeclared`](https://docs.raku.org/type/X::Undeclared) because when
`throws-like` EVALs the code string it would use the closure from
`my-compound-test` method body as the context. And the closure doesn't have any
`$obj` declared!

My answer to the challenge is *anchoring* a tool call stack entry. It means that
any nested call to any test tool will consider that entry as if it is its own 
direct caller:

```raku
method my-compound-test(Str:D $code, ...) 
    is test-tool(:anchored) 
{
    ...
    self.throws-like: ...;
    ...
}
```

That's all. `throws-like` will now consider itself called in the context of
_"Complex one"_ subtest from the above example. And even if we wrap it into a
nested subtest:

```raku
method my-compound-test(Str:D $code, ...) 
    is test-tool(:anchored) 
{
    ...
    self.subtest: "compound", :hidden, :instant, {
        ...
        self.throws-like: ...;
        ...
    }
    ...
}
```

Both the subtest and the `throw-like` would "stick" to the same context in which
`my-compound-test` is called.

## Inline test bundles

Previously to declare own test bundle with custom, project-specific test tools,
one had to write and `use` a module. Now it can be done in a _.rakutest_ file
if it's the only place where these test tools are used:

```raku
use Test::Async::Decl;
test-bundle LocalBundle {
    method my-test(...) is test-tool(:anchored) {
        ...
    }
}
use Test::Async <Base>;
plan 1;
my-test ...;
```

The advantage of declaring `my-test` this way instead of making it a plain `sub`
is that it gets all the cookies of `Test::Async` infrastructure directly. For
example, for `my-test` from the above example anchoring will make it easier to
spot failure locations in the test file.

## Test Aborting

I always felt like `skip-rest` is only partial solution for the problem of
aborting a test suite early. I mean, what would be the common way of using it?

```raku
if ok(do-something, "we're ok") {
    ...; # Run remaining tests
}
else {
    skip-rest "can't continue";
}
```

So far, so good, until we need similar construct among the *remaining tests*.
If it's the global context of a test file then we can make our life easier with
`exit`:

```raku
unless ok(...) {
    skip-rest "reason";
    done-testing;
    exit 1;
}
```

But when we're inside of a subtest things get more complicated and most likely
one would end up with nested `if {...} then {...} else {...}` constructs each
time `skip-rest` is needed.

In `Test::Async` I implemented another solution to this. It is called
`skip-remaining` and it makes all remaining tests to be kind of replaced with
`skip`:

```raku
unless ok(...) {
    skip-remaining "makes no sense";
}
is ...;
isa-ok ...;
done-testing;
```

Both `is` and `isa-ok` will do nothing if `ok` fails. Instead they will emit
`Event::Skip` with _"makes no sense"_ message. This looks better, but still not
ideal. Consider this:

```raku
my $got = may-result-in-a-Failure;
unless is-deeply($got, $expected, "structure ok") {
    skip-remaining "invalid result produced";
}
my-compound-test $got, "integrity test";
done-testing;
```

Apparently, `my-compound-test` will explode if `$got` contains a `Failure`.
While overall the above code would still be a failed test, but for many reasons
a thrown exception might not be an outcome we agree with. Especially in such a
simple case where `else` would easily solve... Wait, what, `else` again?

My short answer to such a long pre-amble is `abort-testing`. It is a test tool
similar in nature to `done-testing` with the only difference: it quits the
current test suite. In case of a child suite like `subtest` it results in
calling suite's `abort` method. For the top suite (test file global context)
`abort-testing` uses plain `exit`. Now we can have something like this:

```raku
plan ...;
my $got = may-result-in-a-Failure;
unless is-deeply($got, $expected, "structure ok") {
    skip-rest "invalid result produced";
    abort-testing;
}
my-compound-test $got, "integrity test";
unless my-other-sensitive-test(...) {
    skip-rest "all is worse than expected";
    abort-testing;
}
test-something-else ...;
done-testing;
```

I think nobody would disagree that a linear code of the kind is much easier to
maintain than a pile of nesting conditions. 

The other great thing is that the example can be easily be wrapped in a subtest
with no changes needed.

# Lessons Learned

This section should've been named _Things f*ed up and fixed_, but then it
wouldn't sound that academic!

Soon after releasing v0.1.0 I decided it is time to get back to my other
projects where I use `Test::Async`. Those I mostly develop on a multi-multi-core
server which is fantastically good for testing concurrent code. Apparently, the
server proved its reputation by refusing to install the update! Tests behaving
nicely over multiple runs on my MacBook suddenly collapsed with astonishing
glory! That was the beginning of a new little quest...

## Don't Share Data Across Threads

Not that I didn't know this rule before or I was ever forgetting about it. But
what I did forget about was a very useful feature of `Test::Async` which allows
to bind a number of concurrent threads to a test suite and make sure the suite
doesn't finish until all threads done. For example:

```raku
subtest "Concurrent Case" => {
    for ^5 -> $thread-num {
        test-suite.start: {
            do-in-thread-test: id => $thread-num;
        }
    }
    # Do some more testing which doesn't depend 
    # on the threads started
    ...; 
}
```

Method `start` of a test suite creates and starts a new job in a dedicated
thread. The subtest (which is our test suite in this case) will never finish
until all five threads are done. The great thing about this feature is that
within `do-in-thread-test` one can call any of the `Test::Async` provided test
tools, including possibly loaded third-party test bundles:

```raku
test-bundle MyAppBundle {
    method do-in-thread-test(..., :$id) is test-tool {
        ...
        self.pass: "control: we're in a thread";
        ...
        self.is: $got, $expected, "message";
        ... 
    }
}
```

By this moment someone might have already understood what was going on: the
_test tool stack_ happened. The damn thing was implemented as an array attribute
on the test suite object and was shared among all threads started! I was lucky
enough to somehow evade this race condition on 16 cores, but on 56 it was nearly
unavoidable...

For better or for worse (and for many reasons it is for better, as to my view),
in [Raku](https://raku.org) there is no guarantee that code started in a thread
would be ran by the same one forever until done. Whenever something like `await`
takes a break there is a non-zero chance that the resumption would happen on a
different thread. So, if one prints `$*THREAD.id` regularly they may notice the
value changing. What it meant to me is that I don't have a reliable way to
identify the current stack based on the data available via `$*THREAD`.

I needed other way around. Apparently, [Raku](https://raku.org) provides it: the
attribute was replaced with a dynamic variable `@*TEST-TOOL-STACK`. The variable
is then set individually per each job created by `Test::Async::JobMgr` role; and
there one set in `PROCESS::` namespace for the global scope.

There is nothing really complicated about this case. But I used it as a good
reason to demo once again how easy it is to find the right solution to a problem
in [Raku](https://raku.org).

## Don't Be Greedy

Now it felt like things are ready for the bugfix release of v0.1.1. Just one
more test and... Needless to say, I got another punch in my face! To make long
story short, the problem was tracked down to the following construct, which is a
part of `t/060-subtest.t`:

```raku
todo "subtest fails";
subtest "TODO before subtest" => {
    flunk "this test fails but the subtest is TODO";
}
```

For the clarity of it, the construct could fail in the presence of another
concurrently running subtest, started earlier:

```raku
subtest "Concurrent", :async, {
    ...
}
```

This is a rarely happening flapper case. Briefly, what happens here is that
`todo` internally sets a counter which tells the core how many of the following
tests must be marked as `TODO`. Because subtests can be ran concurrently or even
postponed until the end of execution of the enclosing test suite, they pick
up their `TODO` status as early as possible, even before the suite object
they're based upon, is instantiated.

So far, so good. When a subtest finishes it is using it's parent suite object to
report the results in order to simulate behavior of other test tools and to
provide correct indentation of TAP output. And it does so by calling parent's
`proclaim` method. `proclaim`, in turn, uses `send-test` method which is the
central point of emitting `Event::Test` filled with all the information to be
reported. One its duties is taking into account the current TODO counter. _Oops,
we do it again!_

Here is what is the diagnosis: when the concurrent subtest finishes it might
pick up the `TODO` status on the parent _before_ the "TODO" subtest is getting
there for it! As a result I was seeing an _ok_ subtest marked with `TODO`, and
the flunking one... Well, it was actually flunking.

I needed to somehow explicitly tell `send-test` method not to consider `TODO`
counter when this is not needed. There were two ways to have this done: either
add a parameter to the method itself and to the `proclaim` method; or use
another thread-safe way to raise a flag.

The first approach required a slight, but still backward-incompatible, change to
the suite object API. The second was only possible with a help of a dynamic
variable.

The first approach I didn't like. The second one was even worse.

And so the choice was clear, I had to bump `:api` version of the module.  After
all, whereas `Test::Async` v0.1.0 was implementing API v0.1.0; v0.1.1 of the
module does API v0.1.1. I don't like it, it looks like abusing the feature; but
have to admit this cost of insufficient pre-release testing.

# Post-Release

Heh, a long period of silence I compensated with a monstrous post which was
initially planned as a few paragraphs introducing just a couple of new features
in `Test::Async`. Another proof of the saying "Wanna make the God laugh? Tell
him about your plans!". Anyway, _my_ plans now is to get back to the work I
postponed.  And to finally make the decision as to whether I have time for
having a talk at the upcoming Perl Conference...
