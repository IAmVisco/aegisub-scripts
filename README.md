# Aegisub Scripts
Repository with personal scripts for Aegisub

# Table of contents
* [Clipper](#clipper)
* [Blur and Glow](#blur-and-glow)
* [Line height fix](#line-height-fix)
* [Trim spaces](#trim-spaces)

# Clipper
A fork of [lyger's](https://github.com/lyger) and [lae's](https://github.com/lae) [Clipper](https://github.com/idolactivities/vtuber-things/tree/clipper-v1.0.1/clipper), simplified and modified to encode the whole video without any stitching but applying .ass color correction.

# Blur and Glow
Forked and bandage edited version of [unanimated's Blur and Glow script](https://unanimated.github.io/ts/scripts-manuals.htm#blurglow). Added an option to fix script breaking on line breaks with `{\r}` and changed default button for quick Enter slap.

# Line height fix
A script to insert line height/spacing tags based on [this guide](https://www.md-subs.com/line-spacing-in-ssa) in case your font has super weird vertical spacing.
Inserts line break instead of the `@` symbol in the line.

# Trim spaces
Trims leading and trailing spaces from selected lines. Also removes spaces around `\N` tag. Useful for YouTube CCs post-processing.