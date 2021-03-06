#!/usr/bin/perl -w

#
#
# rwb-mobile.pl (Red, White, and Blue)
#
#
# Example code for EECS 339, Northwestern University
# 
# Peter Dinda
#

# The overall theory of operation of this script is as follows
#
# 1. The inputs are form parameters, if any, and a session cookie, if any. 
# 2. The session cookie contains the login credentials (User/Password).
# 3. The parameters depend on the form, but all forms have the following three
#    special parameters:
#
#         act      =  form  <the form in question> (form=base if it doesn't exist)
#         run      =  0 Or 1 <whether to run the form or not> (=0 if it doesn't exist)
#         debug    =  0 Or 1 <whether to provide debugging output or not> 
#
# 4. The script then generates relevant html based on act, run, and other 
#    parameters that are form-dependent
# 5. The script also sends back a new session cookie (allowing for logout functionality)
# 6. The script also sends back a debug cookie (allowing debug behavior to propagate
#    to child fetches)
#


#
# Debugging
#
# database input and output is paired into the two arrays noted
#
my $debug=0; # default - will be overriden by a form parameter or cookie
my @sqlinput=();
my @sqloutput=();

#
# The combination of -w and use strict enforces various 
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);


# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.  
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;



#
# You need to override these for access to your database
#
my $dbuser="pps860";
my $dbpasswd="zaM7in9Wf";


#
# The session cookie will contain the user's name and password so that 
# he doesn't have to type it again and again. 
#
# "RWBSession"=>"user/password"
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename="RWBSession";
#
# And another cookie to preserve the debug state
#
my $debugcookiename="RWBDebug";

#
# Get the session input and debug cookies, if any
#
my $inputcookiecontent = cookie($cookiename);
my $inputdebugcookiecontent = cookie($debugcookiename);

#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $outputdebugcookiecontent = undef;
my $deletecookie=0;
my $user = undef;
my $password = undef;
my $logincomplain=0;

#
# Get the user action and whether he just wants the form or wants us to
# run the form
#
my $action;
my $run;


if (defined(param("act"))) { 
  $action=param("act");
  if (defined(param("run"))) { 
    $run = param("run") == 1;
  } else {
    $run = 0;
  }
} else {
  $action="base";
  $run = 1;
}

my $dstr;

if (defined(param("debug"))) { 
  # parameter has priority over cookie
  if (param("debug") == 0) { 
    $debug = 0;
  } else {
    $debug = 1;
  }
} else {
  if (defined($inputdebugcookiecontent)) { 
    $debug = $inputdebugcookiecontent;
  } else {
    # debug default from script
  }
}

$outputdebugcookiecontent=$debug;

#
#
# Who is this?  Use the cookie or anonymous credentials
#
#
if (defined($inputcookiecontent)) { 
  # Has cookie, let's decode it
  ($user,$password) = split(/\//,$inputcookiecontent);
  $outputcookiecontent = $inputcookiecontent;
} else {
  # No cookie, treat as anonymous user
  ($user,$password) = ("anon","anonanon");
}

#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login") { 
  if ($run) { 
    #
    # Login attempt
    #
    # Ignore any input cookie.  Just validate user and
    # generate the right output cookie, if any.
    #
    ($user,$password) = (param('user'),param('password'));
    if (ValidUser($user,$password)) { 
      # if the user's info is OK, then give him a cookie
      # that contains his username and password 
      # the cookie will expire in one hour, forcing him to log in again
      # after one hour of inactivity.
      # Also, land him in the base query screen
      $outputcookiecontent=join("/",$user,$password);
      $action = "base";
      $run = 1;
    } else {
      # uh oh.  Bogus login attempt.  Make him try again.
      # don't give him a cookie
      $logincomplain=1;
      $action="login";
      $run = 0;
    }
  } else {
    #
    # Just a login screen request, but we should toss out any cookie
    # we were given
    #
    undef $inputcookiecontent;
    ($user,$password)=("anon","anonanon");
  }
} 


#
# If we are being asked to log out, then if 
# we have a cookie, we should delete it.
#
if ($action eq "logout") {
  $deletecookie=1;
  $action = "base";
  $user = "anon";
  $password = "anonanon";
  $run = 1;
}


my @outputcookies;

#
# OK, so now we have user/password
# and we *may* have an output cookie.   If we have a cookie, we'll send it right 
# back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if (defined($outputcookiecontent)) { 
  my $cookie=cookie(-name=>$cookiename,
		    -value=>$outputcookiecontent,
		    -expires=>($deletecookie ? '-1h' : '+1h'));
  push @outputcookies, $cookie;
} 
#
# We also send back a debug cookie
#
#
if (defined($outputdebugcookiecontent)) { 
  my $cookie=cookie(-name=>$debugcookiename,
		    -value=>$outputdebugcookiecontent);
  push @outputcookies, $cookie;
}

#
# Headers and cookies sent back to client
#
# The page immediately expires so that it will be refetched if the
# client ever needs to update it
#
print header(-expires=>'now', -cookie=>\@outputcookies);

#
# Now we finally begin generating back HTML
#
#
#print start_html('Red, White, and Blue');
print "<!DOCTYPE html>";
print "<html style=\"height: 100\%\">";
print "<head>";
print "<link rel=\"manifest\" href=\"manifest.json\">";
print "<title>Red, White, and Blue</title>";
print "</head>";

