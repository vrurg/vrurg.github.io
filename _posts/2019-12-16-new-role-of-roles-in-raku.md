---
title: New Role Of Roles In Raku
toc: true
toc_icon: book
tags: Raku roles MOP
header: 
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---

My morning started today with a cup of cold tea and an IRC request. The latter was coming from Elizabeth Mattijsen asking to write a paragraph on my recently merged work on Raku roles. 
<!--more-->
There was a little problem though: I have no idea how to fit it into a single paragraph! And so I was left with no choice but to start blogging for the first time in many years.

*Note.* For those of you who consider themselves Raku experts I'd rather recommend skipping the next two sections and proceed directly to the technical details in `Changes`.

## Once upon a time...
... there was a project which I was implementing to support a my boss' project. The structure of the code was heavily based on roles. This is the pattern I tend to use: split functionality into manageable as small as possible pieces and compose them into final code.

Of course, roles fits the pattern perfectly...

... or wait, not really! Soon it became clear that I'm missing a few crucial features in by then actual Rakudo implementation.

But before I proceed I'd like to explain a concept in Raku for those who happened to stumble upon this post while lacking in-depth knowledge of the language. I'm currently talking about [`submethod`s](https://docs.perl6.org/language/objects#Submethods). In brief, a `submethod` is not inheritable by a subclass. Or, putting it other way around, it's a method which belongs exclusively to its type object. Or so I thought.

Another important property of roles in Raku is that they're getting flattened down into the class consuming them. In other words, if one is trying to consider them as a kind of an abstract class that'd be totally wrong. When a role is consumed by a class it is used as source of attribute and method objects which are copied over into the class at its construction time. For example, this code:

```
role Foo {
    method foo { }
}

class Bar does Foo {
}

class Baz is Bar {
}

say Bar.^method_table.keys;
say Baz.^method_table.keys;
```

would print:

```
(foo)
()
```

And from this output we see that class `Bar` does have a method named `foo` despite no methods declared in class body. Contrary, `Baz` consumes nothing and its method table is empty.

Here comes the first problem I have encountered: `submethod`s were not considered sole property of the roles they're defined in but are copied over into the consuming class too! To say the least, this looked like an inconsistency to me. To demonstrate why is it so, I always use the case of that above mentioned project of mine. It was supposed to consist of a few command line tools, each being implemented via its own application class. Each class inherits from a couple of other classes and consumes directly or indirectly a set of roles. Each component represents its own part of functionality and provides a set of configuration variables and command line options.

Combining all this manually for each application was too cumbersome and prone to errors. But with `submethods`  the implementation turned into a more or less simple introspective walking over the class and role tree and collecting the data from `submethod`s. Everything looked fine until I started receiving duplicates because of `submethod`s duplication for cases where a class didn't have its own version. From this moment on once rather elegant solution started loosing its elegance due to rather cryptic checks which are most likely wouldn't be clearly understood by anybody who would pick up my work after me.

And that's not all. For those of you who don't know, in Raku constructors and destructors are `submethod`s  too. Now, if a role define a constructor `TWEAK`, for example, we have two different scenarios:

1. A consuming class doesn't  have it's own `TWEAK` submethod. In this case role's constructor would be installed into the class and executed.
2. A consuming class does have a `TWEAK` submethod. Then role's `TWEAK` would never be called unless the class code takes care of it. If the functionality provided by role requires proper initialization this could pose a problem. Especially in cases where such situation results in an action at distance.

Those are just two of the problems I discovered by the time. Because comprehensive walkthrough would require me to mention diamond role consumption ( `C` consumes `R1` and `R2` where both roles in turn consume `R3`) as well as few other edge cases, I'd better stop now.

It took months of discussions in Rakudo's GitHub repository issues and in [problem solving](https://github.com/perl6/problem-solving/) before I felt ready to put my hands on the task.

## Language versioning

As you may probably know, Raku language has a couple of versions. So far, there're two language releases marked as Raku 6.c and 6.d respectively. With 6.e is currently being in development and planned for release at some point in time in late 2020.

Another thing to be mentioned is that one of the core policies of Rakudo compiler development is backward compatibility. What it means on practice is that some code created years ago must be successfully ran by todays compiler despite of being written for an older language release or even before the first release in some cases. But reality tells us that full backward compatibility could pull back language development by preventing it from incorporating features which break it.

Raku has a solution for this. It is called `use v6.<version>;` pragma which declares what language release our code expects to be compiled against. For example, if you try the following (here and then I'll be using `raku` command which is available since Rakudo release 2019.11; for earlier releases one must replace it with `perl6`):

```
raku -e 'use v6.c; my $a = 1; undefine $a'
```

there will be no output. But:

```
raku -e 'use v6.d; my $a = 1; undefine $a'
```

will result in the following message:

```
Saw 1 occurrence of deprecated code.
================================================================================
undefine seen at:
  -e, line 1
Will be removed with release v6.e!
Please use another way: assign a Nil; for Arrays/Hashes, assign Empty or () instead.
--------------------------------------------------------------------------------
Please contact the author to have these occurrences of deprecated code
adapted, so that this message will disappear!
```

This way Raku is capable of implementing some backward-incompatible functionality without actually breaking the existing code. 

Moreover, a single project may consist of modules implemented using either of the currently supported language releases.

If one wants to give a try to untested upcoming language release he must append `.PREVIEW` suffix to the version: `use v6.e.PREVIEW;` is the way to go for impatient ones.

And the last note about terminology. Two equivalent terms could be used alongside in this post: *language version* and *language release*. While basically representing same entity, the first stands for full version number including `6.` part (i.e. `6.c`, `6.d`, `6.e`) whereas the second is about the letter in the version: `c`, `d`, `e`.

## Changes
### Versioning

As it was discussed, the changes I planned were incompatible with older Raku versions. In some cases it is necessary to know what language version a type object was created with to know how to handle it correctly. It is now possible to find out a type object language revision with `^language-revision` method:

```
raku -e 'use v6.e.PREVIEW; class Foo { }; say Foo.^language-revision'; # e
raku -e 'use v6.c; class Foo { }; say Foo.^language-revision' # c
```

### MRO

In addition to traditional method resolution order which reports back a class' inheritance tree, it is now possible to include roles into the list alongside with classes. I call it *Rolified MRO* or *RMRO*.

Moreover, RMRO handles diamond consumption. Consider the following:

```
role R0 { }
role R1 does R0 { }
role R2 does R0 { }
class C does R1 does R2 { }
say C.^mro(:roles).map: *.^name; # (C R2 R1 R0 Any Mu)
say C.^roles.map: *.^name;       # (R2 R0 R1 R0)
```

This way we get the proper representation of *flattening down* concept because, as a matter of fact, `R0` is actually consumed by `C` just once, contrary to the perception which might be created by `^roles` method output.

Similar to how `^mro` method got a new `:roles` parameter, `^roles` method has received support for `:mro` adverb, allowing us to get properly flattened down list of roles only for a class:

```
say C.^roles(:mro).map: *.^name # (R2 R0 R1)
```

#### Diamond Bugs

There was also a family of bugs related to the above code. One with submethods was causing Rakudo to freeze. 

Another one was resulting in duplication of attributes and methods on the consuming class. Try modifying `R0` in the above code by adding an attribute to it:

```
role R0 { has $.a; }
```

Rakudo 2019.07 would then complain:

```
===SORRY!=== Error while compiling /Users/vrurg/src/Raku/experiments/2019-12-16 blog post/mro.raku
Attribute '$!a' conflicts in role composition
at /Users/vrurg/src/Raku/experiments/2019-12-16 blog post/mro.raku:4
```

But now it is totally legal code with single exception when `R0` is parameterized:

```
role R0[::T] { has T $.a; }
role R1 does R0[Int] { }
role R2 does R0[Str] { }
class C does R1 does R2 { }
```

In this case `$.a` is being parameterized into two different attributes and therefore in this case we deal with a real duplication.

### Constructors And Destructors (6.e)

This change is heavily dependent on RMRO.

A role can now have it's own constructors and destructor and they're guaranteed to be invoked same way, as for classes:

```
use v6.e.PREVIEW;

role R0 { 
    has $.a; 
    submethod TWEAK {
        $!a = "set in R0";
        say "R0";
    }
}
role R2 does R0 {
    submethod TWEAK {
        say "R2";
    }
}
role R1 { 
    submethod TWEAK {
        say "R1";
    }
}
class C does R1 does R2 { 
    submethod TWEAK {
        say "C";
    }
}

say C.^mro(:roles).map: *.^name;
C.new.a.say;
```

Output:

```
(C R2 R0 R1 Any Mu)
R1
R0
R2
C
set in R0
```

Note the order of constructor invocation following the reverse order of RMRO, same way as it happens with ordering of classes.

Replacing revision `e` with `d` in the version pragma would cause the compiler to  bail out with an error.

Though there is not much to be said about this change, I think it's the most important of all. I started using it already in a new project. Yes, I'm the impatient one sometimes!

### Hiding Roles

A role can now be hidden from MRO. I.e. it is possible to apply `is hidden` trait:

```
role R0 { has $.a; }
role R2 does R0 { }
role R1 is hidden { }
class C does R1 does R2 { }
say C.^mro_unhidden(:roles).map: *.^name; # (C R2 R0 Any Mu)
say C.^mro(:roles).map: *.^name;          # (C R2 R0 R1 Any Mu)
```

The hidden status is also preserved for when a role is puned.

### Relaxed Parameterization Lookup

This change is not  directly related to the rest of the work. But it seemed to be easy to implement, so I done it. Actually, the key word here is *'seemed'* as the task turned out to be a bit more tricky than it looked at the first glance. Anyway, it is now possible to:

```
role R[::T] {
    method foo {
        say "R.foo";
    }
}
class C does R[Str] {
    method foo {
        say "C.foo";
        self.R::foo;
    }
}

C.new.foo; 
# C.foo
# R.foo
```

### A Method To `WALK` Them All

#### A Lyrical Digression

What is great about use of submethod for construction/destruction is that their invocation happens semi-magically, without user interaction.  My mentioned above project needed this kind of 'magic' too, but I had to implement it manually.

At some point the question arose: how should we handle submethods in the new functionality? How do we invoke those which are not constructors/destructors? The ideas was:

- Have `$foo.sub-method` to call all submethods of the name found in MRO implicitly.
- Leave the current approach as is and:
	- add operators similar to the existing `.+` and `.*`
	- add a method

At some point the operators approach won. The only question was: how do we name them? The problem is that we might equally well need to call the submethods in both direct and reverse RMRO order. I made a joke about `.?+`, `.?-` only to find out that it's not that hard to have them implemented.

And so I got them into the code, to the total despair of Alex Daniel who was virtually screaming on IRC something like: *Oh no! No more new operators!* His well-grounded 😉 position was later backed by Jonathan Worthington and there was no choice left but to pull the changes out.

That's how the story of two new operators ends...

Was I unhappy? I rather not. And even opposite to that because I didn't like the idea of overloading Raku's symbol space with new operators too. It's just so that the other alternatives I saw then looked even worse to me.

Thanks to Jonathan, he's not only rejected the ops but also pointed out at yet undocumented method `WALK`. Despite not been documented, the method is covered by `roast` what makes it a part of the language specification. Its name with the functionality it already provided made it the ideal candidate. 

#### What's new to `WALK`

- It now can accept a method name as the first positional parameter in addition to the former `:name<method-name>`:
```
$obj.WALK("method");
```
- Three new adverbs: `:roles`, `:submethods`, `:methods`. The last two are *True* by default. So, if one needs to exclude, say, methods he'd need to use `:!methods` explicitly.
- `WALK` returns an object of new type `WalkList` which provides the functionality of batch-calling the methods found using `invoke` method:
```
$obj.WALK("method").invoke($pos-arg, :$named-arg)
```
    `invoke` returns a list of return values, each being itemized. `Slip`s are disrespected and converted into `List`s prior to returning them to prevent confusion when number of return values is not equal to the number of methods found.

The `WalkList` class is also a callable allowing the following construct:

```
$obj.WALK('method')($pos-arg, :$named-arg)
```

Two other useful methods it provides are:

- `reverse` to call found methods in reverse order, similar to constructors ordering
- `quiet` to suppress exceptions, wrap them in `Failure`s, and return those back to user.

Perhaps, the new `WALK` functionality  would be best demoed by the following code:

```
use v6.e.PREVIEW;

role R0 { 
    submethod foo(|c) {
        say $?ROLE.^name, ": ", c.perl;
    }
}
role R2 does R0 { 
    submethod foo(:$die, |c) {
        die "Test" if $die;
        say $?ROLE.^name, ": ", c.perl;
    }
}
role R1 { 
    submethod foo(|c) {
        say $?ROLE.^name, ": ", c.perl;
    }
}
class C does R1 does R2 { 
    submethod foo(|c) {
        say $?CLASS.^name, ": ", c.perl;
    }
}
my $obj = C.new;
say "Found: ", $obj.WALK('foo', :roles).map: *.^name;
say "No roles:";
$obj.WALK('foo')(:class<only>);
say "Basic:";
$obj.WALK('foo', :roles)(answer => 42);
say "Reverse:";
$obj.WALK('foo', :roles).reverse.(answer => 42);
say "With failure:";
say $obj.WALK('foo', :roles).quiet.(:die).map: *.^name;
```

It results in the following output:

```
Found: (Submethod Submethod Submethod Submethod)
No roles:
C: \(:class("only"))
Basic:
C: \(:answer(42))
R2: \(:answer(42))
R0: \(:answer(42))
R1: \(:answer(42))
Reverse:
R1: \(:answer(42))
R0: \(:answer(42))
R2: \(:answer(42))
C: \(:answer(42))
With failure:
C: \(:die)
R0: \(:die)
R1: \(:die)
(Bool Failure Bool Bool)
```

Note how passing `:die`  results in no output from `R2` but a `Failure` in the second position of the return values list.

*Note* that `WALK` functionality is yet largely experimental and may change in the future. 

### New Role-scoped Variable
Role code can now learn about it's concretization using `$?CONCRETIZATION` variable. If you don't know what it means then most likely you don't need it:

```
role R {
    method foo { say $?CONCRETIZATION.HOW.^name } # ConcreteRoleHOW
}
```

### Minor additions to MOP

- Attribute lookup methods: `^has_attribute($name)`, `^has_public_attribute($name)`, `^attribute_table`. 
- Added `find_method_qualified` method to `ConcreteRoleHOW`

## Compatibility
What is to be taken into account by anybody trying the new functionality is that it is largely backward-incompatible with earlier Raku language releases. In particular, it means that roles implemented with 6.e language version are not compatible with 6.c and 6.d classes.  An attempt to consume such a role with older language revision class will result in an error. For some it could have unexpected outcomes like:

```
raku -e 'use v6.e.PREVIEW; role R { }; my $a = "A" but R'
Type object Str+{R} of v6.c is not compatible with R of v6.e
  in block <unit> at -e line 1
```

Unfortunately, this behavior is expected because:

```
$ raku -e 'say Str.^language-revision'
c
```

Most of the core classes are implemented in 6.c core. For the moment, the only classes provided by 6.e are:

- `Grammar`
- `PseudoStash`
- There are plans for two more classes: `Dict` and `Tuple` but they're unimplemented yet.

The problem with compatibility lies exactly in the way how submethods and constructors/destructors are handled. Classes implemented using older semantics might and very likely will not handle the semantics of the new roles correctly. Best case scenario would result in immediate errors. Worst case would include subtle errors really hard to catch.

The one solution to this complication is for a project to have a 6.c or 6.d module and declare some roles in it:

*role6d.rakumod*:
```
use v6.d;

role R is export { }
```

```
use v6.e.PREVIEW;
use role6d;

class C does R { }
my $d = "foo" but R;
```

Note also, that class `C` is of 6.e and it successfully consumes `R`. That is because later language revision object do know how to handle older roles and can take care of them.

## DESTROY
Consider this section as if it's this post's destructor method. As `DESTROY` is not necessarily to be invoked in Raku, this section is optional too. 😉

For those of you who learn by example, look at [changes to roast](https://github.com/perl6/roast/pull/581/files) where tests cover as much of the implemented functionality as I was able to remember about.

For those who likes studying the source, [the final version of PR](https://github.com/rakudo/rakudo/pull/3348) would be useful too.

*There is an earlier version of the PR which I had to reverse and reconstruct manually due to improper use of git rebasing which broke build of all the PR commits.*

I hope for all these changes to be eventually properly documented, but prior the dust needs to settle down, bugs squashed, some details perhaps polished.

Ah, and in case you wonder about: the project this all started with has never been completed because my boss has changes his mind and my work wasn't demanded ever since...

_Originally posted [on blogs.perl.org](http://blogs.perl.org/users/vadim_belman/2019/12/post.html)_
