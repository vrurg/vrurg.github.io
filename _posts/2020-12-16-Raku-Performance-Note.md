---
title: A Note On Raku Performance
tags: Raku performance
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
Just another day before Christmas and one more great [Raku Advent
Calendar](https://raku-advent.blog/) article: [Day 14: Writing Faster Raku code,
Part
I](https://raku-advent.blog/2020/12/14/day-15-writing-faster-raku-code-part-i).
Nothing foreshadowed a surprise until I stumbled over a statement:

> But objects in are slow, so I use a nested array.

However surprising it might be to the most of my readers, but the statement is
wrong. Though not this alone but also the fact that in the article where the
author, Wim Vanderbauwhede, meticulously tests nearly every alternative, this
particular one remains unproved. I couldn't pass by this time and had to bust
the myth. And here it goes.

# Setting The Target

First, let's define the challenge. The statement says that a tree represented as
a Raku array outperforms an object representation. In turn I state that: _a
properly defined and used class outperforms an `Array` with the current
implementation of Rakudo compiler_.

The last part is an important constraint because the situation may change any
time with more optimizations implemented. But the current state of things can be
explained with some help of my article [Everything Is An
Object](/arfb-publication/02-everything-is-an-object-mop/). Arrays are no
exception. Every time we write something like `@a[0]` we use a shortcut to
`@a.AT-POS(0)`.  Or, it would be more correct to say that we invoke a sub
implementing postcircumfix operator `[]` and the code behind the scene is
`&postcircumfix:<[ ]>(@a, 0)`. It is the `&postcircumfix:<[ ]>` sub which
eventually calls `AT-POS` for us.

One may ask: why? The answer is the abstraction level which allows us to do
things like:

```raku
class Foo { 
    method AT-POS($i) { "**$i**" } 
} 
say Foo.new[42]; # **42**
```

While this example on its own is rather primitive, the real life use allows to
simplify a lot of use cases by hiding boilerplate code behind simple operations.
In turn, this leads to less error-prone code. After all, it's a trade-off we
sometimes make.

BTW, I still remember the times when for real high performance one used to
inline assembler code into their C program!

Besides, it could be one of you, who would eventually implement the
optimizations which will skyrocket the speeds of arrays and hashes. Once set
your foot into the land of the core sources and there will likely be no
return...

Anyhow, I made my statement. It is now time to prove it.

# Preparing The Battleground

There was an easy path. I could simply define a tree manually, create two
different representations of it... Nah! Boring, boring, boring... Besides, the
original article was about parsing Fortran sources. I haven't written a Raku
grammar for too long and felt like needing some refreshment in the area.

Eventually, my task list got the following shape:

1. Write a [grammar](https://docs.raku.org/language/grammars)
1. Create different [actions](https://docs.raku.org/language/grammars#Action_objects) for it 
1. Benchmark parse time for each action
1. Use the AST tree built at the parsing stage to benchmark its traversal

The grammar took the most of my time. No, I wasn't writing a Fortran parser. Not
even close. Not even close to a fully functional expression parser. Just
something sufficient to build an AST tree. And yet I was doing all kinds of
mistakes and errors. Anyway, it was fun! Raku grammars are something special.

The I prepared three action classes: one to form an array tree representation,
one based on `ExprNode` class, and one dummy which has all the statements, the
two other actions has, but builds nothing. The latter serves as the baseline to
measure the time it takes the compiler to handle array- and object-based data
structures.

The last part is to actually do the benchmarking. Sounds simple: take the start
time, run the code, measure the duration. But the thing I learned with my laptop
is about throttling: don't trust the measurements taken on two consequent runs.
Apparently, the most common case is when a busy benchmark causes CPU overheating.
Consequently, the second and any following benchmark is getting less computing
power due to the lowered CPU frequency.

Even on systems where throttling or other techniques of manipulating CPU/bus
frequencies are not used outcomes of sequentially ran benchmarks might be
affected by parallel processes or any other events taking place in a concurrent
environment.

For quite some time now I usually run different versions of code in parallel
simultaneously to equalize the conditions they're coping with. Roughly, it means
doing something like:

```raku
my $test-num = 0;
for @tests -> &test-code {
    ++$test-num;
    start {
        my $st = now;
        &test-code;
        say "duration #$test-num: ", now - $st;
    }
}
```

As usual, there is a catch: neither OS nor Raku is giving no warranty as to how
soon a new thread will start. Reporting `$st` for each test may reveal delays
sufficient for the throttling or anything else to step in and cause biased
timings. Solution? Basically, any race give it to us: a starting pistol! Or a
kind of. 

The common scenario is for supervisor code to make sure that all
contesters are ready and give them a signal to start. In Raku my favourite tool
to implement this is [`Promise`](https://docs.raku.org/type/Promise):

```raku
my @ready;
my @done;
my $supervisor = Promise.new;

for @tests -> &test-code {
    my $test-ready = Promise.new;
    @ready.push: $test-ready;
    @done.push: start {
        $test-ready.keep;
        await $supervisor;
        ... # Benchmarking happens here
    }
}

await @ready;
$supervisor.keep;
await @done;
```

This way we make sure that all parallel benchmarks start at the same time, give
or take. Apparently, this doesn't ensure 100% synchronicity, but it's as close
to the goal as possible.

Because I want to do two benchmarks - one for parse, one for traverse, - the
script will need two synchronizations of the kind.

# Fight!

Here is what I came up with. Don't use it as a sample of a good coding style as
it's more of a sample of "gimme the result, now!" style.

```raku
grammar SimpleExpr {
    rule TOP {
        ''
        | <expr>
    }

    rule expr {
        $<lhs>=<term> [ <infix> $<rhs>=<expr> ]?
    }

    token term {
        | <value>
        | '(' ~ ')' <expr>
        | <prefix>? <term>
    }

    token value {
        \d+
    }

    proto token prefix {*}
    token prefix:sym<-> { <.sym> }
    token prefix:sym<+> { <.sym> }

    proto token infix {*}
    token infix:sym<+> { <.sym> }
    token infix:sym<-> { <.sym> }
    token infix:sym<*> { <.sym> }
    token infix:sym</> { <.sym> }
}

constant EMPTY = 0;
constant VAL = 1;
constant PFX_NEG = 2;
constant PFX_NOP = 3;
constant IFX_ADD = 4;
constant IFX_MIN = 5;
constant IFX_MUL = 6;
constant IFX_DIV = 7;

class ArrayTree {
    method TOP($/) {
        make $/<expr> ?? $/<expr>.ast !! [EMPTY]
    }
    method term($/) {
        if $<expr> {
            make $<expr>.ast;
        }
        elsif $<prefix> {
            make [$<prefix>.ast, $<term>.ast];
        }
        else {
            make [VAL, $<value>.ast]
        }
    }
    method value($/) {
        make $/.Int
    }
    method prefix:sym<+>($/) { make PFX_NOP }
    method prefix:sym<->($/) { make PFX_NEG }
    method infix:sym<+>($/) { make IFX_ADD }
    method infix:sym<->($/) { make IFX_MIN }
    method infix:sym<*>($/) { make IFX_MUL }
    method infix:sym</>($/) { make IFX_DIV }
    method expr($/) {
        if $<infix> {
            make [$<infix>.ast, $<lhs>.ast, $<rhs>.ast]
        }
        else {
            make $<lhs>.ast
        }
    }
}

class ExprNode {
    has $.code;
    has $.lhs;
    has $.rhs;
    method ops {
        with $!rhs {
            $!lhs, $!rhs
        }
        else {
            $!lhs,
        }
    }
}

class NodeTree {
    method TOP($/) {
        make $/<expr> ?? $/<expr>.ast !! ExprNode.new(:code(EMPTY))
    }
    method term($/) {
        if $<expr> {
            make $<expr>.ast;
        }
        elsif $<prefix> {
            make ExprNode.new(:code($<prefix>.ast), :lhs($<term>.ast));
        }
        else {
            make ExprNode.new(:code(VAL), :lhs($<value>.ast));
        }

    }
    method value($/) {
        make $/.Int
    }
    method prefix:sym<+>($/) { make PFX_NOP }
    method prefix:sym<->($/) { make PFX_NEG }
    method infix:sym<+>($/) { make IFX_ADD }
    method infix:sym<->($/) { make IFX_MIN }
    method infix:sym<*>($/) { make IFX_MUL }
    method infix:sym</>($/) { make IFX_DIV }
    method expr($/) {
        if $<infix> {
            make ExprNode.new(:code($<infix>.ast), :lhs($<lhs>.ast), :rhs($<rhs>.ast));
        }
        else {
            make $<lhs>.ast
        }
    }
}

class DummyTree {
    method TOP($/) {
        make EMPTY
    }
    method term($/) {
        if $<expr> {
            make $<expr>.ast;
        }
        elsif $<prefix> {
            make PFX_NOP;
        }
        else {
            make VAL;
        }

    }
    method value($/) {
        make $/.Int
    }
    method prefix:sym<+>($/) { make PFX_NOP }
    method prefix:sym<->($/) { make PFX_NEG }
    method infix:sym<+>($/) { make IFX_ADD }
    method infix:sym<->($/) { make IFX_MIN }
    method infix:sym<*>($/) { make IFX_MUL }
    method infix:sym</>($/) { make IFX_DIV }
    method expr($/) {
        if $<infix> {
            make $<infix>.ast;
        }
        else {
            make $<lhs>.ast
        }
    }
}

my $bench_expr = '(-3*((10+12)/13))*((100-11*(3+(4/-2)))/(123-+23))';

sub parser(Mu $actions is raw, $repeats) {
    my $ast;
    my $st = now;
    for ^$repeats {
        $ast = SimpleExpr.parse($bench_expr, :$actions).ast;
    }
    my $et = now;
    ($et - $st), $ast
}

proto traverse($,$) {*}
multi traverse(Positional:D $ast, $repeats) {
    my sub _trvs(@node) {
        my $count = 1;
        for 1,2 -> $idx {
            with @node[$idx] {
                $count += _trvs($_) if $_ ~~ Positional && $_[0] != VAL;
            }
        }
        $count
    }
    my $st = now;
    for ^$repeats {
        my $count = _trvs($ast);
    }
    now - $st
}
multi traverse(ExprNode:D $ast, $repeats) {
    my sub _trvs($node) {
        my $count = 1;
        for $node.ops -> $op {
            $count += _trvs($op) if $op ~~ ExprNode && $op.code != VAL;
        }
        $count
    }
    my $st = now;
    for ^$repeats {
        my $count = _trvs($ast);
    }
    now - $st
}

my @stage1_ready;
my @stage2_ready;
my @bench_done;
my $supervisor_stage1 = Promise.new;
my $supervisor_stage2 = Promise.new;

for ArrayTree, NodeTree, DummyTree -> $actions is raw {
    my $ready1 = Promise.new;
    my $ready2 = Promise.new;
    @stage1_ready.push: $ready1;
    @stage2_ready.push: $ready2;
    @bench_done.push: start {
        $ready1.keep;
        await $supervisor_stage1;
        my ($duration, $ast) = parser($actions, 10000);
        say $actions.^name, " parse: ", $duration;
        $ready2.keep;
        await $supervisor_stage2;
        unless $ast ~~ Int {
            $duration = traverse($ast, 100000);
            say $actions.^name, " traverse: ", $duration;
        }
    }
}

await @stage1_ready;
$supervisor_stage1.keep;
await @stage2_ready;
$supervisor_stage2.keep;
await @bench_done;
```

I tried to reproduce a structure akin to what Wim is using for his task:

- digital codes for tree nodes
- an array representing a node consist of a code value and 1 or two operand
  elements
- if an operand is an array then it's the root node of a subtree
- values are also represented as arrays
  
The grammar parses expressions without any respect paid to operator priorities,
except for prefix ops `-` and `+` which are tightly bound to the term they
precede.

The expression used in the script is totally random and meaningless. Something I
just typed in to make a long one.

Code in action classes is intentionally being kept as identical as it's only
possible to make the time spent on code unrelated to the data manipulations as
identical as possible. For this reason `DummyTree` still uses `make` even though
it's meaningless in the context of this action class. It serves both the purpose
of maintaining the probability of code inlining at the same level as for
`ArrayTree` and `NodeTree`; and for the purpose of including the time it takes to
call `make` into the final duration.

There is no traversal for `DummyTree` case because there nothing to traverse.
For this reason traversal benchmarks of `ArrayTree` and `NodeTree` can only be
compared one to another without attempt to calculate the baseline timing.

Traversal code simply counts a number of nodes it encounters. This is to make it
possible to check if both algorithms do walk the whole tree by comparing the
counts.

# Results

I did several runs of the script. A typical outcome looks like this:

```
DummyTree parse: 11.1933962
NodeTree parse: 11.6332386
ArrayTree parse: 11.8440641
NodeTree traverse: 4.54844838
ArrayTree traverse: 6.26943534
```

I saw a couple of results where parsing into an array was even a little tiny bit
faster than parsing into the class. But overall tendency is class approach
beating the array by approximately 2% on parsing by measuring the overall code
run time. This is equivalent to pure data processing time needed to handle the
`ExprNode` objects 20-50% less then time spent on handling arrays.

Yet, though there is no clear way to measure the time spent on non-data
processing code for traversal, the results here are even more spectacular as the
sub traversing the `ExprNode` tree is about 30% faster than array traversal. And
this number is more or less consistent over the runs.

Aside from being faster, use of a node class also allows us to define some nice
well-incapsulated API to work with tree nodes. For example, while debugging I
wanted nice-looking output of the tree structure. So, I came up with a
`gist` method to print a subtree under a node:

```raku
    method gist {
        given $!code {
            when EMPTY { '' }
            when VAL { ~$!lhs }
            when PFX_NOP { $!lhs.gist }
            when PFX_NEG {
                "[" ~ $_ ~ "]"
                ~ "-" ~ ($!lhs ~~ ExprNode
                            ?? "\n" ~ $!lhs.gist.indent(2)
                            !! $!lhs)
            }
            when IFX_ADD..IFX_DIV {
                "[" ~ $_ ~ "]"
                ~ <+ - * />[$_ - IFX_ADD]
                ~ "\n" ~ $!lhs.gist.indent(2)
                ~ "\n" ~ $!rhs.gist.indent(2)
            }
        }
    }
```

And here is what it gives me with `say $ast` for the expression I used for benchmarking:

```
[6]*
  [6]*
    [2]-
      3
    [7]/
      [4]+
        10
        12
      13
  [7]/
    [5]-
      100
      [6]*
        11
        [4]+
          3
          [7]/
            4
            [2]-
              2
    [5]-
      123
      23
```

For a real parsing task an AST node object would provide the best means to
implement functional API around it.

# Conclusion

Not much to say here. Just don't let the urban legends to drive you and choose
your tools carefully.