print "<body style=\"height:100\%;margin:0\">";

#
# Force device width, for mobile phones, etc
#
print "<meta name=\"viewport\" content=\"width=device-width\" />\n";

# This tells the web browser to render the page in the style
# defined in the css file
#
print "<style type=\"text/css\">\n\@import \"rwb-mobile.css\";\n</style>\n";

#
#
# The remainder here is essentially a giant switch statement based
# on $action. 
#
#
#


# LOGIN
#
# Login is a special case since we handled running the filled out form up above
# in the cookie-handling code.  So, here we only show the form if needed
# 
#
if ($action eq "login") { 
  if ($logincomplain) { 
    print "Login failed.  Try again.<p>"
  } 
  if ($logincomplain or !$run) { 
    print start_form(-name=>'Login'),
      h2('Login to Red, White, and Blue'),
	"Name:",textfield(-name=>'user'),	p,
	  "Password:",password_field(-name=>'password'),p,
	    hidden(-name=>'act',default=>['login']),
	      hidden(-name=>'run',default=>['1']),
		submit,
		  end_form;
  }
}



#
# BASE
#
# The base action presents the overall page to the browser
# This is the "document" that the JavaScript manipulates
#
#
if ($action eq "base") { 


  print "<script src=\"http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js\" type=\"text/javascript\"></script>";
  #
  # The Javascript portion of our app
  #
  print "<script type=\"text/javascript\" src=\"rwb-mobile.js\"></script>";
  #
  # Google maps API, needed to draw the map
  #
  print "<script async defer src=\"http://maps.googleapis.com/maps/api/js?key=AIzaSyA7s3rLmlAgAC5WwqQw6Co1njG95fiDTHo&callback=initMap\"></script>";

  #
  #
  # And something to color (Red, White, or Blue)
  #
  print "<div id=\"color\" style=\"width:100\%; height:10\%\"></div>";

  #
  #
  # And a map which will be populated later
  #
  print "<div id=\"map\" style=\"width:100\%; height:80\%\"></div>";
  
  # 
  # creates checkboxes for opinions and individuals
  print "<div id=\"query-data\">";
  print "<p><strong>Choose data to query</strong></p>";
  print "<input type=\"checkbox\" name=\"committees\"> <label>View committee data?</label> <br>"; 
  print "<input type=\"checkbox\" name=\"candidates\"> <label>View candidate data?</label> <br>";  
  print "<input type=\"checkbox\" name=\"individuals\"> <label>View individual data?</label> <br>";
  print "<input type=\"checkbox\" name=\"opinions\"> <label>View opinion data?</label> <br>";
  print "</div><hr>";

  #make cycle checkboxes
  print "<div id=\"choose-cycles\"><p><strong>Choose election cycles:</strong></p>";
  my @cycles;
  @cycles = ExecSQL($dbuser, $dbpasswd, "select distinct cycle from cs339.committee_master order by cycle desc", "COL");
  foreach my $cyc (@cycles) {
	  print "<input type=\"checkbox\" name=\"cycle\" value=\"$cyc\"> <label>$cyc</label> <br>";
  }
  print "</div><hr>";


  #creates form for submitting opinion data
  #only creates this form if user is not anonymous
  if ($user ne "anon") { 
    print "<div id=\"opinion-data\">";
    print "<p><strong>Give opinion data</strong></p>";
    print start_form(-name=>'GiveOpinionData'),
    p('What do you think the political "color" is at your current location?'),
    p('Select -1 for red, 0 for neutral, and +1 for blue.'),
    "<input type=\"radio\" name=\"opinion\" value=\"-1\"><label>-1</label><br>",
    "<input type=\"radio\" name=\"opinion\" value=\"0\"><label>0</label><br>",
    "<input type=\"radio\" name=\"opinion\" value=\"1\"><label>+1</label><br>",
    hidden(-name=>'run',-default=>['1']),
    hidden(-name=>'act',-default=>['give-opinion-data']),
    hidden(-name=>'lat'),
    hidden(-name=>'long'),
    submit,
    end_form;
    print "</div><hr>";
  } 

  # button to calculate aggregate data - not in near because too slow
  print "<div id=\"calculate-summary\">";
  print "<p><strong>Calculate a summary of the data and cycles you selected above</strong></p>";
  print "<button id=\"aggregate\">Calculate summary</button>";
  print "</div><hr>";

  # summary div where summary goes
  print "<div id=\"summary\" style=\:width:100\%;></div>";  

  # 

# height=1024 width=1024 id=\"info\" name=\"info\" onload=\"UpdateMap()\"></iframe>";

  #
  # User mods
  #
  #
  print "<div id=\"user-mods\">";
  if ($user eq "anon") {
    print "<p><strong>You are anonymous, but you can also <a href=\"rwb-mobile.pl?act=login\">login</a></strong></p>";
  } else {
    print "<p><strong>You are logged in as $user and can do the following:</strong></p>";
    if (UserCan($user,"give-opinion-data")) {
      print "<p><a href=\"rwb-mobile.pl?act=give-opinion-data\">Give Opinion Of Current Location</a></p>";
    }
    if (UserCan($user,"give-cs-ind-data")) {
      print "<p><a href=\"rwb-mobile.pl?act=give-cs-ind-data\">Geolocate Individual Contributors</a></p>";
    }
    if (UserCan($user,"manage-users") || UserCan($user,"invite-users")) {
      print "<p><a href=\"rwb-mobile.pl?act=invite-user\">Invite User</a></p>";
    }
    if (UserCan($user,"manage-users") || UserCan($user,"add-users")) { 
      print "<p><a href=\"rwb-mobile.pl?act=add-user\">Add User</a></p>";
    } 
    if (UserCan($user,"manage-users")) { 
      print "<p><a href=\"rwb-mobile.pl?act=delete-user\">Delete User</a></p>";
      print "<p><a href=\"rwb-mobile.pl?act=add-perm-user\">Add User Permission</a></p>";
      print "<p><a href=\"rwb-mobile.pl?act=revoke-perm-user\">Revoke User Permission</a></p>";
    }
    print "<p><a href=\"rwb-mobile.pl?act=logout&run=1\">Logout</a></p>";
  }
  print "</div>";

  #
  # And a div to populate with info about nearby stuff
  #
  #
  if ($debug) {
    # visible if we are debugging
    print "<div id=\"data\" style=\:width:100\%; height:10\%\"></div>";
  } else {
    # invisible otherwise
    print "<div id=\"data\" style=\"display: none;\"></div>";
  }

}

