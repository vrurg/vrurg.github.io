---
title: New Kid On The Block
tags:
  - Raku
  - module
  - LibXML
  - XML
toc: true
header:
  teaser: /assets/images/Camelia-200px-SQUARE.png
slug: libxml-class-release
date: 2023-06-18
---
The thing is: I hate XML.

OK, not exactly. I hate the way they abuse it, especially in the corporate world. XML, and Java (or Python lately), and
no alternatives allowed. Often, where even CSV would do better – they stick in an XML-based bloatware and get always
happy about it!

But then it turns out that I have this bunch of very different PDFs on my hands, from different sources, produced by
various software tools, but with one thing in common: they all contain data I must pull in and sort out. Lucky me,
nobody puts limits on what this has to be implemented in: "Raku? What is it? Whatever, just make it work!" Fantastic!

Next turn, what do we have for reading PDFs? Oh, oops... Can I convert them into something different? Sure, you can!
Would you be happy about XML? Er... Well, yes, I suppose.

In a while, along with the PDFs, an XLSX spreadsheet pops up. And you all know what is it internally... Moreover, back
then it became apparent to me that [`Spreadsheet::XLSX`](https://raku.land/zef:jnthn/Spreadsheet::XLSX) lacks support
for some key features of the format and I came up with a couple of PRs to implement them. Along the lines I basically
developed a small core for de-/serializing XML into Raku objects. It's limited and only sufficient to serve the needs of
XLSX parsing, but it felt like having some interesting potential. Especially with regard to the tasks I already had on
my hands.

Yet, before doing something as stupid as starting a new project, I checked around first and, apparently, stumbled upon
[`XML::Class`](https://raku.land/zef:jonathanstowe/XML::Class). Unfortunately, the
[`XML`](https://raku.land/zef:raku-community-modules/XML) module, it is based upon, proved to be too slow for the files
I'm dealing with, [`LibXML`](https://raku.land/zef:dwarring/LibXML) is doing way better. Still, `XML::Class` provided me
with a couple of great ideas.

And here we are today: welcome the [`LibXML::Class`](https://raku.land/zef:vrurg/LibXML::Class) module! A swiss army
knife of XML serialization for [The Raku language](https://raku.org).

First of all, the principle I'm trying to follow any time something new is planned: make it easy to start with, yet make
it very capable:

```
use LibXML::Class;
class Record is xml-element {
    has Str $.field1;
    has Int:D $.field2 is required;
}

say Record.new(
        field1 => 'The Answer',
        field2 => 42
    ).to-xml;

say Record.new( field2 => 12 ).to-xml;
```

How much easier could this ever be? There is even better
[example](https://github.com/vrurg/raku-LibXML-Class/blob/main/examples/manual01.raku) in [the
repository](https://github.com/vrurg/raku-LibXML-Class), but I'm not including it here now because I have different
plans for it.

Ok, this is about simplicity. What about capability? The full list of module's features can be found in its
[README](https://github.com/vrurg/raku-LibXML-Class#description) and [the
manual](https://github.com/vrurg/raku-LibXML-Class/blob/main/docs/md/LibXML/Class/Manual.md) explains them in details,
though due to lack of time no proofreading has been done for it and errors of different kinds are guaranteed. That's why
I tried to cover most important topics with [examples](https://github.com/vrurg/raku-LibXML-Class/tree/main/examples).
In this post I'd cover just the most important ones.

## Lazy Deserialization

Say, we have a _huge_ XML with complex structure. Full and immediate deserialization of it would result in hundreds or
thousands of instances of Raku classes created. No fast parser would be of much help here because of the time it takes
to run all the constructors of each and every object. If one needs just one attribute of a single records somewhere in
the structure it'd be definitely stupid waste of computing time and memory and, worst of all, end user patience.

This is not our way. `LibXML::Class` doesn't deserialize until it is really necessary. Consider [an
example](https://github.com/vrurg/raku-LibXML-Class/blob/main/examples/manual01a.raku) from the repository:

```
use v6.e.PREVIEW;
use LibXML::Class;

class Record is xml-element {
    has Str:D $.data is required;
    submethod TWEAK {
        say "+ record";
    }
}

class Root is xml-element {
    has Record:D $.record is required;
    submethod TWEAK {
        say "+ root";
    }
}

my $root = Root.new: record => Record.new(:data("some data"));

say "--- deserializing";
my $root-copy = Root.from-xml: $root.to-xml.Str;
say "--- deserialized";
say $root-copy.record;
say "--- all done";
```

Running it would result in an output like this:

```
+ record
+ root
--- deserializing
+ root
--- deserialized
+ record
Record.new(data => "some data", xml-name => "Record")
--- all done
```

The first two lines are rather understandable: we create a record, then the root object. Hence the prints from their
constructors. But starting from _'--- deserializing'_ line the events get more interesting twist. We only see an output
from `Root`'s constructor, but there is nothing from `Record`. That is because at this point `$.record` is not
initialized yet. `LibXML::Class` is using [`AttrX::Mooish`](https://github.com/vrurg/raku-AttrX-Mooish) to turn the
attribute in a lazy one as if somebody applied `is mooish(:lazy<xml-deserialize-attr>)` trait to it. The effect of this
action is visible right after the end of deserialization is reported with _'--- deserialized'_ line. There you can see
_'+ record'_ from `Record`'s `TWEAK` submethod first, and only after that there is a gist of the record object itself.
Both are easily pinpointed to the `say $root-copy.record` line, where a read from `$.record` resulted in the object
being eventually deserialized and made ready for use.

Now, imagine that the `Record` itself has sub-records, and sub-sub-records, and there are lots and lots of them. But
your code doesn't waste time on instantiating – unless explicitly requested to do so as, apparently, this behavior can
be disabled if necessary. Moreover, it can be triggered on or off at individual level per attribute.

This functionality is not activated implicitly for basic-type attributes like strings, numerics, etc. But one can
enforce it per-attribute, if this is considered helpful

## XML Sequences

Working on `Spreadsheet::XLSX` introduced me to such pretty curious entity as XML sequence. From Raku's perspective it
would be a `Positional`, and an `Iterable`; but neither a `List` nor a `Seq`. Well, in theory it is possible to map it
into one, but that'd be rather tricky and unnatural. Here is the most challenging features of a sequence:

- it can be a multi-type thing; i.e. it may contain different XML elements
- it could contain a huge number of elements
- elements are not necessarily come from the same namespace

Perhaps I miss something here, but even these three points make it somewhat special.

Sure, with certain amount of patience and obstinacy, one could implement them as arrays, but here come one barely
solvable problem: an array attribute would still be deserialized as a whole simply because there are no lazy arrays in
Raku!

Here comes a solution (see [another
example](https://github.com/vrurg/raku-LibXML-Class/blob/main/examples/manual08a.raku)):

```
use v6.e.PREVIEW;
use LibXML::Class;

class Ref is xml-element<ref> {
    has Str:D $.ISBN is required is xml-element;
    has Int:D $.page is required is xml-element;
    submethod TWEAK {
        say "+ ref for ", $!ISBN;
    }
}

class Index is xml-element( 'index',
                            :sequence( Ref, :idx(Int:D) ) )
{
    has Str:D $.title is required;
}

my $index = Index.new: title => "Experimental";

$index.push: 42;
$index.push: Ref.new(:ISBN<1-2-FAKE>, :page(10));
$index.push: Ref.new(:ISBN<3-4-MOCKED>, :page(1001));

say "--- deserializing";
my $index-copy = Index.from-xml: $index.to-xml.Str;
say "--- deserialized";
say $index-copy[1];
say "--- all done";
```

_Along the lines, the sample also demonstrates how advanced capabilities of `LibXML::Class` get activated when
necessary._

Anyway, running this would result in the following output:

```
+ ref for 1-2-FAKE
+ ref for 3-4-MOCKED
--- deserializing
--- deserialized
+ ref for 1-2-FAKE
Ref.new(ISBN => "1-2-FAKE", page => 10, xml-name => "ref")
--- all done
```

And, again, we observe laziness in action! As only the single item on the sequence is read from – only single output is
produced by the `TWEAK`. There is a difference to the attributes though: XML sequence is totally and unexceptionally
lazy. No sequence item is deserialized until read, not even the basic type ones.

Now, let's get back to where it started. In an XLSX worksheet rows are sequence elements (items in terms of
`LibXML::Class` Raku representation); same apply to individual cells. Now, imagine full deserialization of a sheet
consisting of thousand lines with hundreds of columns! Nah, gimme a break... Of course, that would still mean full
parsing of the XML, but, unfortunately, it's unavoidable cost. Yet, it doesn't mean that there gonna be piles of
`LibXML::Node` objects scattered all around your RAM! Fortunately for us, most of the work would be done at the low
level by `libxml` and only pulled up into the Raku land when necessary. In other words, these ops are also mostly lazy.

## Namespacing

This is where I both love it and hate it. Use of namespaces in XML helps resolve so many problems that often times XML
is the only answer to complex problems. Though in my view a way less verbose format could've been developed for these
tasks, but it's too late for any discussions now. Hence my only complain here is about using XML where there are more
appropriate formats that would do better.

Anyway, my goal was to cover as many different combinations of using namespaces as I could. Considering that we have
default namespaces (these defined with `xmlns="..."`), and we have prefixes, and we have priorities, inheritance,
override, and perhaps some other things I forget about; and there are rules on how they apply and match; and that the
way one see and use them with Raku objects must look and feel the same as for XML (or, at least, for `LibXML`
implementation of the standard); so, considering all the above, in the retrospective, I'm not surprised that more than
80% of code development time has been spent on namespacing. Parts of the code underwent like 5-10 rewrites – basically,
the count has been lost long ago...

But it's definitely worth it. Just by looking at [the module's
SYNOPSIS](https://github.com/vrurg/raku-LibXML-Class#more-complex-case) you can see how simple is it to declare and
refer to namespaces!

Then you start reading [the manual](https://github.com/vrurg/raku-LibXML-Class/blob/main/docs/md/LibXML/Class/Manual.md).

Then you come down to see [an example of deriving
namespaces](https://github.com/vrurg/raku-LibXML-Class/blob/main/examples/manual09.raku).

Then there is [an example of imposing
namespaces](https://github.com/vrurg/raku-LibXML-Class/blob/main/examples/manual13.raku).

And only then it gets apparent how convoluted namespacing could be. Yet, we can handle if not all possible variations
of it, but a significant subset, most certainly!

BTW, another feature I wouldn't focus upon but wanna mention anyway is
[XML:any](https://github.com/vrurg/raku-LibXML-Class/blob/main/docs/md/LibXML/Class/Manual.md#xmlany) technique, which
is heavily based upon namespaces. This is an idea I borrowed from `XML::Class` but gave it some extra capabilities,
especially in the area of XML sequence items.

_Examples are intentionally omitted in this section due to their rather bloated sizes._

## Searching

Here comes real magic!

When I encountered `LibXML`, aside of its speed, what made me attracted (let's avoid _emotionally attached_ term,
though...) is its XPath-based `findnodes`. And when I came down to the idea of `LibXML::Class` the method was one of the
two most significant reasons I wanted the module to exists in first place.

Well, you know what? I nearly forgot to implement it, after all. The namespaces, you know: they sucked every last bit of
energy out of me. But, down with them...

Can you spot a catch here? I'll give a hint: laziness. It wouldn't be a big deal to map a `LibXML::Node` to its
deserialization because there is the `unique-key` method which lets us keep track of objects. But what if there is no
object to track yet? What if the node we found is so deeply nested in the source XML that not only there is no
deserialization for it, but for a couple of its parent nodes too?

Solved. The feature can be observed in action [in modified version of SYNOPSIS
code](https://github.com/vrurg/raku-LibXML-Class/blob/main/examples/synopsis.raku). Tests
[_200-pml-parser.rakutest_](https://github.com/vrurg/raku-LibXML-Class/blob/main/t/200-pml-parser.rakutest) and
[_150-find.rakutest_](https://github.com/vrurg/raku-LibXML-Class/blob/main/t/150-find.rakutest) are even better in
demonstrating the feature, but they're apparently harder to read. _200-pml-parser.rakutest_ is specifically focused on
searching for undeserialized yet nodes.

I'm once again avoiding any full samples here. They'd be too big. Just to give you an impression on how it works, here
is the single line which would be at the core of most searches:

```
my LibXML::Class::XML:D @deserializations = $root.xml-findnodes(q«//*[@idx = 3002]»);
```

This is all needed to find deserializations for all XML elements with `idx` attribute set to _3002_.

Wait, don't go! Just one another line and we're almost done here:

```
my Str:D @names = $root.xml-findnodes(q«//*[@idx = 3002]/@name»);
```

This is how find attributes `name` of our elements. So, let's say there is something like this in our Raku:

```
role Named is xml-element {
    has Str:D $.name is xml-attribute;
}

role Indexed is xml-element {
    has UInt:D $.idx is xml-attribute;
}

class Record is xml-element<rec> does Named does Indexed {
    has SubRecord $.sr is xml-element<subrec>;
}
```

The by adding _@name_ to the XPath we'd get `$.name` of the role `Named`. If there are other classes consuming it and
deserialized from the same XML then we gonna get their attributes too, perhaps. Surely, it depends on `$.idx` values.

Pardon? Haven't I told about roles? Oh, my bad! Well, you see them supported. As well as subclassing. Let's not focus on
this.

What's more interesting is that search works with object cloning. It means that even there is 100% probability that
there is single XML element to be found, a sequence would always be returned for a particular XPath expression. Because
if a deserialization gets cloned the first thing the newborn copy does is registers itself with the object registry.

And, sure enough, if search is not needed then turning it off altogether would spare you some memory and processing
times.

## Done

Now I say myself: stop! Or a post would turn into a secondary manual. Before we say each other "see ya!" I would have
one single request to you: if this module ever makes you want to use it – please, make sure it's not for a manually
editable config of your application! XML is great when used properly; and "properly" means to me: read and written by
and only by code, never by human eyes and human hands!
