#!/usr/bin/perl -w


my $debug=0; # default - will be overriden by a form parameter or cookie
my @sqlinput=();
my @sqloutput=();

use strict;

use DBI;
my $dbuser="pps860";
my $dbpasswd="zaM7in9Wf";

#use Time::ParseDate;
use CGI qw(:standard);
use HTML::Template;
use Data::Dumper;



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
	$action = "portfolio";
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
print "<!DOCTYPE html>";
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

if ($action eq "portfolio") { 
	my $main_pf_template = HTML::Template->new(filename => 'main_pf.html');
	my $portfolio_name = 'portfolio 1';
	my $email = 'root@root.com';
	# for each symbol in portfolio 
	# 	marketval += close;
	$main_pf_template->param(PF_NAME => $portfolio_name);
	$main_pf_template->param(VALUE => '');
	$main_pf_template->param(VOLATILITY => '');
	$main_pf_template->param(CORRELATION => '');

	my @holding_info = ExecSQL($dbuser, $dbpasswd,
	  		     "select symbol, num_shares from holdings where portfolio_name=? and user_email=?","COL",
	  		     $portfolio_name, $email);

  my $table_data = "hi";
  print "HELLO" . Dumper($table_data, join(',',@holding_info));
	foreach my $holding (@holding_info) {
    # print "HELLO" + ref($holding) + @holding_info;
    # $table_data += "<tr><td>"+$holding[0]+"</td><td>"+$holding[0]+"</td>"+
    #     "<td><a href='portfolio.pl?act=edit_holding&holding_id=1></td>"+
    #     "<td><a href='portfolio.pl?act=view_stats&holding_id=1></td></tr>";
  }
  $main_pf_template->param(TABLE_DATA => $table_data);

	print $main_pf_template->output;
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

