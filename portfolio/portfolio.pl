#!/usr/bin/perl -w
use strict;

use DBI;
my $dbuser="pps860";
my $dbpasswd="zaM7in9Wf";
my @sqlinput=();
my @sqloutput=();
my $debug;

#use Time::ParseDate;
use CGI qw(:standard);
use HTML::Template;
use Data::Dumper;
use Getopt::Long;
use Time::ParseDate;
use Time::CTime;
use FileHandle;

#use stock_data_access;


# receive cookies from client
my $sessioncookie = "pfsession";
my $inputsessioncookie = cookie($sessioncookie);


my $outputsessioncookie = undef;
my $deletecookie=0;
my $user_email = undef;
my $password = undef;
my $badlogin=0;

my $action;
my $run;

#set action and run vals
if (defined(param("act"))) {
	$action=param("act");
	
	if (defined(param("run"))){ 
		$run = param("run") == 1;
	} else {
    	$run = 0;
  	}
} else { # set default action
	if(defined($inputsessioncookie)) { # if they're logged in, send 'em home
		$action="home";
		$run=0;
	} else { # otherwise lock 'em out
		$action="login";
  		$run = 0;
	}
}

# handle session cookie
if (defined($inputsessioncookie)) {
	($user_email,$password) = split(/\//,$inputsessioncookie);
  	$outputsessioncookie = $inputsessioncookie;
} else {
	# $action = "edit_holding";
  # $action = "login";
	undef $outputsessioncookie;
}

if ($action eq "login") {
	if ($run) {#if login attempt
		($user_email, $password) = (param('user_email'), param('password'));
		if ( ValidUser($user_email, $password )) {
			$outputsessioncookie = join("/",$user_email,$password);
			$action = "home";
			$run = 0;
 		} else { #try again with empty form
			$badlogin = 1;
			$action = "login";
			$run = 0;
		}
	} else { #just show the form
		undef $inputsessioncookie;
		undef $user_email;
		undef $password;
	}
}


if ($action eq "logout") {
  	$deletecookie=1;
  	undef $user_email;
  	undef $password;
  	$run = 0;
}

#send cookies to client
my @outputcookies;

my $badcookie = cookie(-name => "badcookie",
						-value => "badcookie",
						-expires=>($deletecookie ? '-1h' : '+1h'));
	push @outputcookies, $badcookie; # dummy cookie for testing

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
				"Email:",textfield(-name=>'user_email'),	p,
	  			"Password:",password_field(-name=>'password'),p,
	    		hidden(-name=>'act',default=>['login']),
	      		hidden(-name=>'run',default=>['1']),
				submit(name=>"Log In"),
		  		end_form;
  	}
  	if ($badlogin) { 
    	print "<p>Login failed.  Try again.</p><br>";
  	} 
   	print "<a href=\"portfolio.pl?act=register\">Make an account</a>";
}


if ($action eq "logout") {
  print "<p>You have logged out.</p><br>";
  print "<a href=\"portfolio.pl?act=login\">Login</a>";
}

if ($action eq "register") {
	if(!$run) {
		print h2('Register New Account');
		print start_form(-name=>'Register'),
					"Name:", textfield(-name=>'name'), p,
					"Email:", textfield(-name=>'user_email'), p,
	  				"Password:", password_field(-name=>'password'), p,
            "Portfolio Name:",textfield(-name=>'portfolio_name'),p,
	    			hidden(-name=>'act',default=>['register']),
	      			hidden(-name=>'run',default=>['1']),
					submit(name=>"Create Account"),
		  			end_form;
	} else {
		my $name = param('name');
		my $user_email = param('user_email');
		my $password = param('password');
    my $portfolio_name = param('portfolio_name');
		my $error1 = UserAdd($name, $user_email, $password);
    my $error2 = AddPf($user_email, $portfolio_name, 0);
		if ($error1 or $error2) {
			print "Error: $error1";
      print "Error: $error2";
		} else {
			print "Congrats! New account created.<br>";
      print "<a href=\"portfolio.pl?act=login\">Login</a><br>";
			$run = 0;
		}
	}
}