#
#
# NEAR
#
#
# Nearby committees, candidates, individuals, and opinions
#
#
# Note that the individual data should integrate the FEC data and the more
# precise crowd-sourced location data.   The opinion data is completely crowd-sourced
#
# This form intentionally avoids decoration since the expectation is that
# the client-side javascript will invoke it to get raw data for overlaying on the map
#
#
if ($action eq "near") {
  	my $latne = param("latne");
  	my $longne = param("longne");
  	my $latsw = param("latsw");
  	my $longsw = param("longsw");
  	my $whatparam = param("what");
  	my $format = param("format");
 	  my $cycle = param("cycle");
  	my %what;

  	$format = "table" if !defined($format);
   	if (!defined($cycle) or ($cycle=="")){
		  $cycle = "1112";
	  }

  if (!defined($whatparam) || $whatparam eq "all") { 
    %what = ( committees => 1, 
	      candidates => 1,
	      individuals =>1,
	      opinions => 1);
  } else {
    map {$what{$_}=1} split(/\s*,\s*/,$whatparam);
  }
	       

  if ($what{committees}) { 
    my ($str,$error) = Committees($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby committees</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{candidates}) {
    my ($str,$error) = Candidates($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby candidates</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{individuals}) {
    my ($str,$error) = Individuals($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby individuals</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{opinions}) {
    my ($str,$error) = Opinions($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby opinions</h2>$str";
      } else {
	print $str;
      }
    }
  }
}

# 
# 
# pretty much the same thing as near, except prints summary statistics
# also does different sql calls than near
# aggregate this isn't in near because it is too slow 
if ($action eq "aggregate") {
    my $whatparam = param("what");
    my $format = param("format");
    my $cycle = param("cycle");
    my %what;

    $format = "table" if !defined($format);
    if (!defined($cycle) or ($cycle=="")){
      $cycle = "1112";
    }

  if (!defined($whatparam) || $whatparam eq "all") { 
    %what = ( committees => 1, 
        candidates => 1,
        individuals =>1,
        opinions => 1);
  } else {
    map {$what{$_}=1} split(/\s*,\s*/,$whatparam);
  }
         
  if ($what{committees}) { 
    my $latne = param("latne");
    my $longne = param("longne");
    my $latsw = param("latsw");
    my $longsw = param("longsw");

    # increasingly larger area until enough data
    my @count = CountCommittees($latne,$longne,$latsw,$longsw,$cycle,$format);
    my $count = $count[0][0]; 
    my $centerlat = ($latne + $latsw)/2;
    my $latdist;
    my $centerlong = ($longne + $longsw)/2;
    my $longdist;
    while ($count < 30) {
      $latdist = ($latne - $latsw)/2;
      $longdist = ($longne - $longsw)/2;
      $latne = $centerlat + $latdist * 1.5;
      $latsw = $centerlat - $latdist * 1.5;
      $longne = $centerlong + $longdist * 1.5;
      $longsw = $centerlong - $longdist * 1.5;
      @count = CountCommittees($latne,$longne,$latsw,$longsw,$cycle,$format);
      $count = $count[0][0];

      # THIS LINE IS ONLY FOR DEBUGGING 
      # print "<h1> count: $count, height of box: $latdist, width of box: $longdist</h1>";
    }

    # gets summary data for large enough area
    my @rows = SummarizeCommittees($latne,$longne,$latsw,$longsw,$cycle,$format);

    # calculates summary statistics
    my $difference = $rows[0][1] - $rows[1][1];
    if ($difference < 0) {
      print "<div style=\"background-color: red;\">";
    }
    else {
      print "<div style=\"background-color: dodgerblue;\">";
    }
    print "<h2>Committee Summary</h2><h3>Total money given by committees:</h3>";
    print $rows[0][1] > 0 ? "<p> To Democrats: \$$rows[0][1]</p>" : "<p> To Democrats: $0</p>";
    print $rows[1][1] > 0 ? "<p> To Republicans: \$$rows[1][1]</p>" : "<p> To Republicans: $0</p>";
    if ($difference < 0) {
      $difference *= -1;
      print "<p><strong>Difference: \$$difference more given to Republicans</strong></p><hr></div>";
    }
    else {
      print "<p><strong>Difference: \$$difference more given to Democrats</strong></p><hr></div>";
    }
  }
  if ($what{individuals}) { 
    my $latne = param("latne");
    my $longne = param("longne");
    my $latsw = param("latsw");
    my $longsw = param("longsw");

    # increasingly larger area until enough data
    my @count = CountIndividuals($latne,$longne,$latsw,$longsw,$cycle,$format);
    my $count = $count[0][0]; 
    my $centerlat = ($latne + $latsw)/2;
    my $latdist;
    my $centerlong = ($longne + $longsw)/2;
    my $longdist;
    while ($count < 30) {
      $latdist = ($latne - $latsw)/2;
      $longdist = ($longne - $longsw)/2;
      $latne = $centerlat + $latdist * 1.5;
      $latsw = $centerlat - $latdist * 1.5;
      $longne = $centerlong + $longdist * 1.5;
      $longsw = $centerlong - $longdist * 1.5;
      @count = CountIndividuals($latne,$longne,$latsw,$longsw,$cycle,$format);
      $count = $count[0][0];

      # THIS LINE IS ONLY FOR DEBUGGING
      # print "<h1> count: $count, height of box: $latdist, width of box: $longdist</h1>";
    }

    # gets summary data for large enough area
    my @rows = SummarizeIndividuals($latne,$longne,$latsw,$longsw,$cycle,$format);

    # calculates summary statistics
    my $difference = $rows[0][1] - $rows[1][1];
    if ($difference < 0) {
      print "<div style=\"background-color: red;\">";
    }
    else {
      print "<div style=\"background-color: dodgerblue;\">";
    }
    print "<h2>Individual Summary</h2><h3>Total money given by individuals:</h3>";
    print $rows[0][1] > 0 ? "<p> To Democrats: \$$rows[0][1]</p>" : "<p> To Democrats: $0</p>";
    print $rows[1][1] > 0 ? "<p> To Republicans: \$$rows[1][1]</p>" : "<p> To Republicans: $0</p>";
    if ($difference < 0) {
      $difference *= -1;
      print "<p><strong>Difference: \$$difference more given to Republicans</strong></p><hr></div>";
    }
    else {
      print "<p><strong>Difference: \$$difference more given to Democrats</strong></p><hr></div>";
    }
  }
  if ($what{opinions}) { 
    my $latne = param("latne");
    my $longne = param("longne");
    my $latsw = param("latsw");
    my $longsw = param("longsw");

    # increasingly larger area until enough data
    my @count = CountOpinions($latne,$longne,$latsw,$longsw,$format);
    my $count = $count[0][0]; 
    my $centerlat = ($latne + $latsw)/2;
    my $latdist;
    my $centerlong = ($longne + $longsw)/2;
    my $longdist;
    my $num_expansions=0;
    while ($count < 30 && $num_expansions < 10) {
      $latdist = ($latne - $latsw)/2;
      $longdist = ($longne - $longsw)/2;
      $latne = $centerlat + $latdist * 1.5;
      $latsw = $centerlat - $latdist * 1.5;
      $longne = $centerlong + $longdist * 1.5;
      $longsw = $centerlong - $longdist * 1.5;
      @count = CountOpinions($latne,$longne,$latsw,$longsw,$cycle,$format);
      $count = $count[0][0];
      $num_expansions += 1;

      # THIS LINE IS ONLY FOR DEBUGGING 
      # print "<h1> count: $count, height of box: $latdist, width of box: $longdist</h1>";
    }

    # gets summary data for large enough area
    my @rows = SummarizeOpinions($latne,$longne,$latsw,$longsw,$format);

    # calculates summary statistics
    my $average = $rows[0][0];
    my $stnddev = $rows[0][1];
    $stnddev = sprintf "%.2f", $stnddev;
    if ($average < 0) {
      print "<div style=\"background-color: red;\">";
    }
    elsif ($average > 0) {
      print "<div style=\"background-color: dodgerblue;\">";
    }
    else {
      print "<div style=\"background-color: #d8d8d8;\">";
    }
    print "<h2>Opinion Summary</h2><p>Number of opinions: $count</p>";
    print "<p>Average opinion data (+1 = blue, -1 = red): $average</p>";
    print "<p>Standard deviation of opinion data: $stnddev</p><hr></div>";
  }
}

#
# INVITE-USER
#
# User Invite functionaltiy 
#
#
#
#
if ($action eq "invite-user") { 
  if (!UserCan($user,"invite-users") && !UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to invite users.');
  } else {
    if (!$run) { 
      
      print start_form(-name=>'InviteUser'),
  h2('Invite User'),
    "Email: ", textfield(-name=>'email'),
      p,
        hidden(-name=>'run',-default=>['1']),
      hidden(-name=>'act',-default=>['invite-user']),
        submit,
          end_form,
            hr;
    } else {
      my $email=param('email');
      my $error;
      my $code=1000000 + int(rand(9999999 - 1000000));

      $error=AddInviteCode($code,$email,$user);
      
      if ($error) { 
  print "Can't invite user because: $error";
      } else {
  open(MAIL,"| mail -s 'Invitation to RWB!' $email") or die "Can't run mail\n";
  print MAIL "Click here for your one-time invitation to RWB: http://murphy.wot.eecs.northwestern.edu/~pps860/rwb/rwb-mobile.pl?act=accept-invite&code=$code\n";
  close(MAIL);
  print "Sent invitation to $email from $user\n";
      }
    }
  }
  print "<p><a href=\"rwb-mobile.pl?act=base&run=1\">Return</a></p>";
}

#
# ACCEPT-INVITE
#
# Accept Invite functionaltiy 
#
#
#
#
if ($action eq "accept-invite") { 
  my $code=param('code');
  my @info=ValidCode($code);
  if (@info) {
    my ($email,$referer)=@info;
    if (!$run) { 
      print start_form(-name=>'Create Account'),
  h2('Create Account'),
    "Name: ", textfield(-name=>'name'),
      p,
        "Email: ", textfield(-name=>'email',-default=>$email,-disabled=>'true'),
    p,
      "Password: ", textfield(-name=>'password'),
        p,
          hidden(-name=>'run',-default=>['1']),
      hidden(-name=>'act',-default=>['accept-invite']),
      hidden(-name=>'referer',-default=>$referer),
      hidden(-name=>'code',-default=>$code),
        submit,
          end_form,
            hr;
    } else {
        my $name=param('name');
        my $password=param('password');
        my $error;
        $error=UserAdd($name,$password,$email,$referer);
        if ($error) { 
    print "Can't create account because: $error";
        } else {
          GiveUserPerm($name,'invite-users');
          GiveUserPerm($name,'add-users');
          GiveUserPerm($name,'give-opinion-data');
          GiveUserPerm($name,'query-fec-data');
          GiveUserPerm($name,'query-cs-ind-data');
          GiveUserPerm($name,'query-opinion-data');
          my $errorOnDelete;
          $errorOnDelete=DelInviteCode($code);
          if ($errorOnDelete) {
            print "Could not delete invite code from table\n";
          }
      print "Successfully created account for $name\n";
        }
      }
  } else {
    print h2('Invalid URL')
  }
  print "<p><a href=\"rwb-mobile.pl?act=base&run=1\">Return</a></p>";
}

#
# GIVE-OPINION-DATA
#
# This action will only get called when opinion data is submitted. 
# The form to enter opinion data is part of the base action.
#
#
#
if ($action eq "give-opinion-data") { 
  if (!UserCan($user,"give-opinion-data")) { 
    print h2('You do not have the required permissions to give opinion data.');
  } else {
    my $opinion=param('opinion');
    my $lat=param('lat');
    my $long=param('long');
    my $error;

    $error=AddOpinion($user,$opinion,$lat,$long);
    if ($error) { 
      print "Can't add opinion because: $error";
    } else {
      print "Added opinion to opinion data.\n";
    }
  }
  print "<p><a href=\"rwb-mobile.pl?act=base&run=1\">Return</a></p>";
}


if ($action eq "give-cs-ind-data") { 
  print h2("Giving Crowd-sourced Individual Geolocations Is Unimplemented");
}

#
# ADD-USER
#
# User Add functionaltiy 
#
#
#
#
if ($action eq "add-user") { 
  if (!UserCan($user,"add-users") && !UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to add users.');
  } else {
    if (!$run) { 
      print start_form(-name=>'AddUser'),
	h2('Add User'),
	  "Name: ", textfield(-name=>'name'),
	    p,
	      "Email: ", textfield(-name=>'email'),
		p,
		  "Password: ", textfield(-name=>'password'),
		    p,
		      hidden(-name=>'run',-default=>['1']),
			hidden(-name=>'act',-default=>['add-user']),
			  submit,
			    end_form,
			      hr;
    } else {
      my $name=param('name');
      my $email=param('email');
      my $password=param('password');
      my $error;
      $error=UserAdd($name,$password,$email,$user);
      if ($error) { 
	print "Can't add user because: $error";
      } else {
	print "Added user $name $email as referred by $user\n";
      }
    }
  }
  print "<p><a href=\"rwb-mobile.pl?act=base&run=1\">Return</a></p>";
}

#
# DELETE-USER
#
# User Delete functionaltiy 
#
#
#
#
if ($action eq "delete-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to delete users.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'DeleteUser'),
	h2('Delete User'),
	  "Name: ", textfield(-name=>'name'),
	    p,
	      hidden(-name=>'run',-default=>['1']),
		hidden(-name=>'act',-default=>['delete-user']),
		  submit,
		    end_form,
		      hr;
    } else {
      my $name=param('name');
      my $error;
      $error=UserDel($name);
      if ($error) { 
	print "Can't delete user because: $error";
      } else {
	print "Deleted user $name\n";
      }
    }
  }
  print "<p><a href=\"rwb-mobile.pl?act=base&run=1\">Return</a></p>";
}


