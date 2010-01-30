#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

use Tk;

plan tests => 1;

my $mw = tkinit;
{
    # http://rt.cpan.org/Public/Bug/Display.html?id=41436
    my $s = "\x90";
    my $b = $mw->Label->pack;
    $s =~ /(.)/;
    $b->configure(-text, $1);
    pass("RT #41436"); # otherwise it would abort()
}

__END__
