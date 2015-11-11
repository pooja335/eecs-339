delete from RecentStocksDaily;
delete from holdings;
delete from portfolios;
delete from pfusers;

commit;

drop view HistoricalData;
drop table RecentStocksDaily;
drop table holdings;
drop table portfolios;
drop table pfusers;

create table pfusers (
--
	name varchar(64) not null,
--
	email varchar(256) not null primary key
		constraint email_good CHECK (email LIKE '%@%'),
--
	password varchar(64) NOT NULL
	);


create table portfolios (
	user_email varchar(64) NOT NULL references pfusers(email)	
		ON DELETE cascade,
--
	name varchar(64) NOT NULL,	
--
	cash_account number default 0 not null,
--
	constraint pf_unique UNIQUE(user_email, name)
);

create table holdings (
--
	symbol varchar(64) not null UNIQUE,
--
	user_email varchar(64) NOT NULL,
--
	portfolio_name varchar(64) NOT NULL,
--
	num_shares NUMBER default 0 NOT NULL,
--
	constraint holdings_ref FOREIGN KEY (user_email, portfolio_name) references portfolios(user_email, name),
--
	constraint holdings_unique UNIQUE(symbol, user_email, portfolio_name)
);


create table RecentStocksDaily (
	--
	symbol varchar2(16) NOT NULL,
	--
	timestamp number NOT NULL, 	
	--
	open number NOT NULL,
	--
	high number NOT NULL,
	--
	low number NOT NULL,
	--
	close number NOT NULL,
	--
	volume number NOT NULL,
	--
	constraint hist_unique UNIQUE(symbol, timestamp)
);



CREATE VIEW HistoricalData AS ((SELECT * FROM cs339.StocksDaily) UNION (SELECT * FROM RecentStocksDaily));





--Make dummy data
INSERT INTO pfusers (name, email, password) VALUES ('root', 'root@root.com', 'rootroot');
INSERT INTO portfolios (user_email, name, cash_account) VALUES ('root@root.com', 'portfolio 1', 100.00);
