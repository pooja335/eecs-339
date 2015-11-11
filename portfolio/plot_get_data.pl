#!/usr/bin/perl -w

use CGI qw(:standard);
use DBI;
use Time::ParseDate;

my $symbol = param('symbol');
my $start_date = param('start_date');
my $end_date = param('end_date');

print header(-type => 'image/png', -expires => '-1h' );
if (!defined($symbol)) {
  $symbol = 'AAPL'; # default
}

`./get_data.pl --close --from=\"$start_date\" --to=\"$end_date\" $symbol > _plot.in`;

open(GNUPLOT,"| gnuplot") or die "Cannot run gnuplot";

print GNUPLOT "set term png\n";           # we want it to produce a PNG
print GNUPLOT "set output\n";             # output the PNG to stdout
print GNUPLOT "set title '$symbol'\nset xlabel 'time'\nset ylabel 'data'\n";
print GNUPLOT "plot '_plot.in' using 1:2 with linespoints\n"; # feed it data to plot
#
# Here gnuplot will print the image content
#

close(GNUPLOT);
