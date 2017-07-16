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
use POSIX;

=head1 SYNOPSIS

stan [<scan options>]

=head2 Options

All command-line options to B<stan> which are not listed below are
passed unaltered and directly to L<scan(1)>.

=over 8

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
	version|v
	scan-help
	help|h
	manual|H
	license|L
);
my(%ARG)=();

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

my($RS)=chr(036);

my($FORMAT)=join($RS,
	'%4(msg)',
	'%<(cur)+%|%<(unseen)-%>%>',
	'%<{List-Id}l%>'.
		'%<{In-Reply-To}r%>'.
		'%<{content-type}%<(match multipart/signed)s%>%>'.
		'%<{content-type}%<(match multipart/encrypted)e%>%>'.
		'%<{content-type}%<(match multipart/mixed)a%>%>'.
		'%<{content-type}%<(match multipart/related)a%>%>',
	'%(clock{date})',
	'%<(mymbox{from})%<{to}To:%14(decode(friendly{to}))%>%>'.
		'%<(zero)%17(decode(friendly{from}))%>',
	'%(decode{subject})',
	'%{Message-ID}',
	'%{In-Reply-To}',
	'%{References}',
);

my($SCAN)=IO::Handle->new;
my(%mail)=();
my($msg, $status, $info, $time, $from, $subject, $id, $reply, $refs);
my($ancestor);

my($fmt)="%4d%1s%1s %5s %s  %s";

my($cols, $rows, $width, $height)=GetTerminalSize(*STDOUT);

=pod

Message are sorted by time, not by message number.  All messages
in a threaded group are sorted based on the time of the most
recently received message in that thread.

=cut

sub bytime {
	$mail{$a}{'time'} <=> $mail{$b}{'time'}
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

	return unless($mail{$msg});

	if($mail{$msg}{'scan'}) {
		$mail{$msg}{'scan'}[5]=~s/^\s*/$space/;
		print substr(sprintf($fmt, @{$mail{$msg}{'scan'}}), 0, $cols), "\n";
		$indent++;
	}
	
	foreach my $child (sort bytime @{$mail{$msg}{'replies'}}) {
		&print_msg($child, $indent);
	}

	delete($mail{$msg});
}

=pod

The info field will have an C<l> if the message is sent to a list,
C<r> if the message is in reply to another message, C<s> if the message
was digitally signed, and C<e> if the message was encrypted.  Any message
which is sent to a list or replied to which is either signed or encrypted
will list the letter capitalized (e.g. C<L> or C<R>).  An info field
of C<.> means that the message might have an attachement.

=cut

my(%INFO)=(
	'l'		=> 'l',
	'lr'		=> 'l',
	'ls'		=> 'L',
	'le'		=> 'L',
	'lrs'	=> 'L',
	'lre'	=> 'L',
	'r'		=> 'r',
	'rs'		=> 'R',
	're'		=> 'R',
	's'		=> 's',
	'e'		=> 'e',
	'a'		=> '.',
);

open($SCAN, '-|', 'scan', @ARGV, '-width', '2048', '-format', $FORMAT);
while(<$SCAN>) {
	chomp;

	($msg, $status, $info, $time, $from, $subject, $id, $reply, $refs)
		=split(m/$RS/o);

	$id=~s/^.*?<//;
	$id=~s/>.*?$//;
	$reply=~s/^.*<//;
	$reply=~s/>.*?$//;

	$mail{$id}{'reply-to'}=$reply;
	$mail{$id}{'refs'}=[reverse($refs=~m/<(.*?)>/g)];
	$mail{$id}{'parent'}=undef;

	$mail{$id}{'time'}=$time;
	$time=strftime("%m/%d", localtime($time));
	$mail{$id}{'scan'}=[$msg, $status, $INFO{$info}, $time, $from, $subject];
}
close($SCAN);

=pod

All message metadata is read into memory, then organized by thread, then
finally displayed to the screen.  Therefore, when using B<stan> you may
notice a lag on large message scans which is not normally seen when just
using L<scan(1)>.

=cut

foreach my $mid (keys(%mail)) {
	foreach my $ancestor ($mail{$mid}{'reply-to'}, @{$mail{$mid}{'refs'}}) {
		if($ancestor && $mail{$ancestor}) {
			$mail{$mid}{'parent'}=$ancestor;
			push(@{$mail{$ancestor}{'replies'}}, $mid);

			while($ancestor) {
				$mail{$ancestor}{'time'}=
					max($mail{$ancestor}{'time'}, $mail{$mid}{'time'});
				$ancestor=$mail{$ancestor}{'parent'};
			}
			last;
		}
	}
}

=pod

When multiple messages are in reply to the same parent, they will be
displayed in the order in which they were received.

=cut

foreach my $mid (keys(%mail)) {
	$mail{$mid}{'time'}+=$mail{$msg}{'scan'}[0]/10000 if($mail{$msg}{'scan'});
}

foreach my $mid (sort bytime keys(%mail)) {
	&print_msg($mid, 0) unless($mail{$mid}{'parent'});
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

