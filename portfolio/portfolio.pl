#!/usr/bin/perl -w
use strict;

use DBI;
my $dbuser="pps860";
my $dbpasswd="zaM7in9Wf";

#use Time::ParseDate;
use CGI qw(:standard);




print "Content-type:text/html\r\n\r\n";
print "<!DOCTYPE html>";
print "<html lang=\"en\">";
print "<head>";
print "<title>Portfolio Manager</title>";
print "</head>";
print "<body>";

my $action;
my $run;

#set action and run
if (defined(param("act"))) {
	$action=param("act");
	
	if (defined(param("run"))){ 
		$run = param("run") == 1;
	} else {
    	$run = 0;
  	}
} else { # set default action
	$action="home";
  	$run = 1;
}

if ($action eq "login") {
	print "welcome to login!";
}

if ($action eq "home") {
	
	print "Welcome to home!";
	
}


print "</body>";
print "</html>";