#!/usr/bin/perl

=head1 NAME

stan - Threaded MH scan

=cut

my($VERSION)='1.0';

use Getopt::Long;
use Pod::Usage;
use IO::Handle;
use List::Util qw(max);
use Term::ReadKey;
use Text::ParseWords;
use MIME::Base64;
use POSIX;

=head1 SYNOPSIS

stan [<scan options>]

=head2 Options

All command-line options to B<stan> which are not listed below are
passed unaltered and directly to L<scan(1)>.

=over 8

=item -b or -body

Show the body of the message in the output.  If you need to turn
this off, you can use -nobody.

=item -d fmt or -date fmt

Specify the format for the date using L<strftime(3)> C<%> sequences.
The default is C<%m/%d> for month/day in 0 padded numeric form.

=item -t fmt or -time fmt

Specify the format for the time (used when messages are less than 24 hours
old) using L<strftime(3)> C<%> sequences.  The default is C<%H:%M> for
hour:minute in 0 padded numeric, 24-hour form.

=item -v or -version

Print version and exit

=item -h or -? or -help

print this short help, then exit.

=item -H or -manual

Print the full manual, then exit.

=item -L or -license

Print the software license, then exit.

=back

=cut

my(@OPTIONS)=qw(
	body|b!
	time|t=s
	date|d=s
	version|v
	scan-help
	help|h
	manual|H
	license|L
);
my(%ARG)=(
	'time'	=> '%R',
	'date'	=> '%m/%d',
);

my($DUP)=0;

unshift(@ARGV, shellwords(`mhparam stan`));

Getopt::Long::Configure('pass_through', 'bundling_override', 'ignore_case');
unless(GetOptions(\%ARG, @OPTIONS)) {
     pod2usage(-verbose => 1, -exitval => 1);
} 

if($ARG{'version'}) {
	print basename($0), ' ', $VERSION, "\n";
	exit(0);
} elsif($ARG{'help'}) {
	pod2usage(-verbose => 1, -exitval => 0);
} elsif($ARG{'manual'}) {
	pod2usage(-verbose => 2, -exitval => 0);
} elsif($ARG{'license'}) {
	pod2usage(-verbose => 99, -exitval => 0,
		-sections => ['LICENSE', 'COPYRIGHT']);
}

=head1 DESCRIPTION

Listing messages so that you can see the threading is helpful, but not
implemented in MH.  B<stan> fixes this issue by calling L<scan(1)> for
you and buildng the the threaded view before displaying.  In order to
build the threaded view, B<stan> must have full control over the output
of L<scan(1)>.  Because of this, the one limitation to using B<stan> is
that the output is not configurable.

=cut

my($RS, $US)=(chr(036), chr(037));

my($FORMAT)=join($RS,
	'%4(msg)',
	'%<(cur)+%|%<(unseen)-%>%>',
	'%<{replied}<%>'.
		'%<{forwarded}>%>'.
		'%<{resent}d%>'.
		'%<{encrypted}E%>'.
		'%<{list-id}l%>'.
		'%<{in-reply-to}r%>'.
		'%<{content-type}%<(match multipart/signed)s%>%>'.
		'%<{content-type}%<(match multipart/encrypted)e%>%>'.
		'%<{content-type}%<(match multipart/mixed)a%>%>',
	'%(clock{date})',
	'%<(mymbox{from})%<{to}To:%14(decode(friendly{to}))%>%>'.
		'%<(zero)%17(decode(friendly{from}))%>',
	'%(decode{subject})',
	'%{Message-ID}',
	'%{In-Reply-To}',
	'%{References}',
	'%(zputlit{body})',
	$US
);

$/="$RS$US\n";

my($SCAN)=IO::Handle->new;
my(%MAIL)=();
my($msg, $status, $info, $time, $from, $subject, $id, $reply, $refs, $body);

my($FMT);
my($TIMEW)=3;

my($COLS, $ROWS, $WIDTH, $HEIGHT)=GetTerminalSize(*STDOUT);

=pod

Message are sorted by time, not by message number.  All messages
in a threaded group are sorted based on the time of the most
recently received message in that thread.

=cut

sub bytime {
	$MAIL{$a}{'time'} <=> $MAIL{$b}{'time'}
}

=pod

The output format of B<stan> is: C<MMMMRI DD/DD F*  S*> where C<MMMM>
is message number, C<R> is read/unread/current, C<I> is info flags,
C<DD/DD> is month/day, C<F*> is From, and C<S*> is Subject.  The subject
will be indented based on where it exists in the thread.

=cut

sub print_msg {
	my($msg, $indent)=@_;
	my($space)=' 'x($indent*2);

	return unless($MAIL{$msg});

	if($MAIL{$msg}{'scan'}) {
		$MAIL{$msg}{'scan'}[5]=~s/^\s*/$space/;
		print substr(sprintf($FMT, @{$MAIL{$msg}{'scan'}}), 0, $COLS), "\n";
		$indent++;
	}
	
	foreach my $child (sort bytime @{$MAIL{$msg}{'replies'}}) {
		&print_msg($child, $indent);
	}

	delete($MAIL{$msg});
}

=pod

The info field will be populated based on information the characteristics
of the message. The message

=over 8

=item -

has been replied to,

=item |

has been forwarded or re-distributed,

=item +

has been replied to and either forwarded or re-distributed,

=item E

was sent encrypted,

=item L

is either signed or encrypted and arrived from a mailing list,

