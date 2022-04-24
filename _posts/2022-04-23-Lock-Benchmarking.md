---
title: He Tested Many Locks. See What Happened Then!
tags: Raku lock benchmark
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
These clickbaiting titles are so horrible, I couldn't stand mocking them! But
at least mine speaks truth.

My recent tasks are spinning around concurrency in one way or another. And where
the concurrency is there are locks. Basically, introducing a lock is the most
popular and the most straightforward solution for most race conditions one could
encounter in their code. Like, whenever an investigation results in a resolution
that data is being updated in one thread while used in another then just wrap
both blocks into a lock and be done with it! Right? Are you sure?

They used to say about Perl that "if a problem is solved with regex then you got
two problems". By changing 'regex' to 'lock' we shift into another domain. I
wouldn't discuss interlocks here because it's rather a subject for a big CS
article. But I would mention an issue that is possible to stumble upon in a
heavily multi-threaded Raku application. Did you know that `Lock`, Raku's most
used type for locking, actually blocks its thread? Did you also know that
threads are a limited resource? That the default `ThreadPoolScheduler` has a
maximum, which depends on the number of CPU cores available to your system? It
even used to be a hard-coded value of 64 threads a while ago.

Put together, these two conditions could result in stuck code, like in this
example:

```
BEGIN PROCESS::<$SCHEDULER> = ThreadPoolScheduler.new: max_threads => 32;

my Lock $l .= new;
my Promise $p .= new;
my @p; 

@p.push: start $l.protect: { await $p; };

for ^100 -> $idx {
    @p.push: start { $l.protect: { say $idx } }
}

@p.push: start { $p.keep; }

await @p;
```

Looks innocent, isn't it? But it would never end because all available threads
would be consumed and blocked by locks. Then the last one, which is supposed to
initiate the unlock, would just never start in first place. This is not a bug in
the language but a side effect of its architecture. I had to create
`Async::Workers` module a while ago to solve a task which was hit by this issue.
In other cases I can replace `Lock` with `Lock::Async` and it would just work.
Why? The answer is in the following section. Why not always `Lock::Async`?
Because it is rather slow. How much slower? Read on!

## `Lock` vs. `Lock::Async`

What makes these different? To put it simple, `Lock` is based on system-level
routines. This is why it is blocking: because this is the default system
behavior.

`Lock::Async` is built around `Promise` and `await`. The point is that in Raku
`await` tries to release a thread and return it back into the scheduler pool,
making it immediately available to other jobs. So does `Lock::Async` too: instead
of blocking, its `protect` method enters into `await`.

