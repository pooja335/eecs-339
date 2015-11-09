#!/usr/bin/perl -w
use strict;

use DBI;
my $dbuser="hls262";
my $dbpasswd="zdrih9KN8";
my @sqlinput=();
my @sqloutput=();
my $debug;

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
	$action = "login";
	undef $outputsessioncookie;
}

if ($action eq "login") {
	if ($run) {#if login attempt
		($useremail, $password) = (param('useremail'), param('password'));
		if ( ValidUser($useremail, $password )) {
			$outputsessioncookie = join("/",$useremail,$password);
			$action = "home";
			$run = 1;
 		} else { #try again with empty form
			$badlogin = 1;
			$action = "login";
			$run = 0;
		}
	} else { #just show the form
		undef $inputsessioncookie;
		undef $useremail;
		undef $password;
	}
}


if ($action eq "logout") {
  	$deletecookie=1;
  	$action = "login";
  	undef $useremail;
  	undef $password;
  	$run = 0;
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
print "<link rel='stylesheet' href='portfolio.css'>";





if ($action eq "login") {
	#print "welcome to login!";
	print h2('Login to PJH Portfolio Manager');
  	if ($badlogin or !$run) { 
    	print start_form(-name=>'Login'),
				"Email:",textfield(-name=>'useremail'),	p,
	  			"Password:",password_field(-name=>'password'),p,
	    		hidden(-name=>'act',default=>['login']),
	      		hidden(-name=>'run',default=>['1']),
				submit(name=>"Log In"),
		  		end_form;
  	}
  	if ($badlogin) { 
    	print "<p>Login failed.  Try again.</p><br>";
  	} 
   	print "<p>No account? <button id=\"register\">Register</button></p>";
}

if ($action eq "register") {
	if(!$run) {
		print h2('Register New Account');
		print start_form(-name=>'Register'),
					"Name:", textfield(-name=>'name'), p,
					"Email:", textfield(-name=>'useremail'), p,
	  				"Password:", password_field(-name=>'password'), p,
	    			hidden(-name=>'act',default=>['register']),
	      			hidden(-name=>'run',default=>['1']),
					submit(name=>"Create Account"),
		  			end_form;
	} else {
		my $name = param('name');
		my $email = param('email');
		my $password = param('password');
		my $error = UserAdd($name, $password, $email);
		if ($error) {
			print "Error: $error";
		} else {
			print "Congrats! new account created.";
			$action = "login";
			$run = 0;
		}
	}
}

if ($action eq "home") {
	
	print "Welcome to home!";
  ($useremail, $password) = (param('useremail'), param('password'));
  my ($table,$error);
  ($table,$error)=UserPf($useremail, $password);
  if (!$error) { 
    print "<h2>Available Permissions</h2>$table";
      }
  else{
    
  }
}

if ($action eq "portfolio") { 
	my $main_pf_template = HTML::Template->new(filename => 'main_pf.html');

  # call query to get portfolio name and user email
	my $portfolio_name = 'portfolio 1';
	my $email = 'root@root.com';
	# for each symbol in portfolio 
	# 	marketval += close;
	$main_pf_template->param(PF_NAME => $portfolio_name);
	$main_pf_template->param(VALUE => '');
	$main_pf_template->param(VOLATILITY => '');
	$main_pf_template->param(CORRELATION => '');

  my $pf_name = param("pf_name");
  # call query to update portfolio name

	# my @holding_info = ExecSQL($dbuser, $dbpasswd,
	#   		     "select symbol, num_shares from holdings where portfolio_name=? and user_email=?","COL",
	#   		     $portfolio_name, $email);
  my @holding_info = ExecSQL($dbuser, $dbpasswd,
             "select * from holdings where portfolio_name='portfolio 1' and user_email='root\@root.com'","");

  my $table_data = "";
 #  print "HELLO" . Dumper($table_data, join(',',@holding_info));
 #  print @holding_info;
	# foreach my $holding (@holding_info) {
    # print "HELLO" + ref($holding) + @holding_info;
    $table_data = "<tr><td>APPL</td><td>15</td>".
    "<td><a href='portfolio.pl?act=edit_holding&symbol=symbol&user_email=user_email&portfolio_name=portfolio_name'>Edit</a></td>".
    "<td><a href='portfolio.pl?act=view_stats&symbol=symbol&user_email=user_email&portfolio_name=portfolio_name'>View Stats</a></td></tr>";
  # }
  $main_pf_template->param(TABLE_DATA => $table_data);

	print $main_pf_template->output;
}

if ($action eq "edit_holding") { 
  my $edit_holding_template = HTML::Template->new(filename => 'edit_holding.html');
  my $symbol = param("symbol");
  my $user_email = param("user_email");
  my $portfolio_name = param("portfolio_name");
  #query here to get number of shares
  my $num_shares;

  $edit_holding_template->param(SYMBOL => $symbol);
  $edit_holding_template->param(NUM_SHARES => $num_shares);
  if ($run) {
    # query here to update number of shares
  }
  print $edit_holding_template->output;
}

print "<script src='https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js'></script>";
print "<script type='text/javascript' src='portfolio.js'></script>";
print "</body>";
print "</html>";


########################################### HELPER FUNCTIONS ###########################################

sub ValidUser {
	my ($useremail,$password)=@_;
  	my @col;
  	
  	eval {@col=ExecSQL($dbuser, $dbpasswd, 
  						"SELECT count(*) FROM pfusers WHERE email=? AND password=?", "COL",
  						$useremail, $password);
  	};
  	
  	if ($@) { 
    	return 0;
  	} else {
    	return $col[0]>0;
  	}
}# Checks validity of login

sub UserAdd { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "INSERT INTO pfusers (name, email, password) VALUES (?, ?, ?)",undef,@_);};
  return $@;
} # Adds new user (helps 'register' act)