=item l

is part of some kind of mailing list,

=item R

is either signed or encrypted and is a reply to another message,

=item r

is a reply to another message,

=item s

is signed,

=item e

is encrypted, or

=item .

may have an attachment (or may not, this method has mixed results).

=back

=cut

sub info {
	local($_)=@_;
	my($in, $out)=(' ', ' ');

	/a/		and $in='.';
	/e/		and $in='e';
	/s/		and $in='s';
	/r/		and $in='r';
	/r[se]/	and $in='R';
	/lr/		and $in='l';
	/lr?[se]/	and $in='L';

	/E/		and $out='E';
	/</		and $out='<';
	/>/		and $out='>';
	/d/		and $out='|';
	/-[fd]/	and $out='+';

	return($in.$out);
}

=pod

By default, the threaded output of B<stan> does not contain any of the
body text of a message (unlike L<scan(1)>).  However, if you would still
like to see the body, you can supply the special C<-body> option to
B<stan> or place C<stan: -body> into your F<.mh_profile>.  If you do
this, you will notice that the output is far more readable than the
same output from L<scan(1)>.  This is because most MIME content is removed
allowing more of the text of the message to show through.

=cut

sub body {
	local($_)=@_;

	s|(([a-zA-Z0-9+/]{68}\s)+)|decode_base64($1)|sge;

	s/^--\S.*$//mig;
	s/=\n//sg;
	s/\s*=([0-9a-f]{2})/chr(hex($1))/ige;
	s/\nContent-Type:([ \t].*?\n)*//sig;
	s/^Content-[\w-]+:.*$//mig;
	s/^X-[\w-]+:.*$//mig;
	s/^\s*This is a multi-part message.*$//mig;
	s/^\s*This is a MIME-encapsulated message.*$//mig;
	s/^MIME-Version: .*$//mig;
	s/^Date: .*$//mig;
	s/\n-- \n.*$//s;
	s|^\s*//.*||mg;
	s|/\*.*\*/||sg;
	s|<style[^>]*>.*?</style>||sig;
	s/[\w*@>-]+\s*{\s*[\w-]+:.*?}//sg;
	s/<.*?>/ /g;
	s/&nbsp;/ /gi;
	s/&lt;/</gi;
	s/&gt;/>/gi;
	s/\s+/ /sg;
	s/^\s+//s;

	s/[[:^print:]]//g;

	return($_);
}

open($SCAN, '-|', 'scan', @ARGV, '-width', '2048', '-format', $FORMAT);
while(<$SCAN>) {
	chomp;

	($msg, $status, $info, $time, $from, $subject, $id, $reply, $refs, $body)
		=split(m/$RS/o);

	$id=~s/^.*?<//;
	$id=~s/>.*?$//;
	$reply=~s/^.*<//;
	$reply=~s/>.*?$//;

	if(exists($MAIL{$id})) {
		$DUP++;
		$id.="-$DUP";
	}

	$MAIL{$id}{'reply-to'}=$reply;
	$MAIL{$id}{'refs'}=[reverse($refs=~m/<(.*?)>/g)];
	$MAIL{$id}{'parent'}=undef;

	$MAIL{$id}{'time'}=$time;
	if($^T-$time < 86400) {
		$time=strftime($ARG{'time'}, localtime($time));
		$time=~s/\s*([ap])\.?m\.?\s*/\L$1/i;
		$TIMEW=length($time) if(length($time)>$TIMEW);
	} else {
		$time=strftime($ARG{'date'}, localtime($time));
	}
	$MAIL{$id}{'scan'}=[
		$msg,
		$status,
		&info($info),
		$time,
		$from,
		$subject,
		$ARG{'body'}?&body($body):''
	];
}
close($SCAN);

=pod

All message metadata is read into memory, then organized by thread, then
finally displayed to the screen.  Therefore, when using B<stan> you may
notice a lag on large message scans which is not normally seen when just
using L<scan(1)>.

=cut

foreach my $mid (keys(%MAIL)) {
	foreach my $ancestor ($MAIL{$mid}{'reply-to'}, @{$MAIL{$mid}{'refs'}}) {
		if($ancestor && $MAIL{$ancestor}) {
			$MAIL{$mid}{'parent'}=$ancestor;
			push(@{$MAIL{$ancestor}{'replies'}}, $mid);

			while($ancestor) {
				$MAIL{$ancestor}{'time'}=
					max($MAIL{$ancestor}{'time'}, $MAIL{$mid}{'time'});
				$ancestor=$MAIL{$ancestor}{'parent'};
			}
			last;
		}
	}
}

=pod

When multiple messages are in reply to the same parent, they will be
displayed in the order in which they were received.

=cut

foreach my $mid (keys(%MAIL)) {
	$MAIL{$mid}{'time'}+=$MAIL{$msg}{'scan'}[0]/10000 if($MAIL{$msg}{'scan'});
}

$FMT="%4d%1s%-2s%-${TIMEW}s %s  %s";
$FMT.=' << %s' if($ARG{'body'});

foreach my $mid (sort bytime keys(%MAIL)) {
	&print_msg($mid, 0) unless($MAIL{$mid}{'parent'});
}

=head1 AUTHOR

William Totten

=head1 LICENSE

BSD 3-Clause License

=head1 COPYRIGHT

  Copyright (c) 2017, William Totten
  All rights reserved.
  
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  
  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
  
  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
  
  * Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.
  
  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