#
# ADD-PERM-USER
#
# User Add Permission functionaltiy 
#
#
#
#
if ($action eq "add-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'AddUserPerm'),
	h2('Add User Permission'),
	  "Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	      p,
		hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['add-perm-user']),
		  submit,
		    end_form,
		      hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
	print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=GiveUserPerm($name,$perm);
      if ($error) { 
	print "Can't add permission to user because: $error";
      } else {
	print "Gave user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb-mobile.pl?act=base&run=1\">Return</a></p>";
}


#
# REVOKE-PERM-USER
#
# User Permission Revocation functionaltiy 
#
#
#
#
if ($action eq "revoke-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'RevokeUserPerm'),
	h2('Revoke User Permission'),
	  "Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	      p,
		hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['revoke-perm-user']),
		  submit,
		    end_form,
		      hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
	print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=RevokeUserPerm($name,$perm);
      if ($error) { 
	print "Can't revoke permission from user because: $error";
      } else {
	print "Revoked user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb-mobile.pl?act=base&run=1\">Return</a></p>";
}



#
#
#
#
# Debugging output is the last thing we show, if it is set
#
#
#
#

print "</center>" if !$debug;

#
# Generate debugging output if anything is enabled.
#
#
if ($debug) {
  print hr, p, hr,p, h2('Debugging Output');
  print h3('Parameters');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(param($_)) } param();
  print "</menu>";
  print h3('Cookies');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(cookie($_))} cookie();
  print "</menu>";
  my $max= $#sqlinput>$#sqloutput ? $#sqlinput : $#sqloutput;
  print h3('SQL');
  print "<menu>";
  for (my $i=0;$i<=$max;$i++) { 
    print "<li><b>Input:</b> ".escapeHTML($sqlinput[$i]);
    print "<li><b>Output:</b> $sqloutput[$i]";
  }
  print "</menu>";
}

