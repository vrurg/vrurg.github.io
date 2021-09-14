---
title: Secure JSONification?
tags: Raku JSON security thoughts
#toc: false
#date: 2021-05-05 23:00:00
header:
  teaser: "/assets/images/Camelia-200px-SQUARE.png"
---
There was an interesting [discussion on
IRC](https://colabti.org/irclogger/irclogger_log/raku?date=2021-09-14#l100)
today. In brief, it was about exposing one's database structures over API and
security implications of this approach. I'd recommend reading the whole thing
because Altreus delivers a good (and somewhat emotional 🙂) point on why such
practice is most definitely bad design decision. Despite having minor
objections, I generally agree to him.

But I'm not wearing out my keyboard on this post just to share that discussion.
There was something in it what made me feel as if I miss something. And it came
to me a bit later, when I was done with my payjob and got a bit more spare
resources for the brain to utilize.

First of all, a bell rang when a hash was mentioned as the mediator between a
database and API return value. I'm somewhat wary about using hashes as return
values primarily for a reason of performance price and concurrency unsafety. 

Anyway, the discussion went on and came to the point where it touched the ground
of blacklisting of a DB table fields vs. whitelisting. The latter is really
worthy approach of marking those fields we want in a JSON (or a hash) rather
than marking those we don't want because blacklisting requires us to remember to
mark any new sensitive field as prohibited explicitly. Apparently, it is easy to
forget to stick the mark onto it.

Doesn't it remind you something? Aren't we talking about hashes now? Isn't it
what we sometimes blame JavaScript for, that its objects are free-form with
barely any reliable control over their structure? Thanks TypeScript for trying
to get this fixed in some funky way, which I personally like more than dislike.

That's when things clicked together. I was giving this answer already on a
different occasion: using a class instance is often preferable over a hash.
In the light of the JSON/API safety this simple rule gets us to another rather
interesting aspect. Here is an example SmokeMachine provided on IRC:

    to-json %( name => "{ .first-name } { .last-name }", 
               password => "***" )
        given $model

This was about returning basic user account information to a frontend. This is
supposed to replace JSONification of a Red model like the following:

    model Account {
        has UInt $.id is serial is json-skip;
        has Str $.username is column{ ... };
        has Str $.password is column{ ... } is json-skip;
        has Str $.first-name is column{ ... };
        has Str $.last-name is column{ ... };
    }

The model example is mine.

_By the way, in my opinion, neither first name nor last name do not belong to
this model and must be part of a separate table where user's personal data is
kept. In more general case, a name must either be a long single field or an
array where one can fit something like "Pablo Diego José Francisco de Paula Juan
Nepomuceno María de los Remedios Cipriano de la Santísima Trinidad Ruiz y
Picasso"._

The model clearly demonstrates the blacklist approach with two fields marked as
non-JSONifiable. Now, let's make it the right way, as I see it:

    class API::Data::User {
        has Str:D $.username is required;
        has Str $.first-name;
        has Str $.last-name;

        method !FROM-MODEL($model) {
            self.new: username   => .username,
                      first-name => .first-name,
                      last-name  => .last-name
                given $model
        }

        multi method new(Account:D $model) {
            self!FROM-MODEL($model)
        }

        method COERCE(Account:D $model) {
            self!FROM-MODEL($model)
        }
    }

And now, somewhere in our code we can do:

    method get-user-info(UInt:D $id) {
        to-json API::Data::User(Account.^load: :$id)
    }

With `Cro::RPC::JSON` module this could be part of a general API class which
would provide common interface to both front- and backend:

    use Cro::RPC::JSON;
    class API::User {
        method get-user-info(UInt:D $id) is json-rpc {
            API::Data::User(Account.^load: :$id)
        }
    }

With such an implementation our Raku backend would get an instance of
`API::Data::User`. In a TypeScript frontend code of a private project of mine I
have something like the following snippet, where `connection` is an object
derived from `jayson` module:

    connection.call("get-user-info", id).then(
        (user: User | undefined | null) => { ... }
    );

What does it all eventually give us? First, `API::Data::User` provides the
mechanism of whilelisting the fields we **do** want to expose in API. Note that
with properly defined attributes we're as explicit about that as only possible.
And we do it declaratively one single place.

Second, the class prevents us from mistyping field names. It wouldn't be
possible to have something like `%( usrname => $model.username, ... )` somewhere
else in our codebase. Or, perhaps even more likely, to try `%user<frst-name>`
and wonder where did the first name go? We also get the protection against wrong
data types or undefined values.

It is also likely that working with a class instance would be faster than with a
hash. I have this subject covered in [another post of
mine](https://vrurg.github.io/2020/12/16/Raku-Performance-Note).

Heh, at some point I thought this post could fit into IRC format... 🤷