sub AddPf {
  eval { ExecSQL($dbuser,$dbpasswd,
       "insert into portfolios (user_email, name, cash_account) values (?,?,?)",undef,@_);};
    return $@;
} # Adds pf for a user ##NEED TO CHECK THAT USER EXISTS, probably in function that calls this function

sub UserPf {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, 
              "select portfolios.name from portfolios where user_email= ?", "ROWS", 
              @_); };
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("portfolio_table",
          "2D",
         ["User email", "Portfolio name"],
         @rows),$@);
  }
} # Selects all portfolios of a user

sub PfHoldings {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, 
              "select symbol, num_shares from holdings where user_email=? and portfolio_name=?", "ROWS", 
              @_); };
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("holdings_table",
          "2D",
         ["Symbol", "Number of Shares"],
         @rows),$@);
  }
} # Selects all holdings associated with a portfolio

sub PfShares {
  eval {ExecSQL($dbuser,$dbpasswd, "select num_shares from holdings where symbol=? user_email=? and portfolio_name=?",undef,@_);};
  return $@;
} # Selects number of shares of a given company in a portfolio. ##NEED TO CHECK THAT PORTFOLIO CONTAINS COMPANY

sub ChangePfName {
  my ($newname, $useremail, $oldname)=@_;
  eval {ExecSQL($dbuser,$dbpasswd, "update portfolios set name=? where user_email=? and name=?",undef,$newname, $useremail, $oldname);};
  return $@;
} # Updates portfolio name

sub ChangeShares {
  eval {ExecSQL($dbuser,$dbpasswd, "update holdings set num_shares=? where user_email=? and portfolio_name=? and symbol=?",undef,@_);};
  return $@;
} # Updates the number of shares in a holding

sub ChangeCash {
  eval {ExecSQL($dbuser,$dbpasswd, "update portfolios set cash_account=? where user_email=? and name=?",undef,@_);};
  return $@;
} # Updates the cash account of a portfolio

sub DelHolding {
   eval {ExecSQL($dbuser,$dbpasswd, "delete from holdings where user_email=? and portfolio_name=? and symbol=?",undef,@_);};
  return $@;
}

########################################### HELPER-HELPER FUNCTIONS (from Prof Dinda) ###########################################
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