print end_html;

#
# The main line is finished at this point. 
# The remainder includes utilty and other functions
#


#
# Generate a table of nearby committees
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Committees {
	my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
	my @rows;
	my @cycles;
	@cycles = split(/\s*,\s*/,$cycle);
  my $size = @cycles;
  my $in = '?' . (',?' x ($size - 1));
	
  	eval { 
    	@rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, cmte_nm, cmte_pty_affiliation, cmte_st1, cmte_st2, cmte_city, cmte_st, cmte_zip from cs339.committee_master natural join cs339.cmte_id_to_geo where latitude>? and latitude<? and longitude>? and longitude<? and cycle in ($in)",undef,$latsw,$latne,$longsw,$longne,@cycles);
	};
  
  	if ($@) { 
    		return (undef,$@);
  	} else {
    		if ($format eq "table") { 
      			return (MakeTable("committee_data","2D",
					  ["latitude", "longitude", "name", "party", "street1", "street2", 
					  "city", "state", "zip"],
				@rows),$@);
    		} else {
      			return (MakeRaw("committee_data","2D",@rows),$@);
    		}
  	}
}


#
# Generate a table of nearby candidates
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Candidates {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  my @cycles;
  @cycles = split(/\s*,\s*/,$cycle);
  my $size = @cycles;
  my $in = '?' . (',?' x ($size - 1));

  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, cand_name, cand_pty_affiliation, cand_st1, cand_st2, cand_city, cand_st, cand_zip from cs339.candidate_master natural join cs339.cand_id_to_geo where latitude>? and latitude<? and longitude>? and longitude<? and cycle in ($in)",undef,$latsw,$latne,$longsw,$longne,@cycles);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") {
      return (MakeTable("candidate_data", "2D",
			["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
			@rows),$@);
    } else {
      return (MakeRaw("candidate_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby individuals
#
# Note that the handout version does not integrate the crowd-sourced data
#
# ($table|$raw,$error) = Individuals(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Individuals {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  my @cycles;
  @cycles = split(/\s*,\s*/,$cycle);
  my $size = @cycles;
  my $in = '?' . (',?' x ($size - 1));

  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, name, city, state, zip_code, employer, transaction_amnt from cs339.individual natural join cs339.ind_to_geo where latitude>? and latitude<? and longitude>? and longitude<? and cycle in ($in)",undef,$latsw,$latne,$longsw,$longne,@cycles);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("individual_data", "2D",
			["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
			@rows),$@);
    } else {
      return (MakeRaw("individual_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby opinions
#
# ($table|$raw,$error) = Opinions(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Opinions {
  my ($latne, $longne, $latsw, $longsw, $cycle,$format) = @_;
  my @rows;

  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, color from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("opinion_data","2D",
			["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
			@rows),$@);
    } else {
      return (MakeRaw("opinion_data","2D",@rows),$@);
    }
  }
}

#
# Count if we have enough committee data for aggregate
#
sub CountCommittees {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @count;
  my @cycles;
  @cycles = split(/\s*,\s*/,$cycle);
  my $size = @cycles;
  my $in = '?' . (',?' x ($size - 1));
  
    eval { 
      @count = ExecSQL($dbuser, $dbpasswd, "SELECT COUNT(cmte_id) AS data_points FROM cs339.cmte_id_to_geo NATURAL JOIN cs339.committee_master WHERE latitude>? AND latitude<? AND longitude>? AND longitude<? AND cycle IN ($in)",undef,$latsw,$latne,$longsw,$longne,@cycles);
  };
  
    if ($@) { 
        return (undef,$@);
    } else {
        return @count;
    }
}

#
# Get aggregate committee data
#
sub SummarizeCommittees {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  my @cycles;
  @cycles = split(/\s*,\s*/,$cycle);
  my $size = @cycles;
  my $in = '?' . (',?' x ($size - 1));
  
    eval { 
      @rows = ExecSQL($dbuser, $dbpasswd,  "SELECT cand.cand_pty_affiliation AS party, SUM(coca.transaction_amnt + cc.transaction_amnt) AS contributions FROM (SELECT cmte_id FROM cs339.cmte_id_to_geo WHERE latitude>? AND latitude<? AND longitude>? AND longitude<?) cir INNER JOIN cs339.comm_to_comm cc ON (cir.cmte_id=cc.cmte_id) INNER JOIN cs339.comm_to_cand coca ON (cc.cmte_id=coca.cmte_id AND cc.cycle=coca.cycle) INNER JOIN cs339.candidate_master cand ON (coca.cand_id= cand.cand_id AND coca.cycle= cand.cycle) WHERE cand.cand_pty_affiliation IN ('REP','DEM') AND cand.cycle IN ($in) GROUP BY cand.cand_pty_affiliation ORDER BY cand.cand_pty_affiliation",undef,$latsw,$latne,$longsw,$longne,@cycles);
        };
  
    if ($@) { 
        return (undef,$@);
    } else {
        return @rows;
    }
}

#
# Count if we have enough Individual data for aggregate
#
sub CountIndividuals {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @count;
  my @cycles;
  @cycles = split(/\s*,\s*/,$cycle);
  my $size = @cycles;
  my $in = '?' . (',?' x ($size - 1));

    eval { 
      @count = ExecSQL($dbuser, $dbpasswd, "SELECT count(sub_id) FROM (SELECT sub_id FROM cs339.ind_to_geo WHERE latitude>? AND latitude<? AND longitude>? AND longitude<?) NATURAL JOIN cs339.individual WHERE cycle IN ($in)",undef,$latsw,$latne,$longsw,$longne,@cycles);
    };

    
  
    if ($@) { 
        return (undef,$@);
    } else {
        return @count;
    }
}

#
# Get aggregate Individual data
#
sub SummarizeIndividuals {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  my @cycles;
  @cycles = split(/\s*,\s*/,$cycle);
  my $size = @cycles;
  my $in = '?' . (',?' x ($size - 1));
  
    eval { 
      @rows = ExecSQL($dbuser, $dbpasswd,  "SELECT cmte.cmte_pty_affiliation AS Party, SUM(ind.transaction_amnt) AS Contributions FROM (SELECT sub_id FROM cs339.ind_to_geo WHERE latitude>? AND latitude<? AND longitude>? AND longitude<?) iir INNER  JOIN cs339.individual ind ON iir.sub_id=ind.sub_id INNER JOIN cs339.committee_master cmte ON ind.cmte_id=cmte.cmte_id WHERE cmte.cmte_pty_affiliation IN ('DEM','REP') AND ind.cycle IN ($in) GROUP BY cmte.cmte_pty_affiliation ORDER BY cmte.cmte_pty_affiliation",undef,$latsw,$latne,$longsw,$longne,@cycles);
        };
  
    if ($@) { 
        return (undef,$@);
    } else {
        return @rows;
    }
}

#
# Count if we have enough Opinion data for aggregate
#
sub CountOpinions {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @count;

    eval { 
      @count = ExecSQL($dbuser, $dbpasswd, "SELECT count(color) FROM rwb_opinions op WHERE latitude>? AND latitude<? AND longitude>? AND longitude<?",undef,$latsw,$latne,$longsw,$longne);
    };
  
    if ($@) { 
        return (undef,$@);
    } else {
        return @count;
    }
}

#
# Get aggregate Opinion data
#
sub SummarizeOpinions {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  
    eval { 
      @rows = ExecSQL($dbuser, $dbpasswd,  "SELECT AVG(color) AS avg, STDDEV(color) AS stdev FROM rwb_opinions op WHERE latitude>? AND latitude<? AND longitude>? AND longitude<?",undef,$latsw,$latne,$longsw,$longne);
        };
  
    if ($@) { 
        return (undef,$@);
    } else {
        return @rows;
    }
}


#
# Generate a table of available permissions
# ($table,$error) = PermTable()
# $error false on success, error string on failure
#
sub PermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select action from rwb_actions"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("perm_table",
		      "2D",
		     ["Perm"],
		     @rows),$@);
  }
}

