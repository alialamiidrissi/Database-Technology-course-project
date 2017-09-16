DROP procedure IF EXISTS addYear;
DROP procedure IF EXISTS addDay;
DROP procedure IF EXISTS addRoute;
DROP procedure IF EXISTS addDestination;
DROP procedure IF EXISTS addFlight;
DROP function IF EXISTS calculateFreeSeats;
DROP function IF EXISTS calculatePrice;
DROP procedure IF EXISTS addReservation;
DROP procedure IF EXISTS addPassenger;
DROP trigger IF EXISTS ticket_number;
DROP procedure IF EXISTS addContact;
DROP procedure IF EXISTS addPayment;
/*DROP procedure IF EXISTS ;    dont need to do checks... FK  already do it...  :(*/

delimiter //
CREATE PROCEDURE addYear(IN year INT, IN factor DOUBLE)
BEGIN
INSERT INTO weeklySchedule VALUES (year, factor);
END;//



CREATE PROCEDURE addDay(IN year INT, IN day VARCHAR(10), IN factor DOUBLE)
BEGIN
INSERT INTO dailyFactor VALUES (day, year, factor);
END;//


CREATE PROCEDURE addDestination(IN code VARCHAR(3), IN name VARCHAR(30), IN country VARCHAR(30))
BEGIN
INSERT INTO airport VALUES (code, name, country);
END;//


CREATE PROCEDURE addRoute(IN dcode VARCHAR(3), IN acode VARCHAR(3), IN year INT,IN routeprice INT)
BEGIN
INSERT INTO route(Depart, Arrive, Year,RoutePrice) VALUES (dcode, acode,year, routeprice);
END;//




CREATE PROCEDURE addFlight (IN dcode VARCHAR(3), IN acode VARCHAR(3), IN year INT, IN day VARCHAR(10), IN dept TIME)
BEGIN

DECLARE n INT DEFAULT 1;
DECLARE var INT;
	INSERT INTO weeklyFlight(Year, Day, DepartureTime, Route) VALUES (year, day, dept, (SELECT route.ID FROM route WHERE route.Arrive = acode AND route.Depart = dcode AND route.Year = year));

SET var := LAST_INSERT_ID();

REPEAT 
	INSERT INTO flight(Week, WeeklyFlight) VALUES (n, var);
	SET n := n + 1;
UNTIL n > 52
END REPEAT;
END;//


/*FUNCTIONS*/


CREATE FUNCTION calculateFreeSeats(flightNum INT) RETURNS INT
BEGIN
DECLARE seats INT DEFAULT 1;

/*SELECT COUNT() INTO seats FROM ticket WHERE ticket.ResNr IN (SELECT reservation.NbPassengers  FROM reservation WHERE reservation.Flight = flightNum (SELECT reservation.ID FROM reservation WHERE payment.ResNr = reservation.ID))*/

/*SELECT COUNT(*) INTO seats FROM ticket WHERE ticket.ResNr IN(SELECT reservation.ID FROM reservation INNER JOIN payment 
	ON reservation.ID = payment.ResNr AND reservation.Flight = flightNum);*/

SELECT SUM(reservation.NbPassengers) INTO seats FROM reservation INNER JOIN payment 
	ON reservation.ID = payment.ResNr AND reservation.Flight = flightNum;


IF(seats IS NULL) THEN
	SET seats := 40;
ELSE
	SET seats := GREATEST(40 - seats, 0);
END IF;



RETURN seats;
END;//


CREATE FUNCTION calculatePrice( flightNum INT) RETURNS DOUBLE
BEGIN
DECLARE day VARCHAR(10);
DECLARE year, wfID INT; 
DECLARE wfactor, pfactor, rprice DOUBLE;
	SELECT WeeklyFlight INTO wfID FROM flight where flight.ID = flightNum;
	SELECT weeklyFlight.Year, weeklyFlight.Day INTO year, day FROM weeklyFlight WHERE weeklyFlight.ID = wfID;
	SELECT weeklySchedule.ProfitFactor INTO pfactor FROM weeklySchedule WHERE weeklySchedule.Year = year;


	
	SELECT dailyFactor.Factor INTO wfactor FROM dailyFactor WHERE dailyFactor.Day = day;
 
	SELECT RoutePrice INTO rprice FROM route WHERE route.ID = (SELECT Route FROM weeklyFlight WHERE weeklyFlight.ID = wfID);


RETURN  round(rprice * wfactor * ((40-calculateFreeSeats(flightNum)+1)/40) * pfactor, 3);
END;//

CREATE TRIGGER ticket_number AFTER INSERT ON payment FOR EACH ROW
BEGIN
Declare id INT;
declare resNb INT;

SET resNb := NEW.resNr;
REPEAT
	REPEAT
		SET id:= 20000*RAND();
		until NOT EXISTS(SELECT ticket.TicketID FROM ticket where ticket.TicketID = id)
	END REPEAT;
	UPDATE ticket SET  ticket.TicketID = id  where (ticket.ResNr = resNb AND ticket.TicketID is NULL) LIMIT 1;
	until NOT EXISTS(SELECT ticket.TicketID FROM ticket where (ticket.ResNr = resNb AND ticket.TicketID is NULL))
