---
layout: single-lflat
title: "Advanced Raku For Beginners"
---
{% for post in site.rafb-publication %}
{% comment %}1. [{{ post.title }}]({{ post.url }}){% endcomment %}
{% include archive-single.html %}
{% endfor %}