#
# Generate a table of users
# ($table,$error) = UserTable()
# $error false on success, error string on failure
#
sub UserTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select name, email from rwb_users order by name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("user_table",
		      "2D",
		     ["Name", "Email"],
		     @rows),$@);
  }
}

#
# Generate a table of users and their permissions
# ($table,$error) = UserPermTable()
# $error false on success, error string on failure
#
sub UserPermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select rwb_users.name, rwb_permissions.action from rwb_users, rwb_permissions where rwb_users.name=rwb_permissions.name order by rwb_users.name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("userperm_table",
		      "2D",
		     ["Name", "Permission"],
		     @rows),$@);
  }
}

#
# Add a user
# call with name,password,email
#
# returns false on success, error string on failure.
# 
# UserAdd($name,$password,$email)
#
sub UserAdd { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into rwb_users (name,password,email,referer) values (?,?,?,?)",undef,@_);};
  return $@;
}

#
# Add an invite code
#
# returns false on success, error string on failure.
#
sub AddInviteCode { 
  eval { ExecSQL($dbuser,$dbpasswd,
     "insert into rwb_invite_codes (code,email,referer) values (?,?,?)",undef,@_);};
  return $@;
}

#
# Delete a user
# returns false on success, $error string on failure
# 
sub UserDel { 
  eval {ExecSQL($dbuser,$dbpasswd,"delete from rwb_users where name=?", undef, @_);};
  return $@;
}