BTW, it might be surprising to many, but `lock` method of `Lock::Async` [doesn't
actually lock by itself](https://docs.raku.org/type/Lock::Async#method_lock). 

## Atomics

There is one more way to protect a block of code from re-entering. If you're
well familiar with atomic operations then you're likely to know about it. For
the rest I would briefly explain it in this section.

Let me skip the part about the atomic operations as such, 
[Wikipedia has it](https://en.wikipedia.org/wiki/Linearizability#Primitive_atomic_instructions).
In particular we need CAS ([Wikipedia again](https://en.wikipedia.org/wiki/Compare-and-swap)
and [Raku implementation](https://docs.raku.org/routine/cas)). In a natural
language terms the atomic approach can be "programmed" like this:

1. Take a variable and set it to _locked_ state if not set already; repeat
   otherwise
2. Do your work.
3. Set the variable to _unlocked_ state.

Note that 1 and 3 are both atomic ops. In Raku code this is expressed in the
following slightly simplified snippet:

```
my atomicint $lock = 0; # 0 is unlocked, 1 is locked
while cas($lock, 0, 1) == 1 {}  # lock
...                             # Do your work
$lock ⚛= 0;                     # unlock
```

Pretty simple, isn't it? Let's see what are the specs of this approach:

1. It is blocking, akin to `Lock`
2. It's fast (will get back to this later)
3. The lock operation might be a CPU hog

Item 2 is speculative at this moment, but guessable. Contrary to `Lock`, we
don't use a system call but rather base the lock on a purely computational
trick.

Item 3 is apparent because even though `Lock` doesn't release it's thread for
Raku scheduler, it does release a CPU core to the system.

## Benchmarkers, let's go benchmarking!

As I found myself in between of two big tasks today, I decided to make a pause
and scratch the itch of comparing different approaches to locking. Apparently,
we have three different kinds of locks at our hands, each based upon a specific
approach. But aside of that, we also have two different modes of using them. One
is explicit locking/unlocking withing the protected block. The other one is to
use a wrapper method `protect`, available on `Lock` and `Lock::Async`.  There is
no data type for atomic locking, but this is something we can do ourselves and
have the method implemented the same way, as `Lock` does.

Here is the code I used:

```
constant MAX_WORKERS = 50;  # how many workers per approach to start
constant TEST_SECS = 5;     # how long each worker must run

class Lock::Atomic {
    has atomicint $!lock = 0;

    method protect(&code) {
        while cas($!lock, 0, 1) == 1 { }
        LEAVE $!lock ⚛= 0;
        &code()
    }
}

my @tbl = <Wrkrs Atomic Lock Async Atomic.P Lock.P Async.P>;
my $max_w = max @tbl.map(*.chars);
printf (('%' ~ $max_w ~ 's') xx +@tbl).join(" ") ~ "\n", |@tbl;
my $dfmt = (('%' ~ $max_w ~ 'd') xx +@tbl).join(" ") ~ "\n";

for 2..MAX_WORKERS -> $wnum {
    $*ERR.print: "$wnum\r";
    my Promise:D $starter .= new;
    my Promise:D @ready;
    my Promise:D @workers;
    my atomicint $stop = 0;

    sub worker(&code) {
        my Promise:D $ready .= new;
        @ready.push: $ready;
        @workers.push: start {
            $ready.keep;
            await $starter;
            &code();
        }
    }

    my atomicint $ia-lock = 0;
    my $ia-counter = 0;

    my $il-lock = Lock.new;
    my $il-counter = 0;

    my $ila-lock = Lock::Async.new;
    my $ila-counter = 0;

    my $iap-lock = Lock::Atomic.new;
    my $iap-counter = 0;

    my $ilp-lock = Lock.new;
    my $ilp-counter = 0;

    my $ilap-lock = Lock::Async.new;
    my $ilap-counter = 0;

    for ^$wnum {
        worker {
            until $stop {
                while cas($ia-lock, 0, 1) == 1 { } # lock
                LEAVE $ia-lock ⚛= 0; # unlock
                ++$ia-counter;
            }
        }

        worker {
            until $stop {
                $il-lock.lock;
                LEAVE $il-lock.unlock;
                ++$il-counter;
            }
        }

        worker {
            until $stop {
                await $ila-lock.lock;
                LEAVE $ila-lock.unlock;
                ++$ila-counter;
            }
        }

        worker {
            until $stop {
                $iap-lock.protect: { ++$iap-counter }
            }
        }

        worker {
            until $stop {
                $ilp-lock.protect: { ++$ilp-counter }
            }
        }

        worker {
            until $stop {
                $ilap-lock.protect: { ++$ilap-counter }
            }
        }

    }

    await @ready;
    $starter.keep;
    sleep TEST_SECS;
    $*ERR.print: "stop\r";
    $stop ⚛= 1;
    await @workers;

    printf $dfmt, $wnum, $ia-counter, $il-counter, $ila-counter, $iap-counter, $ilp-counter, $ilap-counter;
}
```

The code is designed for a VM with 50 CPU cores available. By setting that many
workers per approach, I also cover a complex case of an application
over-utilizing the available CPU resources.

Let's see what it comes up with:

```
   Wrkrs   Atomic     Lock    Async Atomic.P   Lock.P  Async.P
       2   918075   665498    71982   836455   489657    76854
       3   890188   652154    26960   864995   486114    27864
       4   838870   520518    27524   805314   454831    27535
       5   773773   428055    27481   795273   460203    28324
       6   726485   595197    22926   729501   422224    23352
       7   728120   377035    19213   659614   403106    19285
       8   629074   270232    16472   644671   366823    17020
       9   674701   473986    10063   590326   258306     9775
      10   536481   446204     8513   474136   292242     7984
      11   606643   242842     6362   450031   324993     7098
      12   501309   224378     9150   468906   251205     8377
      13   446031   145927     7370   491844   277977     8089
      14   444665   181033     9241   412468   218475    10332
      15   410456   169641    10967   393594   247976    10008
      16   406301   206980     9504   389292   250340    10301
      17   381023   186901     8748   381707   250569     8113
      18   403485   150345     6011   424671   234118     6879
      19   372433   127482     8251   311399   253627     7280
      20   343862   139383     5196   301621   192184     5412
      21   350132   132489     6751   315653   201810     6165
      22   287302   188378     7317   244079   226062     6159
      23   326460   183097     6924   290294   158450     6270
      24   256724   128700     2623   294105   143476     3101
      25   254587    83739     1808   309929   164739     1878
      26   235215   245942     2228   211904   210358     1618
      27   263130   112510     1701   232590   162413     2628
      28   244143   228978       51   292340   161485       54
      29   235120   104492     2761   245573   148261     3117
      30   222840   116766     4035   241322   140127     3515
      31   261837    91613     7340   221193   145555     6209
      32   206170    85345     5786   278407    99747     5445
      33   240815   109631     2307   242664   128062     2796
      34   196083   144639      868   182816   210769      664
      35   198096   142727     5128   225467   113573     4991
      36   186880   225368     1979   232178   179265     1643
      37   212517   110564       72   249483   157721       53
      38   158757    87834      463   158768   141681      523
      39   134292    61481       79   164560   104768       70
      40   210495   120967       42   193469   141113       55
      41   174969   118752       98   206225   160189     2094
      42   157983   140766      927   127003   126041     1037
      43   174095   129580       61   199023    91215       42
      44   251304   185317       79   187853    90355       86
      45   216065    96315       69   161697   134644      104
      46   135407    67411      422   128414   110701      577
      47   128418    73384       78    94186    95202       53
      48   113268    81380       78   112763   113826      104
      49   118124    73261      279   113389    90339       78
      50   121476    85438      308    82896    54521      510
```

Without deep analysis, I can make a few conclusions:

- atomic is faster than `Lock`. Sometimes it is even indecently faster, though
  these numbers are fluctuations. But on the average it is ~1.7 times as fast as
  `Lock`.
- `Lock.protect` is actually faster than `Lock.lock`/`LEAVE Lock.unlock`. Though
  counter-intuitive, this outcome has a good explanation stemming from the
  implementation details of the class. But the point is clear: use the `protect`
  method whenever applicable.
- `Lock::Async` is not simply much slower, than the other two. It demonstrates
  just unacceptable results under heavy loads. Aside of that, it also becomes
  quite erratic under the conditions. Though this doesn't mean it is to be
  unconditionally avoided, but its use must be carefully justified.

And to conclude with, the performance win of atomic approach doesn't make it a
clear winner due to it's high CPU cost. I would say that it is a good candidate
to consider when there is need to protect small, short-acting operations.
Especially in performance-sensitive locations. And even then there are
restricting conditions to be fulfilled:

- little probability of high number of collisions per lock-variable. I'm not
  ready to talk about particular numbers, but, say, up to 3-4 active locks could
  be acceptable, but 10 and more are likely not. It could really be more
  useful to react a little longer but give up CPU for other tasks than to have
  several cores locked in nearly useless loop.
- the protected operations are to be really-really short.

In other words, the way we utilize CPU matters. If aggregated CPU time consumed
by locking loops is larger than that needed for `Lock` to release+acquire the
involved cores then atomic becomes a waste of resources.

## Conclusion

By this moment I look at the above and wonder: are there any use for the atomic
approach at all? Hm... 😉 

By carefully considering this dilemma I would preliminary put it this way: I
would be acceptable for an application as it knows the conditions it would be
operated in and this makes it possible to estimate the outcomes.

But it is most certainly no go for a library/module which has no idea where and
how would it be used.

It is much easier to formulate the rule of thumb for `Lock::Async` acceptance:

- many, perhaps hundreds, of simultaneous operations
- no high CPU load

Sounds like some heavily parallelized I/O to me, for example. In such cases it
is less important to be really fast but it does matter not to hit the
`max_threads` limit.

## Ukraine

This section would probably stay here for a while, until Ukraine wins the war.
Until then, please, [check out this page!](/donate_to_ukraine.html)

I have already received some donations on my PayPal. Not sure if I'm permitted
to publish the names here. But I do appreciate your help a lot! In all my
sincerity: Thank you!
