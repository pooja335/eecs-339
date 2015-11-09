delete from pfusers;
delete from portfolios;
delete from holdings;
delete from holdingHistory;
delete from historicalData;

commit;

drop table historicalData;
drop table holdingHistory;
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

create table historicalData (
	--
	symbol varchar(64) NOT NULL unique,
	--
	timstamp varchar(64) NOT NULL unique, 	
	--
	open number NOT NULL,
	--
	close number NOT NULL,
	--
	high number NOT NULL,
	--
	low number NOT NULL,
	--
	volume number,
	--
	constraint hist_unique UNIQUE(symbol, timstamp)
);

-- create table holdingHistory (
-- 	--
-- 	holding_symbol varchar(64) NOT NULL,			
-- 	--										
-- 	histdata_symbol varchar(64) NOT NULL,
-- 	-- timestamp is a built in variable in sql, so use name timstamp
-- 	timstamp varchar(64) NOT NULL,
-- 	--
-- 	user_email varchar(64) NOT NULL,
-- 	--
-- 	pf_name varchar(64) NOT NULL,
-- 	--
-- 	constraint holdH_ref FOREIGN KEY (histdata_symbol, timstamp) references historicalData(symbol, timstamp),
-- 	--
-- 	constraint holdH_ref2 FOREIGN KEY (holding_symbol, user_email, pf_name) references holdings(symbol, user_email, portfolio_name),
-- 	--
-- 	constraint holdH_unique UNIQUE(holding_symbol, histdata_symbol, timstamp, user_email, pf_name)
-- );

INSERT INTO pfusers (name, email, password) VALUES ('root', 'root@root.com', 'rootroot');

INSERT INTO portfolios (user_email, name, cash_account) VALUES ('root@root.com', 'portfolio 1', 100.00);

INSERT INTO holdings (symbol, user_email, portfolio_name, num_shares) VALUES ('APPL', 'root@root.com', 'portfolio 1', 1);

--INSERT INTO holdingHistory (holding_symbol, histdata_symbol, timstamp, user_email, pf_name) VALUES ('APPL', 'APPL', '00:00:00', 'root@root.com', 'portfolio 1');

--CREATE VIEW histData as recent_data UNION ALL historicalData;