#
# Delete an invite code
# returns false on success, $error string on failure
# 
sub DelInviteCode { 
  eval {ExecSQL($dbuser,$dbpasswd,"delete from rwb_invite_codes where code=?", undef, @_);};
  return $@;
}

#
# Add an opinion
# call with user,opinion,lat,long
#
# returns false on success, error string on failure.
#
sub AddOpinion { 
  eval { ExecSQL($dbuser,$dbpasswd,
     "insert into rwb_opinions (submitter,color,latitude,longitude) values (?,?,?,?)",undef,@_);};
  return $@;
}

#
# Give a user a permission
#
# returns false on success, error string on failure.
# 
# GiveUserPerm($name,$perm)
#
sub GiveUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into rwb_permissions (name,action) values (?,?)",undef,@_);};
  return $@;
}

#
# Revoke a user's permission
#
# returns false on success, error string on failure.
# 
# RevokeUserPerm($name,$perm)
#
sub RevokeUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "delete from rwb_permissions where name=? and action=?",undef,@_);};
  return $@;
}

#
#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
  my ($user,$password)=@_;
  my @col;
  eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_users where name=? and password=?","COL",$user,$password);};
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}

#
# Check to see if invite code exists
# If it does, returns associated email and referer
#
# $ok = ValidCode($code)
#
#
sub ValidCode {
  my ($code)=@_;
  my @info;
  eval {@info=ExecSQL($dbuser,$dbpasswd, "select email,referer from rwb_invite_codes where code=?","ROW",$code);};
  if ($@) { 
    return 0;
  } else {
    return @info;
  }
}


