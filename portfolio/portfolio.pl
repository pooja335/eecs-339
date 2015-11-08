#!/usr/bin/perl -w
use strict;

use DBI;
my $dbuser="pps860";
my $dbpasswd="zaM7in9Wf";

#use Time::ParseDate;
use CGI qw(:standard);




# receive cookies from client
my $sessioncookie = "pfsession";
my $inputsessioncookie = cookie($sessioncookie);


my $outputsessioncookie = undef;
my $deletecookie=0;
my $useremail = undef;
my $password = undef;
my $badlogin=0;

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
	# hmmm... we don't have an anon user, might need to handle default differently than RWB
	$action="login";
  	$run = 0;
}

# handle session cookie
if (defined($inputsessioncookie)) {
	($useremail,$password) = split(/\//,$inputsessioncookie);
  	$outputsessioncookie = $inputsessioncookie;
} else {
	$action = "login";
	undef $outputsessioncookie;
}

if ($action eq "login") {
	if ($run) {#if login attempt
		($useremail, $password) = (param('useremail'), param('password'));
#		if ( ValidUser($useremail, $password )) {
			$outputsessioncookie = join("/",$useremail,$password);
			$action = "home";
			$run = 1;
#  		} else { #try again with empty form
# 			$badlogin = 1;
# 			$action = "login";
# 			$run = 0;
# 		}
	} else { #just show the form
		undef $inputsessioncookie;
		undef $useremail;
		undef $password;
	}
}


#send cookies to client
my @outputcookies;

my $badcookie = cookie(-name => "badcookie",
						-value => "badcookie",
						-expires=>($deletecookie ? '-1h' : '+1h'));
	push @outputcookies, $badcookie;

if (defined($outputsessioncookie)) {
	my $cookie = cookie(-name => $sessioncookie,
						-value => $outputsessioncookie,
						-expires=>($deletecookie ? '-1h' : '+1h'));
	push @outputcookies, $cookie;
}

print header(-expires=>'now', -cookie=>\@outputcookies);

#start the page
#print "Content-type:text/html\r\n\r\n";
#print "<!DOCTYPE html>";
print "<html>";
print "<head>";
print "<title>PJH Portfolio Manager</title>";
print "</head>";
print "<body>";





if ($action eq "login") {
	#print "welcome to login!";
	print h2('Login to PJH Portfolio Manager');
  	if ($badlogin or !$run) { 
    	print start_form(-name=>'Login'),
				"Email:",textfield(-name=>'useremail'),	p,
	  			"Password:",password_field(-name=>'password'),p,
	    		hidden(-name=>'act',default=>['login']),
	      		hidden(-name=>'run',default=>['1']),
				submit,
		  		end_form;
  	}
  	if ($badlogin) { 
    	print "Login failed.  Try again.<p>"
  	} 
}

if ($action eq "home") {
	
	print "Welcome to home!";
}




print "</body>";
print "</html>";


########################################### HELPER FUNCTIONS ###########################################

sub ValidUser {
	my ($useremail,$password)=@_;
  	my @col;
  	
  	eval {@col=ExecSQL($dbuser, $dbpasswd, 
  						"select count(*) from users where email=? and password=?", "COL",
  						$useremail, $password);
  	};
  	
  	if ($@) { 
    	return 0;
  	} else {
    	return $col[0]>0;
  	}
}# Check to see if user and password combination exist ###NEEDS QUERY
