#!/usr/bin/perl -w
use strict;
my $debug=0;
use DBI;
my $dbuser="pps860";
my $dbpasswd="zaM7in9Wf";
my @sqlinput=();
my @sqloutput=();

#use Time::ParseDate;
use CGI qw(:standard);



print "Content-type:text/html\r\n\r\n";
#print "<!DOCTYPE html>";
print "<html>";
print "<head>";
print "<title>PJH Portfolio Manager</title>";

print "<link rel=\"stylesheet\" href=\"portfolio.css\">";

print "<script src=\"https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js\"></script>";
print "<script type=\"text/javascript\" src=\"portfolio.js\"></script>";
print "</head>";
print "<body>";


	print h2("Welcome to home!");
	
	my @portfolios;
#	@portfolios = ExecSQL($dbuser, $dbpasswd, "QUERY", "COL");
   
   @portfolios = ("personal", "Holliday", "Pooja", "jack");
   foreach my $pf (@portfolios) {
		print "<a href=\"portfolio.pl?act=portfolio\" name=\"$pf\">$pf</button><br>";
   }
   print "<button name=\"newpf\">Add Portfolio</button>";	
