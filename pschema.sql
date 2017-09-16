

DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS creditCard CASCADE;
DROP TABLE IF EXISTS ticket CASCADE;
DROP TABLE IF EXISTS reservation CASCADE;
DROP TABLE IF EXISTS contact CASCADE;
DROP TABLE IF EXISTS passenger CASCADE;
DROP TABLE IF EXISTS flight CASCADE;
DROP TABLE IF EXISTS weeklyFlight CASCADE;
DROP TABLE IF EXISTS dailyFactor CASCADE;
DROP TABLE IF EXISTS route CASCADE;
DROP TABLE IF EXISTS weeklySchedule CASCADE;
DROP TABLE IF EXISTS airport CASCADE;
DROP FUNCTION IF EXISTS returnCityName ;
DROP VIEW IF EXISTS allFlights ;
DROP VIEW IF EXISTS temp1 ;




CREATE TABLE weeklySchedule(
Year INT NOT NULL,
ProfitFactor DOUBLE, 
CONSTRAINT pk_weeklySchedule PRIMARY KEY(year)) ENGINE=InnoDB;

CREATE TABLE dailyFactor(
Day VARCHAR(10) NOT NULL,
Year INT NOT NULL,
Factor DOUBLE,
CONSTRAINT pk_dailyFactor PRIMARY KEY(day,year)) ENGINE=InnoDB;

CREATE TABLE weeklyFlight(
ID INT NOT NULL AUTO_INCREMENT,
Year INT NOT NULL,
Day VARCHAR(10) NOT NULL,
DepartureTime TIME,
Route INT NOT NULL,
CONSTRAINT pk_weeklyFlight PRIMARY KEY(ID)) ENGINE=InnoDB;

CREATE TABLE airport(
 Code VARCHAR(3) NOT NULL,
 Name VARCHAR(30),
 Country VARCHAR(30),
 CONSTRAINT pk_airport PRIMARY KEY(Code)) ENGINE=InnoDB;

CREATE TABLE route(
 ID INT NOT NULL AUTO_INCREMENT,
 Depart VARCHAR(3) NOT NULL,
 Arrive VARCHAR(3) NOT NULL,
 RoutePrice DOUBLE, 
 Year INT NOT NULL,
 CONSTRAINT pk_route PRIMARY KEY(ID)) ENGINE=InnoDB;

CREATE TABLE flight(
 ID INT NOT NULL AUTO_INCREMENT,
 Week INT,
 WeeklyFlight INT NOT NULL,
 CONSTRAINT pk_flight PRIMARY KEY(ID)) ENGINE=InnoDB;

CREATE TABLE reservation(
 ID INT NOT NULL AUTO_INCREMENT,
 NbPassengers INT,
 Flight INT NOT NULL,
 Contact INT,
 CONSTRAINT pk_reservation PRIMARY KEY(ID)) ENGINE=InnoDB;

CREATE TABLE passenger(
 PassNr INT NOT NULL,
 Name VARCHAR(30),
 CONSTRAINT pk_reservation PRIMARY KEY(PassNr)) ENGINE=InnoDB;

CREATE TABLE contact(
 PassNr INT NOT NULL,
 Email VARCHAR(30),
 Phone BIGINT,
 CONSTRAINT pk_Contact PRIMARY KEY(PassNr)) ENGINE=InnoDB;

CREATE TABLE ticket(
 PassNr INT NOT NULL,
 TicketID INT ,
 ResNr INT NOT NULL,
 CONSTRAINT pk_Ticket PRIMARY KEY(PassNr,ResNr)) ENGINE=InnoDB;

CREATE TABLE payment(
 ID INT NOT NULL AUTO_INCREMENT,
 ResNr INT NOT NULL,
 BookingPrice DOUBLE,
 CardNr BIGINT,
 CONSTRAINT pk_Ticket PRIMARY KEY(ID)) ENGINE=InnoDB;

CREATE TABLE creditCard(
 CardNr BIGINT,
 CardHolder VARCHAR(30),
 CONSTRAINT pk_creditCard PRIMARY KEY(CardNr)) ENGINE=InnoDB;



ALTER TABLE dailyFactor ADD CONSTRAINT fk_year FOREIGN KEY (Year) REFERENCES weeklySchedule(Year);

ALTER TABLE weeklyFlight ADD CONSTRAINT fk_year2 FOREIGN KEY (Year) REFERENCES dailyFactor(Year);
ALTER TABLE weeklyFlight ADD CONSTRAINT fk_day FOREIGN KEY (Day) REFERENCES dailyFactor(Day);
ALTER TABLE weeklyFlight ADD CONSTRAINT fk_route FOREIGN KEY (Route) REFERENCES route(ID);

ALTER TABLE route ADD CONSTRAINT fk_dep FOREIGN KEY (Depart) REFERENCES airport(Code);
ALTER TABLE route ADD CONSTRAINT fk_arr FOREIGN KEY (Arrive) REFERENCES airport(Code);
ALTER TABLE route ADD CONSTRAINT fk_routeYear FOREIGN KEY (Year) REFERENCES weeklySchedule(Year);

ALTER TABLE flight ADD CONSTRAINT fk_weeklyFlight FOREIGN KEY (WeeklyFlight) REFERENCES weeklyFlight(ID);

ALTER TABLE payment ADD CONSTRAINT fk_card FOREIGN KEY (CardNr) REFERENCES creditCard(CardNr);
ALTER TABLE payment ADD CONSTRAINT fk_resnr2 FOREIGN KEY (ResNr) REFERENCES reservation(ID);

ALTER TABLE contact ADD CONSTRAINT fk_passenger FOREIGN KEY (PassNr) REFERENCES passenger(PassNr);

ALTER TABLE ticket ADD CONSTRAINT fk_passNr FOREIGN KEY (PassNr) REFERENCES passenger(PassNr);
ALTER TABLE ticket ADD CONSTRAINT fk_resNr FOREIGN KEY (ResNr) REFERENCES reservation(ID);

ALTER TABLE reservation ADD CONSTRAINT fk_flight FOREIGN KEY (Flight) REFERENCES flight(ID);
ALTER TABLE reservation ADD CONSTRAINT fk_contact FOREIGN KEY (Contact) REFERENCES contact(PassNr);

delimiter //
CREATE FUNCTION returnCityName( airport_code VARCHAR(3)) RETURNS VARCHAR(30)
BEGIN
declare nameCity VARCHAR(30);
select a.Name into nameCity from airport a where a.Code = airport_code LIMIT 1;
return nameCity;
END;//
delimiter ;

CREATE VIEW temp1 AS SELECT DISTINCT  r.Depart,r.Arrive,wf.DepartureTime,wf.Day,wf.Year,wf.ID from route r join weeklyFlight wf where r.ID = wf.Route ;
CREATE VIEW allFlights AS SELECT DISTINCT  returnCityName(tp1.Depart) as departure_city_name ,returnCityName(tp1.Arrive) as destination_city_name,tp1.DepartureTime as departure_time,tp1.Day as departure_day,f.Week as departure_week,tp1.Year as departure_year,calculateFreeSeats(f.ID) as  nr_of_free_seats, calculatePrice(f.ID) as current_price_per_seat from temp1 tp1 join flight f where f.weeklyFlight = tp1.ID ;
