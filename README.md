mh-utils
========

The mh-utils package is a small set of utilities to compliment the use of the
[MH Message Handling System](https://wikipedia.org/wiki/MH_Message_Handling_System).
Most specifically, it is used (and some features only work) with the
[NMH](https://savannah.nongnu.org/projects/nmh/) implementation of MH.


heynow
------

The `heynow` program is a replacement for the default MH `whatnow` program.
It provides a fully feature compatible (to nmh) interface at base, but
extends the functionality in a number of notable ways.

#### Input Markup

Email in the modern world is vastly different than it was when the
RAND corporation first wrote MH in 1979.  At that time, the idea of
mobile phones wasn't something people were thinking of, let alone
smart phones which could show you your email.

However, in today's world, the concepts of small screens which change
width as the screen rotates, and the subsequent need for reflow are
paramount to successful email collaboration.  Additionaly, formatting
like emphasis, lists of items, and tables are necessary concepts.

So, how does a plain text MH user thrive in today's email world?  This
issue is the central purpose of `heynow`.  It provides a capability
for an MH user to easilly intput the text they want and have it
easilly consumed by anyone, regardless of their mail client and the
ever changing size of their screen.

This feat is accomplished by adding support for formatting messages
using a program called [pandoc](http://pandoc.org/).  Pandoc is an
amazing tool which can take many different input format types and
output them in a clean HTML format capable of being an easilly
readable `text/html` equivalent to your plain text input.  The resulting
output can have in-line pictures, support beautiful reflow (even
in bulleted lists), and/or basic font/style formatting.

The default input format is pandoc's extened markdown syntax (which
was derived, in part, from standard email conventions).  However,
other input formats, such as `t2t` and `rst` are supported.

#### Alias Management

When composing messages in nmh, it is the `send` program which usually
performs alias expansion, right before sending.  If you have aliases
in your message, you often will have to run the `whom` program before
sending to see where the mail is really going.  However, wouldn't it
be nice if you could see that list (and possibly update it) while
editing the message itself?

The capability is provided with `heynow` to perform that alias expansion
inside the draft, so you can see and modify it more easilly.  By adding
the setting `heynow-edit: -expand` to your *.mh_profile* file, `heynow`
will even perform this expansion automatically before each `edit`.  This
means that a command like `comp -to my_alias` will result in the expanded
alias being immediately viewable in the draft.

Beyond adding additional ease of use to the expansion of aliases, alias
managemnt and quering functionality is added.  Aliases can be added,
deleted, and queried from within `heynow`.

#### GPG Support

Digitally signing and encrypting messages is a really important email
functionality which has never really taken off.  The reason for this
is largely because it is difficult or cumbersome to do.  This is no
more evident than in MH.  To this end, support for signing, encrypting,
and even signing/encrypting your messages is made much easier.

The additional commands `sign`, `encrypt`, `pubkey`, and `keyring` are
added to sign, encrypt, attach your public key, and attach your entire
public keyring to an outgoing message easilly.

You still have to have a working GPG configuration to accomplish use
this functionality.

N.B. Only the `gpg` program is supported at this time.


schow
-----

The `schow` program is a curses based replacement for the interactive
part of `mhshow`.  It combines the efforts of `mhshow`, `mhlist`, and
`mhstore` into one program (and uses them to do the heavy lifting) to
simplify email reading.

#### Interface

  1. The top of the interface contains a locked header section.  This
     section will not scroll off the screen while the message is being
	viewed.  To keep this message small, long headers are not line
	wrapped.  Instead, you can use the `<` and `>` keys to scroll
	across the lines.

  2. The menu contains a drop-down for each part (if the message is
     multipart), a "view" menu which can be used to see the message
	in different ways (or to save it), the message number being
	viewed, and a status section which is used to convey information
	about the message to the viewer (e.g. signature validation).

  3. The body of the message (or viewable content area of non-body
     message parts) which can be scrolled using the standard keys
	found in popular pagination programs like `more` and `less`.
	The vi-style `hjkl` and arrow keys also work as expected.

You can use the `tab` key to move between the body and two menus.  If
a message contains only one part, then the `tab` key moves only between
the body section and the view menu.

#### Features

The interface allows you to zoom into and out of messages if your terminal
width is too small to accurately display the message content.

You can add your own view menu options by putting entries into your
*.mh_profile* file.  This allows you to have easy access to multiple
ways of viewing a content type, since different files of the same
type are best served by different programs sometimes.


html2msg
--------

The `html2msg` program tries to make intelligent choices about how to
display `text/html` message content.  A common gripe among MH users is
that they with MH would violate mail standards and display the less
formatted/accurate `text/plain` message in favor of a more accurate
representation (usually `text/html`).

MH users, existing a terminal environment, this argument seems straight 
forward and reasonable.  However, this only seems like the correct
choice; it is not.  Loosing all formatting is not a good choice, and it
can lead to misunderstanding of a message.

The standard solution to this problem is to send the `text/html` through
a terminal web browser like `w3m`, `elinks`, `lynx`, ... and this isn't
the best alternative either.  While these web browsers do their best
to render the content, they often fall so short that the `text/plain`
message really would have been a better alternative.

This is where the `html2msg` program comes in, it attempts to find a
middle ground for normal correspondence.  The middleground is an
attempt to take an HTML formatted message and convert it to a 7-bit,
flat ASCII representation which *still has* the required formatting.
This seeming feat of magic is performmed by converting the message
into [markdown](https://en.wikipedia.org/wiki/Markdown) format.  Markdown
is a format designed, in part, from the conventions of pre-HTML email, so
it only makes sense that it is used turn text with markup into flat
text.

linklister
----------

The `linklister` program is a simple program which reads email in
HTML, markdown, wiki, or text formats and looks for links to documents
and images on the world wide web.  The only output of `linklister` are
these links.

This is a great tool for quickly scanning and finding link content in
an email.  It's intended use is with the `schow` functionality to add
context sensitive menu options for messages.  By adding the following
line to your `.mh_profile`,  you can have a drop-down menu item to display
links in an email for text/html messages:

  schow-links-text/html: linklister %f

To have this drop-down menu for all messages, you can simply put:

  schow-links-text: linklister %f

This tool pulls links from the messages by scraping them with regular
expressions, and does not implement a full HTML parser.  This makes it
fast and able to read multiple message formats; however, it also makes
it imperfect and capable of missing links it doesn't understand how to
parse.


qp2ascii
--------

[Quoted Printable](https://en.wikipedia.org/wiki/Quoted-printable)
is a staple of email, its use is recommended in countless email related
RFC's, and its use is completely and unmistakenly widespread.  It is
very often used even when the message is otherwise written in 7-bit,
flat ASCII.  When replying to and forwarding messages, MH ignores
Quoted Printable and just passes it on as if it was `text/pain`.

The purpose of `qp2ascii` is to take that QP encoding, and make it
`text/plain` for the purposes use in your message.  The great thing
about Quoted Printable is that the only character sequence to worry
about is an equal (=) sign followed by 2 hexadecimal digits.  This
3 character sequece shows up very infrequently in normal email, and
so `qp2ascii` can normally be run against any text with a low chance
of undesired alteration.


stan
----

The `stan` program is a wrapper around the standard MH `scan` program.  It
adds a threaded view to the normal `scan` output.  It is identical in
behaviour to `scan` with the following two exceptions:

  1. The output is threaded, with the subject indented based on what it
     is in reply to, and the order of messages is rearranged to be in
	threaded order.

  2. The format (and thus resulting output) is set in `stan`, and not
     changeable.  Because `stan` is a wrapper, it must know exactly what
	is output from the underlying `scan` program, and so it must override
	any customized formatting you normally have with `scan`.

Other than these two differences, it supports all the same command-line
arguments as `scan`, and they are, in fact, passed on to the underlying
`scan` run unmodified.