if ($action eq "home") {
	print h2("Welcome to home!");
	print "<a href=\"portfolio.pl?act=logout\">Logout</a>";
  ($user_email, $password) = (param('user_email'), param('password'));
	my @portfolios = UserPf($user_email);

	print h2("Portfolios");
  foreach my $pf (@portfolios) {
		print "<a href=\"portfolio.pl?act=portfolio&portfolio_name=$pf&user_email=$user_email\">$pf</a><br><br>";
	}
	my $new_pf_template = HTML::Template->new(filename => 'new_pf.html');
  $new_pf_template->param(USER_EMAIL => $user_email);
  if ($run) {
    my $user_email = param("user_email");
    my $portfolio_name = param("portfolio_name");
    my $error = AddPf($user_email, $portfolio_name, 0);
    $run = 0;
    print "<a href=\"portfolio.pl?act=portfolio&portfolio_name=$portfolio_name&user_email=$user_email\">$portfolio_name</a><br><br>";
    print "Congrats! New portfolio created.<br>";
  }
  print $new_pf_template->output;
}

if ($action eq "portfolio") { 
	my $main_pf_template = HTML::Template->new(filename => 'main_pf.html');

	my $portfolio_name = param("portfolio_name");
	my $user_email = param("user_email");

  my @holding_info = PfHoldings($user_email, $portfolio_name);
  my $holding_info = @holding_info;

  my $table_data = "";
  my $marketval = 0;
	for (my $i=0; $i < $holding_info; $i++) {
    $table_data = $table_data."<tr><td>".$holding_info[$i][0]."</td><td>".$holding_info[$i][1]."</td>".
    "<td><a href='portfolio.pl?act=edit_holding&symbol=".$holding_info[$i][0]."&user_email=".$user_email."&portfolio_name=".$portfolio_name."'>Edit</a></td>".
    "<td><a href='portfolio.pl?act=view_stats&symbol=".$holding_info[$i][0]."&user_email=".$user_email."&portfolio_name=".$portfolio_name."'>View Stats</a></td>";

    my $output = `~pdinda/339/HANDOUT/portfolio/quote.pl $holding_info[$i][0]`;
    if ($output =~ /close\t([0-9\.]+)/) {
      $marketval += $1 * $holding_info[$i][1];
    }
  }

  my @cash = PfCash($user_email, $portfolio_name);

  $main_pf_template->param(USER_EMAIL => $user_email);
  $main_pf_template->param(PORTFOLIO_NAME => $portfolio_name);
  $main_pf_template->param(VALUE => $marketval);
  $main_pf_template->param(VOLATILITY => '');
  $main_pf_template->param(CORRELATION => '');
  $main_pf_template->param(TABLE_DATA => $table_data);
  $main_pf_template->param(CASH_ACCOUNT => @cash);

	print $main_pf_template->output;
}

if ($action eq "edit_holding") { 
  my $edit_holding_template = HTML::Template->new(filename => 'edit_holding.html');
  my $symbol = param("symbol");
  my $user_email = param("user_email");
  my $portfolio_name = param("portfolio_name");
  my @num_shares = PfShares($symbol, $user_email, $portfolio_name);
  my @cash = PfCash($user_email, $portfolio_name);
  my $cash = $cash[0];

  $edit_holding_template->param(SYMBOL => $symbol);
  $edit_holding_template->param(USER_EMAIL => $user_email);
  $edit_holding_template->param(PORTFOLIO_NAME => $portfolio_name);
  $edit_holding_template->param(NUM_SHARES => @num_shares);
  if ($run) {
    print "Stock successfully updated.";
    my $new_num_shares = param("num_shares");
    my $num_share_diff = $new_num_shares - $num_shares[0];
    my $output = `~pdinda/339/HANDOUT/portfolio/quote.pl $symbol`;
    if ($output =~ /close\t([0-9\.]+)/) {
      $cash -= $1 * $num_share_diff;
    }
    ChangeCash($cash, $user_email, $portfolio_name);
    if ($new_num_shares == 0) {
      DelHolding($user_email, $portfolio_name, $symbol);
    }
    else {
      ChangeShares($new_num_shares, $user_email, $portfolio_name, $symbol);
    }
    $edit_holding_template->param(NUM_SHARES => $new_num_shares);
  }
  print $edit_holding_template->output;
}

