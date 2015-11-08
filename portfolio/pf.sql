delete from users;
delete from portfolios;
delete from holdings;
delete from holdingHistory;
delete from historical_Data;

commit;

drop table historical_Data;
drop table holdingHistory;
drop table holdings;
drop table portfolios;
drop table users;


create table users (
	email varchar(256) not null primary key
		constraint email_good CHECK (email LIKE '%@%'),
	name varchar(64) not null,
	password varchar(64) NOT NULL
	);

create table portfolios (
	user_email varchar(64) NOT NULL references users(email)	
		ON DELETE cascade,
	name varchar(64) NOT NULL UNIQUE,	
	cash_account number default 0 not null
	-- constraint primary key (user_email, name)
);

create table holdings (
	symbol varchar(64) not null UNIQUE,
	user_email varchar(64) NOT NULL references users(email)	
	--references users or portfolios?
		ON DELETE cascade,
	portfolio_name varchar(64) NOT NULL references portfolios(name)
		ON DELETE cascade,
	num_shares NUMBER default 0 NOT NULL
	-- constraint primary key (symbol, user_email, portfolio_name)
);

create table historical_Data (
	symbol varchar(64) NOT NULL unique,
	timestamp varchar(64) NOT NULL unique, 	
	--may use date and time variables instead of string
	open number NOT NULL,
	close number NOT NULL,
	high number NOT NULL,
	low number NOT NULL,
	volume number
	-- constraint primary key (symbol, timestamp)
);

--may not need this table
create table holdingHistory (
	holding_symbol varchar(64) NOT NULL references holdings(symbol)
		ON DELETE cascade,													
		--might only need one of these symbols
	histdata_symbol varchar(64) NOT NULL references historical_Data(symbol)
		ON DELETE cascade,
	timestamp varchar(64) NOT NULL references historical_Data(timestamp)
		ON DELETE cascade,
	user_email varchar(64) NOT NULL references users(email)
		ON DELETE cascade,
	pf_name varchar(64) NOT NULL references portfolios(name)
		ON DELETE cascade
	-- constraint primary key (holding_symbol, histdata_symbol, timestamp, user_email, pf_name)
);

INSERT INTO users (email, name, password) VALUES ('root@root.com', 'root', 'rootroot');

INSERT INTO portfolios (user_email, name, cash_account) VALUES ('root@root.com', 'portfolio 1', 0.00);

INSERT INTO holdings (symbol, user_email, portfolio_name, num_shares) VALUES ('APPL', 'root@root.com', 'portfolio 1', 1);

INSERT INTO historical_Data (symbol, timestamp, open, close, high, low, volume) VALUES ('APPL', '00:00:00', 5, 6, 10, 3, 1);

INSERT INTO holdingHistory (holding_symbol, histdata_symbol, timestamp, user_email, pf_name) VALUES ('APPL', 'APPL', '00:00:00', 'root@root.com', 'portfolio 1');

-- CREATE VIEW histData as recent_data UNION ALL historical_Data;
