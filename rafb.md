---
layout: single-lflat
title: "Advanced Raku For Beginners"
description: >-
    A series of articles about Raku's not so evident features
    and quirks.
---
{% for post in site.rafb-publication %}
{% comment %}1. [{{ post.title }}]({{ post.url }}){% endcomment %}
{% include archive-single.html %}
{% endfor %}
