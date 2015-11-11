#!/usr/bin/perl -w

use Getopt::Long;

$#ARGV>=2 or die "usage: time_series_symbol_project.pl symbol steps-ahead model \n";

$symbol=shift;
$steps=shift;
$model=join(" ",@ARGV);

system "/home/pps860/www/pf/get_data.pl --from=\"12/01/2005\" --close $symbol > /home/pps860/www/pf/_data.in";
system "/home/pps860/www/pf/time_series_project /home/pps860/www/pf/_data.in $steps $model 2>/dev/null";