#
#
# Check to see if user can do some action
#
# $ok = UserCan($user,$action)
#
sub UserCan {
  my ($user,$action)=@_;
  my @col;
  eval {@col= ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_permissions where name=? and action=?","COL",$user,$action);};
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}





#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($id, $type, $headerlistref,@list);
#
sub MakeTable {
  my ($id,$type,$headerlistref,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  if ((defined $headerlistref) || ($#list>=0)) {
    # if there is, begin a table
    #
    $out="<table id=\"$id\" border>";
    #
    # if there is a header list, then output it in bold
    #
    if (defined $headerlistref) { 
      $out.="<tr>".join("",(map {"<td><b>$_</b></td>"} @{$headerlistref}))."</tr>";
    }
    #
    # If it's a single row, just output it in an obvious way
    #c
    if ($type eq "ROW") { 
      #
      # map {code} @list means "apply this code to every member of the list
      # and return the modified list.  $_ is the current list member
      #
      $out.="<tr>".(map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>" } @list)."</tr>";
    } elsif ($type eq "COL") { 
      #
      # ditto for a single column
      #
      $out.=join("",map {defined($_) ? "<tr><td>$_</td></tr>" : "<tr><td>(null)</td></tr>"} @list);
    } else { 
      #
      # For a 2D table, it's a bit more complicated...
      #
      $out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
    }
    $out.="</table>";
  } else {
    # if no header row or list, then just say none.
    $out.="(none)";
  }
  return $out;
}


#
# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
#
sub MakeRaw {
  my ($id, $type,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  $out="<pre id=\"$id\">\n";
  #
  # If it's a single row, just output it in an obvious way
  #
  if ($type eq "ROW") { 
    #
    # map {code} @list means "apply this code to every member of the list
    # and return the modified list.  $_ is the current list member
    #
    $out.=join("\t",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } elsif ($type eq "COL") { 
    #
    # ditto for a single column
    #
    $out.=join("\n",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } else {
    #
    # For a 2D table
    #
    foreach my $r (@list) { 
      $out.= join("\t", map { defined($_) ? $_ : "(null)" } @{$r});
      $out.="\n";
    }
  }
  $out.="</pre>\n";
  return $out;
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
  my ($user, $passwd, $querystring, $type, @fill) =@_;
  if ($debug) { 
    # if we are recording inputs, just push the query string and fill list onto the 
    # global sqlinput list
    push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
  }
  my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
  if (not $dbh) { 
    # if the connect failed, record the reason to the sqloutput list (if set)
    # and then die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
    }
    die "Can't connect to database because of ".$DBI::errstr;
  }
  my $sth = $dbh->prepare($querystring);
  if (not $sth) { 
    #
    # If prepare failed, then record reason to sqloutput and then die
    #
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  if (not $sth->execute(@fill)) { 
    #
    # if exec failed, record to sqlout and die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  #
  # The rest assumes that the data will be forthcoming.
  #
  #
  my @data;
  if (defined $type and $type eq "ROW") { 
    @data=$sth->fetchrow_array();
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","ROW",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  my @ret;
  while (@data=$sth->fetchrow_array()) {
    push @ret, [@data];
  }
  if (defined $type and $type eq "COL") { 
    @data = map {$_->[0]} @ret;
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","COL",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  $sth->finish();
  if ($debug) {push @sqloutput, MakeTable("debug_sql_output","2D",undef,@ret);}
  $dbh->disconnect();
  return @ret;
}


######################################################################
#
# Nothing important after this
#
######################################################################

# The following is necessary so that DBD::Oracle can
# find its butt
#
BEGIN {
  unless ($ENV{BEGIN_BLOCK}) {
    use Cwd;
    $ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
    $ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
    $ENV{ORACLE_SID}="CS339";
    $ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
    $ENV{BEGIN_BLOCK} = 1;
    exec 'env',cwd().'/'.$0,@ARGV;
  }
}

