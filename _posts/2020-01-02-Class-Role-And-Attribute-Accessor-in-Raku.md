---
title: Class, Role And Attribute Accessor in Raku
toc: true
toc_icon: book
tags:
    - Raku
    - role
    - class
    - MOP
---
Quite ingenious title I used here, but it's precise. 

<!--more-->

This story starts with the following case:

```
role R {
    method a { 666 }
}
class C does R {
    has $.a = 42;
}
say C.new.a;
```

What would you expect this to print? 

> *For those with basic or no knowledge in Raku I'd like to explain that a public attribute gets an automatic accessor method. So, when one does `$obj.attribute` it's actually a method call.*  

There could be some disagreement among devs wether the code should output _42_ or _666_. Though Raku states it explicitly that things defined by class have priority over role's declared ones. Hence, we expect _42_ here.

Period, this post is over, everybody is free to go? Alas, [this issue](https://github.com/rakudo/rakudo/issues/3382) says that the code above outputs *666*! Oops... What's going on here?

## Class Composition
**NOTE** In the following text I refer to Rakudo implementation of Raku and Raku MOP specifically.

A new class doesn't just appear as it is declared in Raku. Basically, any class in its initial state, right after the parser done it's job, is a Lego-like set of declarations like attributes and methods, parents, roles, etc. All this has to be eventually put together and composed into a type object which would actually implement the class. The composition is quite a complex process of which we need only few details for now. Primarily, I'm going to talk about the order of things now.

The first major step which class composition does is it collects the roles applied to the class. The roles are first prepared (*it's a long interesting story on its own*) and then all the necessary information gets extracted from them. Then the "spare parts" acquired are mounted onto the class type object.

The next step is installation of multi-methods. They require special handling; but to explain why so would bring us beyond the scope of this post (*another long and interesting story*).

And only then it's the attributes turn to be thrown into the "workshop". Yet, an attribute needs to be composed prior to be used. This stage also includes generation and installation of attribute's accessor and other related methods.

Then goes the rest of the composition, including processing of object build plan, etc. This is not relevant for now.

## What's Wrong?
An attentive reader could have already guessed where the problem is. Raku MOP avoids overwriting already installed methods. If a method is already there, it must not be replaced. Not without a warning at least; though so far I can think of no code in the core metamodel which would do the replacement, neither silently nor verbosely. Having this information in mind, if we get through the composition steps again, we'll see that methods from consumed roles would be installed prior to attribute installation. It means that an attribute won't override an existing method even if it comes from a role. Thus, eventually class `C` will get its method `a` not from class attribute but from role `R`. Bad!

## Solution
The first idea was just to warn about such situations. Not only it turned into a somewhat cumbersome code with limitations like not being able to produce a warning at the run-time (fixable, but some more code of vague quality). It would also result in rather confusing error messages because sometimes a class could consume a role from a 3rd-party distribution which consumes one more role from another 3rd-party module which we are not supposed to know about. Yikes...

Besides, warnings won't fix the breakage of the primary rule of class superiority.

Another proposed solution was to find out if an attribute is going to install a method and skip role's methods of the same name. This would require us to teach attribute object to report those methods. While not being a big problem on its own (we just must remember about `handles` trait which makes it more than just accessor to get installed), it becomes a rather weak point as soon as we think about 3rd-party traits. We can't ignore the fact that they might install their own methods too. And there is no good way for us to know about those methods!

*Frankly saying, this last point didn't even come into my mind initially. It's only now that I realized that my own `AttrX::Mooish` module actually installs few helper methods per attribute.*

At this point the task looked like somewhat rather complex and I estimated it to take quite a time which I didn't have much. But then came an idea: what if we just change the order of composition? Since attributes are prioritized, why don't we install them first?

*Fine, let's play with it bit! – I said to myself. A small experiment won't hurt, wouldn't it?*

From the start, the right  order of composition looked to me like: `attributes` -> `roles` -> `multi-methods` -> etc. This way we get all the methods from attributes installed properly. The good thing is that attribute composition code won't install an accessor if a method of the same name exists in the class but there is no methods from roles yet. The bad things are:

- we may need the information about roles and their parents at any composition run time
- multi-methods of the class are not incorporated and attribute composition doesn't know about their existence yet
- multi-methods cannot be incorporated before roles are applied
- and we can't apply roles prior to class' attributes
- and role attributes are not taken care of yet!

The loop of _roles-attributes-mutlimethods-roles_ dependency has to be broken. In our case it is sufficient to break role application into parts and mix them up with other steps properly. The code responsible for the application resides in `RoleToClassApplier` core metamodel class and is done by its `apply` method. The class is stateless and it's not even instantiated to do its job because all the primary functionality nicely fits into the `apply` method. But this is bad for our task.

So, the first thing I do is split `apply` into `prepare` and `apply` methods. `prepare` only collects all the needed information  from a list of concrete roles and stores the results in class attributes. Then our class composition code is changed to use instantiation of `RoleToClassApplier`.

Now it is possible to re-order the composition steps:

`prepare roles` -> `class attributes` -> `apply roles` -> `mutli-methods` -> `role attributes` -> etc.

The only problem here is that `Metamodel::ClassHOW` is using `compose_attributes` method of `Metamodel::AttributeContainer` role. The method doesn't care about where an attribute is coming from, it just iterates them all. Calling it twice would result in double-composition for class-declared attributes. To prevent it, I used the simplest trick possible: mark an attribute as composed and don't do composition second time. 

Great!

No...

In some tests classes lost their attribute accessors for attributes declared in a role! Luckily, while working on another, experimental and yet unmerged, case I stumbled over a line of code where an attribute object was just copied over from its original role into a destination. In some other cases though it was cloned and then copied. Thus, it was rather easy to guess that the problematic attribute object was previously installed in some other class and got composed there. Making original attribute cloning the default behavior did get things straightened out.

Wow, finally, we're there! 

*And, BTW, at what point a small experiment turned into a full fledged fix? Ah, down with it! Just tell me what's wrong with that test over there?* 

Oh, now it's about `multi`! How come it attempts to install a `multi` over a plain method? Ah, there is an accessor already in place... And of course it is!

Remember? Attribute composer doesn't know about the multi-methods. It simply can't until they're applied. That's why in the initial composition order attributes were processed after the incorporation of multis. This way we can have own `multi` attribute accessors if needed.

Did we came to a situation similar to what we started with? Where the composition process requires information which can only be available after a step which we can only make after the location where the information is needed? I mean,  where need to know about the methods an attribute object would install.

Yes, but no! Because it's the incorporation of `multi`s we must do after some other steps. Yet, the candidates for the incorporation are registered early and we know all of them. Given a means to know a candidate of some name exists, attribute's composition can check this information alongside with checking for existing methods!

I guess some could ask about other traits, including those applied to other pieces of code, which could possibly have their methods installed. We should be ok here because a trait would be installing a method or a multi in such ways that attribute composer will know about them even if the trait do this really early. Or they would doing this after the composition when all attribute-bound methods are gonna be in place already. One way or another, but it is much easier to keep this situation under control.

At this point we're actually done. The final composition order is now:

1. collect roles
2. compose class attributes
3. apply roles
4. incorporate multis
5. compose role attributes
6. other jobs

Voilá!

## DESTROY
As in my [first post](http://blogs.perl.org/users/vadim_belman/2019/12/post.html), this section is like a `DESTROY`  method in Raku, but for this article.

It's not much to say in the conclusion. I had two points to write this (seemingly) long read. First, to share some knowledge about Raku MOP implementation. Second, to sort things out in my mind. It is always much easier to get clearer understanding of a concept by sharing it with others.

For those learning by code and patches, the PR related to the subject is here: [Prioritize class attributes/method over those from roles by vrurg · Pull Request #3397 · rakudo/rakudo · GitHub](https://github.com/rakudo/rakudo/pull/3397/files)

Wish a great New Year of 2020 to everybody! And happy coding to you all!

_Originally posted [on blogs.perl.org](http://blogs.perl.org/users/vadim_belman/2020/01/class-role-and-attribute-accessor.html)_
