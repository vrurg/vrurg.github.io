---
title: "Type And Object Composition"
tags:
    - Raku
    - MOP
category: ARFB
categories:
    - Publications
    - ARFB
logo: /assets/images/Camelia-200px-SQUARE.png
#published: false
---
Practically anything from our surroundings has its own life cycle, with a beginning and the end. Understanding these
cycles is a key to understanding how things work and how these processes can be used for our purposes. In the context
of Raku language the most common cycle we deal with is lifetime of an object. Then again, depending on what is being
discussed, the cycle could be considered very narrowly, with focus on what particular code does; or more extensively,
starting from call to a method-constructor. This article is going to take the most extensive approach by going as far
as considering how types are coming to be, and by stretching the subject all the way down to object destruction (when
and if that happens).

Most focus here would be given to the _class_ as a type kind (according to the definition in the [Metamodel:
Archetypes](/arfb-publication/08-metamodel-archetypes/) article), but other kinds are going to be covered too from the
perspective of a type object lifetime.

_For this article I'd expect you to be at least basically familiar with the Metamodel Object Protocol. There is an
[introduction to the MOP](../05-the-metamodel-introduction-to-mop/) in an earlier publication of this series. Though
it is quite basic and doesn't provide all the necessary details, I hope that what is not immediately clear in
this text can be understood from the context. Otherwise I should apologize and add that writing a textbook was never the
plan as a lack of resources at my disposal makes this a nearly impossible task._

# Where We Don't Start

The lifetime of a type object begins, apparently, in the source code where it is declared and then gets parsed and
prepared by the compiler.  The preparatory work complexity mostly depends on the kind of type object. For example, to
create a generic we'd only need a name. But for a class or a role a lot of pieces are to be collected from the source,
then thrown together to be later fit to each other to form something useful.

The part to be omitted in this article is the grammar implementing the collection job. Firstly, because it would make a
better topic for an article on how the parser works; secondly, because at the moment when this text is being written the
RakuAST parser is not fully ready yet, but there is already no point in studying the legacy one.

Anyway, the general plan of building a new type object, in rough patches, looks like this:

1. Find out what `Metamodel` class would be responsible for the new type object. Say, for Raku classes that'd be
   `Metamodel::ClassHOW`; for enumerations – `Metamodel::EnumHOW`; and so on.
2. Determine the key parameters of the type.
3. Create the new type object.
4. Collect some more pieces.
5. Add them to the object.
6. When there is nothing more to collect then finalize it.

Steps 4-6 are optional as not every type kind has them. Steps 1,2, and 4 are out of the scope of this text. We kinda
enter into the middle of the story.

# And This Is Where We Do Start

Here we pick up from the item 3 of the above list. It's, perhaps, the most atomic and the most simple of them all because
it is about calling the `new_type` method on a metamodel class. Sometimes it is all we need to get a type object ready.
Say, for a generic one[^rakuified_sample]:

```
my \generic = Metamodel::GenericHOW.new_type(:name<T>);
say generic.^name;
say generic; # This is going to die because generics can't be used directly
```

Or slightly more complex, yet still a one-step production kind – subset:

```
my \sset =
    Metamodel::SubsetHOW.new_type:
        :name<MySubset>,
        :refinee(Str),                          # subset MySubset of Str
        :refinement({ .fc.contains("foo") });   #        where { .fc.contains("foo") }
say "AA" ~~ sset;
say "AAFooBB" ~~ sset;
```