END REPEAT;
END;//
 
CREATE PROCEDURE addReservation(IN depCode VARCHAR(3),IN arriveCode VARCHAR(3),IN year INT,IN week INT,IN day VARCHAR(10),IN time TIME ,IN nbPassenger INT, OUT resNr INT)
BEGIN
declare flightID INT;
declare seatsAvailable INT;

select flight.ID into flightID from flight  where flight.WeeklyFlight = (select weeklyFlight.ID from weeklyFlight where weeklyFlight.Route = (select route.ID from route where depCode = route.Depart AND arriveCode = route.Arrive AND route.Year = year ) AND weeklyFlight.Day = day AND weeklyFlight.DepartureTime = time) AND week = flight.Week;
IF flightID IS NULL THEN
	SELECT "There exist no flight for the given route, date and time" AS "Message";
ELSE
	SET seatsAvailable := calculateFreeSeats(flightID);
	SELECT seatsAvailable;
	IF seatsAvailable-nbPassenger < 0 THEN
		SELECT "There are not enough seats available on the chosen flight" AS "Message";
	ELSE
		INSERT INTO reservation(NbPassengers,Flight) values (nbPassenger,flightID);
		SET resNr := LAST_INSERT_ID();
		SELECT "OK result" AS "Message";
	END IF;
END IF;
END;//

CREATE PROCEDURE addPassenger(IN reservation_nr INT , IN passport_number INT , IN name VARCHAR(30))
BEGIN
DECLARE nbPass INT;


IF NOT EXISTS(select reservation.ID from reservation where reservation_nr = reservation.ID) THEN 
	SELECT "The given reservation number does not exist" AS "Message";
ELSE
	IF  EXISTS(select payment.ResNr from payment where reservation_nr = payment.ResNr) THEN 
		SELECT "The booking has already been payed and no futher passengers can be added" AS "Message";
	ELSE
		INSERT INTO passenger values (passport_number, name) ON DUPLICATE KEY UPDATE passenger.Name=name;
		INSERT INTO ticket(PassNr,ResNr) values (passport_number, reservation_nr);
		SELECT "OK result" AS "Message";
		
	END IF;
END IF;
END;//


CREATE PROCEDURE addContact(IN reservation_nr INT,IN passport_number INT, IN email VARCHAR(30), IN phone BIGINT)
BEGIN
IF NOT EXISTS(select reservation.ID from reservation where reservation_nr = reservation.ID) THEN 
	SELECT "The given reservation number does not exist" AS "Message";
ELSE
	IF NOT EXISTS(select passenger.PassNr from passenger where passport_number = passenger.PassNr) THEN 
		SELECT "The person is not a passenger of the reservation" AS "Message";
	ELSE
		INSERT INTO contact values (passport_number, email,phone) ON DUPLICATE KEY UPDATE contact.Email = email , contact.Phone = phone;
		UPDATE reservation SET reservation.Contact = passport_number where reservation.ID = reservation_nr;
	   SELECT "OK result" AS "Message";
	END IF;
END IF;
END;//

CREATE PROCEDURE addPayment (IN reservation_nr INT ,IN cardholder_name VARCHAR(30), credit_card_number BIGINT)
BEGIN
declare flightID,nbPass INT;
declare priceCalculated DOUBLE;



IF NOT EXISTS(select reservation.ID from reservation where reservation_nr = reservation.ID) THEN 
	SELECT "The given reservation number does not exist" AS "Message";
ELSE
	IF (select reservation.Contact from reservation where reservation_nr = reservation.ID) IS NULL THEN 
		SELECT "The reservation has no contact yet" AS "Message";
	ELSE
		SELECT COUNT(*) INTO nbPass FROM ticket WHERE ticket.ResNr = reservation_nr;
		SELECT reservation.Flight into flightID from reservation where reservation_nr = reservation.ID LIMIT 1;
 		IF (nbPass >= calculateFreeSeats(flightID)) THEN
			SELECT "There are not enough seats available on the flight anymore, deleting reservation" AS "Message";
			DELETE FROM ticket WHERE ticket.ResNr = reservation_nr;
			DELETE FROM reservation WHERE reservation.ID = reservation_nr;
		ELSE	
			INSERT INTO creditCard values (credit_card_number,cardholder_name) ON DUPLICATE KEY UPDATE creditCard.CardHolder =cardholder_name ;
			SELECT "going to sleep" as "message";
/* for question 10*/
			SELECT SLEEP(15);
/**/

			SET priceCalculated := calculatePrice(flightID);
			INSERT INTO payment(ResNr,BookingPrice, CardNr)  values (reservation_nr,priceCalculated ,credit_card_number);
		   	SELECT "OK result" AS "Message";
		END IF;
	END IF;
END IF;
END;//
delimiter ;

/*IF ((SELECT COUNT(*) FROM ticket where ticket.ResNr = reservation_nr) =
		    (SELECT reservation.NbPassengers FROM reservation WHERE reservation.ID = reservation_nr)) THEN
			SELECT "too many passsengers for the reservation" AS "Message";*/


