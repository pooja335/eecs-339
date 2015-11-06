create table users (

	email varchar(256) not null UNIQUE primary key
		constraint email_ok CHECK (email LIKE '%@%'),

	name varchar(64) not null,

	password varchar(64) NOT NULL
	);


create table portfolios (
	user_email varchar(64) NOT NULL references users(email)	
		ON DELETE cascade,

	name varchar(64) NOT NULL UNIQUE,	

	cash_account number default 0 not null,

	constraint primary key (user_email, name)

);

create table holdings (

	symbol varchar(64) not null UNIQUE,
	user_email varchar(64) NOT NULL references users(email)	//references users or portfolios?
		ON DELETE cascade,
	portfolio_name varchar(64) NOT NULL references portfolios(name)
		ON DELETE cascade,
	num_shares NUMBER default 0 NOT NULL,

	constraint primary key (symbol, user_email, portfolio_name)

);

//may not need this table
create table holdingHistory (

	holding_symbol varchar(64) NOT NULL references holdings(symbol)
		ON DELETE cascade,													//might only need one of these symbols
	histdata_symbol varchar(64) NOT NULL references historicalData(symbol)
		ON DELETE cascade,
	timestamp varchar(64) NOT NULL references historicalData(timestamp)
		ON DELETE cascade,
	user_email varchar(64) NOT NULL references users(email)
		ON DELETE cascade,
	pf_name varchar(64) NOT NULL references portfolios(name)
		ON DELETE cascade,

	constraint primary key (holding_symbol, histdata_symbol, timestamp, user_email, pf_name)

);

create table historicalData (
	symbol varchar(64) NOT NULL unique,
	timestamp varchar(64) NOT NULL unique, 	//may use date and time variables instead of string
	open number NOT NULL,
	close number NOT NULL,
	high number NOT NULL,
	low number NOT NULL,
	volume number,

	constraint primary key (symbol, timestamp)
);

INSERT INTO users (email, name, password) VALUES ('root@root.com', 'root', 'rootroot');

INSERT INTO portfolios (user_email, name, cash_account) VALUES ('root@root.com', 'root', 0.00);

INSERT INTO holdings (symbol, user_email, portfolio_name, num_shares) VALUES ('APPL', 'root@root.com', 'portfolio 1', 1);

INSERT INTO holdingHistory (holding_symbol, histdata_symbol, timestamp, user_email, pf_name) VALUES ('APPL', 'APPL', '00:00:00', 'root@root.com', 'portfolio 1');

CREATE VIEW histData as recent_data UNION ALL historicalData