if ($action eq "add_holding") { 
  my $add_holding_template = HTML::Template->new(filename => 'add_holding.html');
  my $user_email = param("user_email");
  my $portfolio_name = param("portfolio_name");
  my @cash = PfCash($user_email, $portfolio_name);
  my $cash = $cash[0];

  $add_holding_template->param(USER_EMAIL => $user_email);
  $add_holding_template->param(PORTFOLIO_NAME => $portfolio_name);

  if ($run) {
    print "Stock successfully added. Add another?";
    my $symbol = param("symbol");
    my $num_shares = param("num_shares");
    if ($num_shares != 0) {
      AddHolding($symbol, $user_email, $portfolio_name, $num_shares);

      # update the cash in their account
      my $quote_output = `~pdinda/339/HANDOUT/portfolio/quote.pl $symbol`;
      if ($quote_output =~ /close\t([0-9\.]+)/) {
        $cash -= $1 * $num_shares;
      }
      ChangeCash($cash, $user_email, $portfolio_name);

      # add to the recent stocks daily table
      my $quotehist_output = `~pdinda/339-f15/HANDOUT/portfolio/quotehist.pl --from=\"01/01/2006\" --open --high --low --close --vol $symbol`;
      my @timestamp_quotes = split /\n/, $quotehist_output;
      foreach my $timestamp_quote (@timestamp_quotes) {
        my @values = split /\t/, $timestamp_quote;
        AddRecentStocksDaily($symbol, $values[0], $values[2], $values[3], $values[4], $values[5], $values[6]);
      }
    }
  }
  print $add_holding_template->output;
}

if ($action eq "edit_cash") { 
  my $edit_cash_template = HTML::Template->new(filename => 'edit_cash.html');
  my $user_email = param("user_email");
  my $portfolio_name = param("portfolio_name");
  my @cash = PfCash($user_email, $portfolio_name);

  $edit_cash_template->param(USER_EMAIL => $user_email);
  $edit_cash_template->param(PORTFOLIO_NAME => $portfolio_name);
  $edit_cash_template->param(CASH_ACCOUNT => @cash);
  if ($run) {
    my $cash = param("cash");
    print "Cash account successfully updated.";
    ChangeCash($cash, $user_email, $portfolio_name);
    $edit_cash_template->param(CASH_ACCOUNT => $cash);
  }
  print $edit_cash_template->output;
}


