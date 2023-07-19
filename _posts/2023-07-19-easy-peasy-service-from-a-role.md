---
title: Easy-peasy Service From A Role
description: ""
date: 2023-07-19
tags: ["Raku", "trait", "roles", "did-you-know"]
toc: true
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
I was always concerned about making things easier.

No, not this way. A technology must be easy to start with, but also be easy in accessing its advanced or fine-tunable
features. Let's have an example of the former.

## Disclaimer

This post is a quick hack, no proof-reading or error checking is done. Please, feel free to report any issue.

# The Task

Part of my ongoing project is to deal with JSON data and deserialize it into Raku classes. This is certainly a task
for [`JSON::Class`](https://raku.land/zef:jonathanstowe/JSON::Class). So far, so good.

The keys of JSON structures tend to use lower camel case which is OK, but we like
[kebabing](https://en.wikipedia.org/wiki/Naming_convention_(programming)) in Raku. Why not, there is
[`JSON::Name`](https://raku.land/zef:jonathanstowe/JSON::Name). But using it:

- Will hide the original names. This would break the principle of easy start because one would rather expect to see them as attributes of an object. Having both the original naming and kebabed would be more desirable.
- Would require a lot of manual work on my side.

# The Assets

There are roles. At the point I came to the final solution I was already doing something like[^fictional-naming]:

```
class SomeStructure does JSONRecord {...}
```

[^fictional-naming]: Naming is totally fictional.

Then there is [`AttrX::Mooish`](https://raku.land/zef:vrurg/AttrX::Mooish), which is my lifevest on many occasions:

```
use AttrX::Mooish;
class Foo {
    has $.foo is mooish(:alias<bar>);
}
my $obj = Foo.new: bar => "the answer";
say $obj.foo; # the answer
```

Apparently, this way it would still be a lot of manual interaction with aliasing, and that's what I was already doing
for a while until realized that there is a bettter way. But be back to this later...

And, eventually, there are traits and MOP.

# The Solution

## Name Translation

That's the easiest part. What I want is to `makeThisName` look like `make-this-name`. Ha, big deal!

```
unit module JSONRecord::Utils;

our sub kebabify-attr(Attribute:D $attr) {
    if $attr.name ~~ /<.lower><.upper>/ {
        my $alias = (S:g/<lower><upper>/$<lower>-$<upper>/).lc given $attr.name.substr(2);
        ...
    }
}
```

I don't export the sub because it's for internal use mostly. Would somebody need it for other purposes it's a rare case where a long name like `JSONRecord::Utils::kebabify-attr($attr)` must not be an issue.

_The sub is not optimal, it's what I came up with while expermineting with the approach. The number of method calls and regexes can be reduced._

I'll get back later to the yada-yada-yada up there.

## Automate Attribute Processing

Now we need a bit of MOP magic. To handle all attributes of a class we need to iterate over them and apply the aliasing. The first what comes to mind is to use role body because it is invoked at the early class composition times:

```
unit role JSONRecord;

for ::?CLASS.^attributes(:local) -> $attr {
    # take care of it...
}
```

Note the word "early" I used above. It actually means that when role's body is executed there are likely more roles waiting for their turn to be composed into the class. So, there are likely more attributes to be added to the class.

But we can override `Metamodel::ClassHOW` `compose_attributes` method of our target `::?CLASS` and rest assured no one would be missed:

```
unit role JSONRecordHOW;
use JSONRecord::Utils;

method compose_attributes(Mu \obj, |) {
    for self.attributes(obj, :local) -> $attr {
        # Skip if it already has `is mooish` trait applied – we don't want to mess up with user's intentions.
        next if $attr ~~ AttrX::Mooish::Attribute;
        JSONRecord::Utils::kebabify-attr($attr);
    }
    nextsame
}
```

## The Role Does It All

Basically, that's all we currently need to finalize the solution. We can still use role's body to implement the key elements of it:

```
unit role JSONRecord;
use JSONRecordHOW;

unless ::?CLASS.HOW ~~ JSONRecordHOW {
    ::?CLASS.HOW does JSONRecordHOW;
}
```

Job done! _Don't worry, I haven't forgot about the yada-yada-yada above!_

But...

The original record role name itself is even longer than `JSONRecord`, and it consists of three parts. I'm lazy. There are a lot of JSON structures and I want less typing per each. A trait? `is jrecord`?

```
unit role JSONRecord;

multi sub trait_mod:<is>(Mu:U \type, Bool:D :$jrecord) is export {
    unless type.HOW ~~ JSONRecordHOW {
        type.HOW does JSONRecordHOW
        type.^add_role(::?ROLE);
    }
}
```

Now, instead of `class SomeRecord does JSONRecord` I can use `class SomeRecord is jrecord`. In the original case the win is even bigger.

## The Yada???

There is absolutely nothing funny about it. Just a common way to keep a reader interested!

Seriously.

I want `AttrX::Mooish` to do the dirty work for me. Eventually, what is needed is to apply the `is mooish` trait as shown above. But the traits are just subs. Therefore all is needed now is to:

```
&trait_mod:<is>($attr, :mooish(:$alias));
```

Because this is what Raku does internally when encounters `is mooish(:alias(...))`. The final version of the kebabifying sub is:

```
our sub kebabify-attr(Attribute:D $attr) {
    if $attr.name ~~ /<.lower><.upper>/ {
        my $alias = (S:g/<lower><upper>/$<lower>-$<upper>/).lc given $attr.name.substr(2);
        &trait_mod:<is>($attr, :mooish(:$alias));
    }
}
```

Since the sub is used by the HOW above, we can say that the `&trait_mod<is>` would be called at compile time[^not-always].

[^not-always]: Most likely, but there are exceptions. It barely changes a lot, but certainly falls out of the scope of this post.

## The Use

Now, it used to be:

```
class SomeRecord does JSONRecord {
    has $.aLongAttrName is mooish(:alias<a-long-attr-name>);
    has $.shortname;
}
```

Where, as you can see, I had to transfer JSON key names to attribute names, decide where aliasing is needed, add it, and make sure no mistakes were made or attributes are missed.

With the above rather simple tweaks:

```
class SomeRecord is jrecord {
    has $.aLongAttrName;
    has $.shortname;
}
```

Job done.

## The Stupidy

Before I came down to this solution I've got 34 record classes implemented using the old approach. Some are little, some are quite big. But it most certainly could've taken much less time would I have the trait at my disposal back then...