***A digress.*** _It is possible to play some tricks not currently available with the legacy Raku grammar but
technically feasible. See [this gist](https://gist.github.com/vrurg/88ed942d85c897772061f7f92bfb85fd)
where we create a custom generic subset._

Procedures are getting tricker with more complex kinds like enums, roles, and classes. And we'll get there later. For
now let's have a closer look at the arguments of the `new_type` method. Apparently, to create different kinds of types
different set of arguments is needed. Even the simple cases of generics and subsets have their own specifics when it
comes down to the `:name`. It is possible to create a nameless generic type, but it doesn't make sense because
instantiation requires a name to locate the final type to replace the generic with. But a subset doesn't need to be
named to do its job.

This somewhat complicates the parser's life because prior to calling the `new_type` method it must pre-collect some
information and what exactly is to be collected depends on what exactly is about to be created. For example, it may
find a name for potentially named types:

```
role Bar ...
class Foo ...
enum Baz ...
```

Or base types for nominalizables, which would later give them predefined names:

```
say Int:D.^name;

role Foo[::T] {}
say Foo[ Str:U() ].^name;
```

Or refinee and, perhaps, refinement for subsets:

```
subset SS1 of Int;                # no refinement
subset SS2 of Real where * > 10;  # and refinee, and refinement
```

Eventually, it is up to a metamodel class to define its requirements by declaring parameters in the `new_type` method.
It is always possible to find out more by looking at the signatures. A way to do it is using a lookup in Rakudo's
sources under the _src/Perl6/Metamodel_ directory[^perl6_dir]:

`~/s/R/r/s/P/Metamodel$ rak 'method new_type' | less`[^rak_app]


```
ClassHOW.nqp:48:                method new_type(:$name, :$repr = 'P6opaque', :$ver, :$auth, :$api, :$is_mixin) {
GenericHOW.nqp:21:              method new_type(:$name) {
NativeHOW.nqp:24:               method new_type(:$name = '<anon>', :$repr = 'P6opaque', :$ver, :$auth, :$api) {
CurriedRoleHOW.nqp:62:          method new_type($curried_role, *@pos_args, *%named_args) {
ParametricRoleHOW.nqp:37:       method new_type(:$name, :$ver, :$auth, :$api, :$repr, :$signatured, *%extra) {
PackageHOW.nqp:19:              method new_type(:$name = '<anon>', :$repr, :$ver, :$auth) {
ModuleHOW.nqp:20:               method new_type(:$name = '<anon>', :$repr, :$ver, :$auth, :$api) {
ConcreteRoleHOW.nqp:47:         method new_type(:@roles, :$name = '<anon>', :$ver, :$auth, :$repr, :$api) {
NativeRefHOW.nqp:25:            method new_type(:$name = '<anon>', :$ver, :$auth, :$api) {
Mixins.nqp:2:                   method new_type($class_type) {
EnumHOW.nqp:56:                 method new_type(:$name!, :$base_type?, :$repr = 'P6opaque', :$is_mixin) {
CoercionHOW.nqp:33:             method new_type($target, $constraint) {
ParametricRoleGroupHOW.nqp:40:  method new_type(:$name!, :$repr) {
DefiniteHOW.nqp:38:             method new_type(:$base_type!, :$definite!) {
SubsetHOW.nqp:55:               method new_type(:$name = '<anon>', :$refinee!, :$refinement!) {
```

At this point the story ends for simple type kinds like the mentioned above generics and subsets. Raku parser is
going to have some more fun finalizing them for our code, which may include installation of corresponding symbols into
a lexical scope for named types. But for complex kinds more has to be done before the finalization phase can be entered.

# Type Object Preparation

A complex type kind needs to be prepared first. Where previously it was possible to find out what to do by inspecting
the method signatures, now comes the hard part because one has to know _protocols_ of every kind to be prepared. Take,
for example, an enum:

```
my \my-enum = Metamodel::EnumHOW.new_type(:name<MyEnum>, :base_type(Str));
my-enum.^add_role(Enumeration);
my-enum.^compose;

my int $index = 0;

sub create-enum-value(\key, str \val) is raw {
    my \enum-val = Metamodel::Primitives.rebless(val, my-enum);
    enum-val.^get_attribute_for_usage('$!key').set_value(enum-val, key);
    enum-val.^get_attribute_for_usage('$!value').set_value(enum-val, val);
    enum-val.^get_attribute_for_usage('$!index').set_value(enum-val, $index++);
    enum-val
}

my-enum.^add_enum_value(create-enum-value("foo", "Foo"));
my-enum.^add_enum_value(create-enum-value("bar", "Bar"));

say "--- Custom enum";
say my-enum.("Foo");
say my-enum.^enum_value_list;
```

All lines between the call to `new_type` and the first `say` – they are about preparing the new
enum[^dont_focus_on_details]. Though, generally speaking, the type itself can be considered as "ready" after the call
to `compose`, what sense an enum without values makes?

This example is as straightforward as possible. The only complication I brought into it is giving it the `Str`
base type. In the real life sometimes more operations are to be done, depending on such factors as how the values are
declared, or if there any traits applied, etc. For myself I separate the operations into "filling with content" and
"fine tuning". Since classes are the kind which can have most diverse kinds of content and the biggest number of
parameters to tune, it would, perhaps, make good time to switch our attention to them.

## Class

To give you an impression of how complex a class is, let me copy over here [the declaration of
`Perl6::Metamodel::ClassHOW` class](https://github.com/rakudo/rakudo/blob/c10c28ae9419609bac09bba3e9f1f133c9eceb20/src/Perl6/Metamodel/ClassHOW.nqp#L1-L27)[^links_to_2023_06]:

```
class Perl6::Metamodel::ClassHOW
    does Perl6::Metamodel::Naming
    does Perl6::Metamodel::Documenting
    does Perl6::Metamodel::LanguageRevision
    does Perl6::Metamodel::Stashing
    does Perl6::Metamodel::AttributeContainer
    does Perl6::Metamodel::MethodContainer
    does Perl6::Metamodel::PrivateMethodContainer
    does Perl6::Metamodel::MultiMethodContainer
    does Perl6::Metamodel::MetaMethodContainer
    does Perl6::Metamodel::RoleContainer
    does Perl6::Metamodel::MultipleInheritance
    does Perl6::Metamodel::DefaultParent
    does Perl6::Metamodel::C3MRO
    does Perl6::Metamodel::MROBasedMethodDispatch
    does Perl6::Metamodel::MROBasedTypeChecking
    does Perl6::Metamodel::Trusting
    does Perl6::Metamodel::BUILDPLAN
    does Perl6::Metamodel::Mixins
    does Perl6::Metamodel::ArrayType
    does Perl6::Metamodel::BoolificationProtocol
    does Perl6::Metamodel::REPRComposeProtocol
    does Perl6::Metamodel::InvocationProtocol
    does Perl6::Metamodel::ContainerSpecProtocol
    does Perl6::Metamodel::Finalization
    does Perl6::Metamodel::Concretization
    does Perl6::Metamodel::ConcretizationCache
```

Scary, isn't it? However, creating a new dummy class is only one step extra, compared to the creation of a generic:

```
my \my-class = Metamodel::ClassHOW.new_type(:name<MyClass>);
my-class.^compose;

my $obj = my-class.new;
say $obj.WHICH;
```

Even the name above is optional: there are anonymous classes in Raku. But this simplicity is not what we all gathered
here for! Therefore it's time to add some spices into the dish:

```
my \my-class = Metamodel::ClassHOW.new_type(:name<MyClass>);
my-class.^add_parent(Cool);
my-class.^add_role(Stringy);
my-class.^compose;

my $obj = my-class.new;
say $obj.WHICH;
```

Barely any explanation is needed to get the point: this snippet is equivalent to the following declaration:

```
class MyClass is Cool does Stringy {}
```

_Let's pretend that our intention is to implement a new kind of strings – this explains the parent class and the role._

Next in this section I'm going to discuss a couple of preparation processes. The order of subsections below does not
reflect the order of the processes while code is compiled. Way more likely that they would interleave, depending on the
particular declaration locations in a class source code.

### Traits

Traits are applied as early as possible. As a matter of fact, anything between the package[^class_is_a_package] name
and its body must be a trait. Yes, the `is` and `does` are too. Consider the example:

```
multi sub trait_mod:<is>(Mu:U \type, :$ctest!) {
    say $ctest;
    say type.^parents(:local);
    say type.^roles_to_compose;
}

class Foo
    is ctest('--- before is')
    is Cool
    is ctest('--- before does')
    does Stringy
    is ctest('--- after does')
{}
```

The output it produces is a clear demonstration of how trait application works:

```
--- before is
()
()
--- before does
((Cool))
()
--- after does
((Cool))
((Stringy))
```

### Packaging

Since classes are packages they can have symbols installed in their [stashes](https://docs.raku.org/type/Stash). As you
know, this is done with `our` modifier:

```
multi sub trait_mod:<is>(Mu:U \type, :$psyms!) {
    say $psyms;
    say type.WHO.keys;
}

class Foo {
    also is psyms('--- before `our`');
    our sub foo {}
    also is psyms('--- after `our`');
}
```

_Yes, `also` is another way to apply a trait._

The output of this snippet is not only about when a symbol gets installed into a package symbol table, but it is also
about the intermixing of different processes during the preparatory stage because we have here a _trait ➔ declaration ➔
trait_ sequence:

```
--- before `our`
()
--- after `our`
(&foo)
```

Apparently, the sub is later available as `Foo::<&foo>` or for a full-name call `Foo::foo()`.

### Roles

Adding a role with `does` is only the first step. It is like a statement of intent. Some extra efforts to be applied
before whatever the role has to offer is used to form the final type object. Wait until we reach [the finalization](./#type-finalization) stage.

### Attributes

Adding an attribute means creating an instance of
[`Attribute`](https://github.com/rakudo/rakudo/blob/2023.06/src/core.c/Attribute.pm6) class and pushing it onto the
attribute list of a package (the package metamodel class must consume
[`Metamodel::AttributeContainer`](https://github.com/rakudo/rakudo/blob/2023.06/src/Perl6/Metamodel/AttributeContainer.nqp)
role; [`Metamodel::ClassHOW`](https://github.com/rakudo/rakudo/blob/2023.06/src/Perl6/Metamodel/ClassHOW.nqp) does
this). But similar to roles, the first step is the smallest, comparing to what's being done at [the
finalization](#type-finalization) stage.

The only nuance I'd like to get covered here is that the `Attribute` object is not the attribute itself. This means that
the object is not the container which holds a value. The container gets allocated later and attached to the low-level
object _representation_ (a class instance, for example) and it'll be one structure per each object.  Contrary to
that, there would exists a sole instance of `Attribute`, attached to its type object, and serving as a collection of
attribute's parameters.

If it is not really clear what I mean, look at this code:

```
class Foo {
    has $.attr;
}
my $obj1 = Foo.new(attr => 42);
my $obj2 = Foo.new(attr => "The Answer");
my $attr = $obj1.^get_attribute_for_usage('$!attr');
say $attr === $obj2.^get_attribute_for_usage('$!attr'); # True
say $attr.get_value($obj1);                             # 42
say $attr.get_value($obj2);                             # The Answer
```

# Type Object Finalization {#type-finalization}

Here comes the complexity. Whatever's been done before is like placing parts in boxes. Fitting them together is a
different story which starts when `.^compose` method is called on a type object template. Don't forget that our focus
is on classes now. Other kinds of types may not need any finalization, as it was stated earlier. Some don't even have
the `compose` method. But since our focus is on the class kind, not only `Metamodel::ClassHOW` [has
it](https://github.com/rakudo/rakudo/blob/c10c28ae9419609bac09bba3e9f1f133c9eceb20/src/Perl6/Metamodel/ClassHOW.nqp#L101),
but the method itself is the biggest among other metamodel classes.

Though before digging up the secrets of a class composition it might make sense to exercise yourself by looking into much
simpler, but doing similar job, [`compose` method of
`Metamodel::EnumHOW`](https://github.com/rakudo/rakudo/blob/c10c28ae9419609bac09bba3e9f1f133c9eceb20/src/Perl6/Metamodel/EnumHOW.nqp#L110C8-L110C8).

## Class

You could follow [the actual source of the `compose`
method](https://github.com/rakudo/rakudo/blob/c10c28ae9419609bac09bba3e9f1f133c9eceb20/src/Perl6/Metamodel/ClassHOW.nqp#L101)
alongside with reading the text. This time the order of subsections would more or less follow the order of processes in
method's body.

### Roles And Attributes

And so, we have a box of parts that we need to assemble into a class. But is their set complete? Likely not if the class
is consuming roles. At this point roles are treated, first of all, as containers from which the class picks
remaining parts it needs.

Technically what happens here is each role [gets
specialized](/arfb-publication/07-roles-or-when-one-is-many/#step-4a-specialization) first. Then a dedicated worker
object called Role To Class Applier is created which, given the list of specialized roles, prepares its workspace to
be ready for the final application.

At the next step the specialized roles are used again to seed class' type checking mechanism, so we can tell if
`Foo ~~ Stringy` in our userland code, for example.

Then comes an unavoidable trick which lets us handle the role-imported attributes when a "diamond" role consumption is
encountered:

```
role Apex { has $.attr; }
role Left does Apex { }
role Right does Apex { }
class Bottom does Left does Right { }
```

An older version of Rakudo compiler would error here because it was thinking that `$!attr` `Attribute` objects coming
from the `Left` and from the `Right` are different attributes (they are, in fact, different instances at this point)
and that this is is a conflict.

It is also possible that `Bottom` declares its own `$.attr` in which case it has to be the winner. It's not a big deal
when we just work with attribute's object, but a public one brings in its accessor method and measures must be taken
to prevent importing a wrong accessor from the roles.

The trick allows to resolve these conflicts by composing class' attributes first and applying the roles afterwards.
Only when all of it is done the remaining (imported) attributes can be eventually composed; though not immediately
after.

### MRO

It is OK to call the `compose` method more than once as the class could be dynamically changed at run-time and need some
adjustments to be done. But some of its parameters are considered immutable and are to be computed only once ever.  The
MRO is one of them. It gets built right after the roles are applied, because by then we already know all our parents.
Though if there are no explicit parents a default one would be implied. Normally it is `Any`[^default_parent_change].

### Multi Candidates And, Again, Attributes

Composition postpones another operation too: incorporation of `multi`-candidate methods. It is not easy to tell at the early
stages of class composition where `proto` of a multi-dispatch method would come from. Largely due to MRO not being
known until lately. When MRO is computed we have means of finding out if there is already a useable `proto` in one of
our parent classes.

Having all `multi`s incorporated also means that at this point all methods are properly installed on the class and
composing the attributes sourced from the roles is safe as no explicitly declared method would be in trouble because of
an imported attribute accessor of the same name.

### Setting Up Instance Finalization

This is just a single method call in the `compose` method body, but it is very important for correct functioning of an
object.

Finalization step is, first of all, about invoking `DESTROY` submethods and doing it in the right order. Depending on
what Raku language revision created the class, it is also mandatory to make sure that `DESTROY`s of consumed roles are
included into the order too (Raku v6.e and later).

### Miscelaneous

At this point the composition makes sure all stubbed methods got their implementations, i.e. there is a `method stubbed
{ say "something useful" }` for `method stubbed {...}`.

Then the class boolification mode is configured (so that simple cases can be easily optimized).

And, then a fallback hook gets installed if there is user-provided `FALLBACK` method.

### BUILDPLAN

A class can be very complex, considering that attributes may have many means of getting initialized, depending on their
types, and/or presence of explicit initializers or defaults, on wether `is built` trait applied, and wether constructor
submethods been present.  We need a plan to do it all in order and miss nothing. We need a `BUILDPLAN` to be precise.
What it is and how it works worth a separate article, but in the meantime a pick into
[`Metamodel::BUILDPLAN`](https://github.com/rakudo/rakudo/blob/2023.06/src/Perl6/Metamodel/BUILDPLAN.nqp) could satisfy
one's curiosity itch. I plan to touch the subject later in the text, but only one aspect of it.

### Finalize The Finalization: Composing Representation

Whatever we've done so far was about building structures, describing the type object. Now, as every part has been picked
up and plugged into its rightful place, the time has come to tell the backing virtual machine to compose an in-memory
representation of the new class. The method `compose_repr` of
[`Metamodel::REPRComposeProtocol`](https://github.com/rakudo/rakudo/blob/c10c28ae9419609bac09bba3e9f1f133c9eceb20/src/Perl6/Metamodel/REPRComposeProtocol.nqp#L4)
is responsible for this task. When it's done our VM is going to have a low-level structure which describes our new type
and lets the VM to take care of aspects such as memory allocation per object instance, type checking, and others.

A class may have different VM representations. The default one is called _P6opaque_. But there are
[others](https://docs.raku.org/language/traits#is_repr_and_native_representations.) too.

### Finishing Touches

By now the composition is basically complete. All left to be done is publishing some of the earlier collected
information to the VM in order to let it know about things it can use later, at the run-time. Things like method cache,
for example.

Also, the last step is to install and, perhaps, propagate user-declared meta-methods like `method ^my-meta(...) {...}`.

And this is, finally, it...

# Class Instantiation

Beginner could make a mistake by considering object construction a simple and cheap operation[^looking_into_mirror].
Why, it's just `Foo.new`! Well, for compiler's sake! `Foo.new(:attr<something>)`...

Remember the earlier mentioned `BUILDPLAN`? When built it is a list of little arrays, no longer than three
elements each, where the first element is an operation code, and the remaining ones are operation arguments. For example,
an entry like `(0, 'Foo', '$!attr')` tells us to seek for `attr` key in the hash of named attributes passed into the
constructor (`:attr<something>` above) and use its value as initializer for `$!attr`.

Roughly, there is code somewhere which is busy interpreting these codes and executing the plan so that when its done our
fresh new object instance has all attributes set and all constructors executed if no errors took place in the meantime.
I say 'somewhere' because there is an interpreter method, implemented by the CORE class `Mu`, but otherwise the compiler
does its best and tries to produce an optimized version of the interpreter.

Anyway, optimized or not, a class of many attributes wouldn't be too fast to setup during object construction time. And
this is not to mention that memory allocations alone often contribute to the overall performance penalties.

Though somebody would tell this story better than me because my experience with the guts of MoarVM is limited; not to
mention that we are mutual enemies with the JVM backend! Just kidding. A little...

## Construction And Destruction

The only aspect of BUILDPLAN I would touch here, though rather tangentially, is class constructors, except for what can
be found [in the documentation](https://docs.raku.org/language/classtut#Construction).

Starting with Raku v6.e submethods are no longer imported from roles into the classes. It means that if your role
declares a `TWEAK` submethod it will be called, no matter if the consuming class has its own `TWEAK` or not:

```
use v6.e.PREVIEW;

role R1 {
    has $.r1;
    submethod TWEAK {
        say ::?ROLE.^name, " TWEAK";
    }
}

class C does R1 {
    has $.c1;
    submethod TWEAK {
        say ::?CLASS.^name, " TWEAK";
    }
}

my $obj = C.new(:c1(42), :r1("answer"));
```

Try removing `use v6.e.PREVIEW` and see what happens. Internally the difference lies in the extra entries added to
the BUILDPLAN – one per each `submethod` found on any type object involved into MRO composition.

There is an interesting consequence of this: a role can declare own `BUILD` submethod without affecting the overall
object construction. Wether it is useful somehow or not – I don't know. All cases where I may need some extra processing
of constructor arguments are well covered either by overriding the method `new`, or by manipulating initialized
attributes in a `TWEAK`.

_Despite of this subsection title, I barely have something to add about the destruction stage on the top of what can be
found in the documentation. Except that don't expect to find any entry for `DESTROY` in the BUILDPLAN. After all, it's
a plan to build something, not to demolish!_

# Phew!

This was a big one. I'm happy about finishing it!

---

[^rak_app]: - I use Raku-native [rak](https://raku.land/zef:lizmat/rak) utility instead of `grep` or `ack` whenever possible.
    - The original output doesn't indent by `method` statement. I done it manually for better readability.

[^perl6_dir]: With RakuAST development the _Perl6_ part is likely to either change or be gone at all.

[^rakuified_sample]: All samples are Rakuified from the perspective of using Raku-specific `.^` call of metamodel
    methods, and from the perspective of using `Metamodel::` namespace. In NQP code the namespace would be
    `Perl6::Metamodel::`, and typical invocation of a metamodel method would look like `$obj.HOW.method($obj, ...)`. I
    would try to remember to be explicit when the code in a sample is NQP, but even if I forget these two traits would
    clearly indicate the language used.

[^dont_focus_on_details]: Don't focus on the details of the sample for now. They purely for demo purposes.

[^class_is_a_package]: Remember that any class or role is, in fact, a package.

[^links_to_2023_06]: This and other links to the Rakudo source code are pointing at 2023.06 release of the compiler.
    This would let the article to remain consistent even if the sources change.

[^looking_into_mirror]: At this moment think of me as pointing finger at own mirror reflection. Memory is like that,
    it wouldn't let go some of the memories about mistakes made...

[^default_parent_change]: A brave one may risk changing the default parent to another class, it's possible. But this may
    have consequences...