if ($action eq "view_stats") { 
  print "<h2>Yesterday's Market Summary</h2>";
  my $symbol = param("symbol");
  my $user_email = param("user_email");
  my $portfolio_name = param("portfolio_name");
  my ($open, $close, $high, $low, $volume) = CurrentStats($symbol); 
  print "<h4>Open price: $open</h4>";
  print "<h4>Highest price: $high</h4>";
  print "<h4>Lowest price: $low</h4>";
  print "<h4>Close price: $close</h4>";
  print "<h4>Trading Volume: $volume</h4>";

  my $dates = [1970, 1971, 1972, 1973, 1974, 1975, 1976, 1977, 1978, 1979, 1980, 1981, 1982, 1983, 1984, 1985, 1986, 1987, 1988, 1989, 1990, 1991, 1992,
                  1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015];
  my $future_increments = [0.5, 1, 5, 10, 15, 20];
  if(!$run){
    print startform(-name=>'Dates'),
    'Select a Past Date Range to View:',
    br,
    "From: \t", popup_menu(-name=>'Beginning date', -values=> $dates),
    " To: ", popup_menu(-name=>'Ending date', -values=> $dates),
    br, br,
    'Select How far into the Future to Predict: ',
    br,
    popup_menu(-name=>'Future', -values=> $future_increments),
    hidden(-name=>'act',default=>['view_stats']),
            hidden(-name=>'run',default=>['1']),
            br,
    submit(-value=>'Go'),
    endform;
  }
  else{
    my $start_date = param('Beginning date');
    my $end_date = param('Ending date');
    my $future = param('Future');
    if($start_date >= $end_date){
      print "Error: The start date cannot be on or after the end date";
      $run = 0;
      $action = "view_stats";
    }
    else{
      # convert dates to seconds
      $start_date = ($start_date - 1970)*60*60*24*365;
      $end_date = ($end_date - 1970)*60*60*24*365;
      my $plot = 1;
      #my $output = `~pdinda/339/HANDOUT/portfolio/plot_stock.pl type=plot symbol=$symbol`;
      #print $output;
      my $past_graph = `~pdinda/339/HANDOUT/portfolio/get_data.pl  --from=$start_date --to=$end_date --close --plot $symbol\n`;
      print $past_graph;
      my $predictions = `~pdinda/339/HANDOUT/portfolio/time_series_symbol_project.pl $symbol $future`;
      print $predictions;
    }
  }
    
}


#end the page
print "<script src='https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js'></script>";
print "<script type='text/javascript' src='portfolio.js'></script>";
print "</body>";
print "</html>";



########################################### HELPER FUNCTIONS ###########################################

sub ValidUser {
	my ($user_email,$password)=@_;
  	my @col;
  	
  	eval {@col=ExecSQL($dbuser, $dbpasswd, 
  						"SELECT count(*) FROM pfusers WHERE email=? AND password=?", "COL",
  						$user_email, $password);
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
              "select portfolios.name from portfolios where user_email= ?", "COL", 
              @_); };
  if ($@) { 
    return (undef,$@);
  } else {
    return @rows;
  }
} # Selects all portfolios of a user

sub PfHoldings {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, 
              "select symbol, num_shares from holdings where user_email=? and portfolio_name=?", undef, 
              @_); };
  if ($@) { 
    return (undef,$@);
  } else {
    return @rows;
  }
} # Selects all holdings associated with a portfolio

sub PfShares {
  my @rows;
  eval { @rows = ExecSQL($dbuser,$dbpasswd, "select num_shares from holdings where symbol=? and user_email=? and portfolio_name=?","COL",@_); };
  if ($@) { 
    return (undef,$@);
  } else {
    return @rows;
  }
} # Selects number of shares of a given company in a portfolio. ##NEED TO CHECK THAT PORTFOLIO CONTAINS COMPANY

sub PfCash {
  my @rows;
  eval { @rows = ExecSQL($dbuser,$dbpasswd, "select cash_account from portfolios where user_email=? and name=?","COL",@_); };
  if ($@) { 
    return (undef,$@);
  } else {
    return @rows;
  }
} # Selects the cash account for a given portfolio

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

sub AddHolding {
  eval { ExecSQL($dbuser,$dbpasswd,
       "insert into holdings (symbol, user_email, portfolio_name, num_shares) values (?,?,?,?)",undef,@_);};
    return $@;
} # Adds holdings to a pf

sub CurrentStats {
  my @rows;
  eval {@rows = ExecSQL($dbuser,$dbpasswd,
       "select open, close, high, low, volume from RecentStocksDaily where symbol=? order by timestamp","COL",@_);};
    if ($@){
      return (undef, $@);
    }
    else{
      return $rows[0];
    }
}

sub AddRecentStocksDaily {
  eval { ExecSQL($dbuser,$dbpasswd,
       "insert into RecentStocksDaily (symbol, timestamp, open, high, low, close, volume) values (?,?,?,?,?,?,?)",undef,@_);};
    return $@;
} # Adds to recent stocks daily table



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
