#!/usr/bin/perl -w

use CGI qw(:standard);
use DBI;
use Time::ParseDate;

$ENV{PORTF_DBMS}="oracle";
$ENV{PORTF_DB}="cs339";
$ENV{PORTF_DBUSER}="pps860";
$ENV{PORTF_DBPASS}="zaM7in9Wf";
$ENV{PATH} = $ENV{PATH}.":."; 



my $symbol = param('symbol');
my $future = param('future');

print header(-type => 'image/png', -expires => '-1h' );
if (!defined($symbol)) {
  $symbol = 'AAPL'; # default
}

`/home/pps860/www/pf/time_series_symbol_project.pl $symbol $future AWAIT 200 AR 16 > _futureplot.in`;

open(GNUPLOT,"| gnuplot") or die "Cannot run gnuplot";

print GNUPLOT "set term png\n";           # we want it to produce a PNG
print GNUPLOT "set output\n";             # output the PNG to stdout
print GNUPLOT "set title '$symbol'\nset xlabel 'time'\nset ylabel 'data'\n";
print GNUPLOT "plot '_futureplot.in' using 1:2 title 'Past', '_futureplot.in' using 1:3 title 'Future'\n";
#
# Here gnuplot will print the image content
#

close(GNUPLOT);