package io.bytebakehouse.train.company.orchestrator.config;

import io.bytebakehouse.train.company.orchestrator.entity.*;
import io.bytebakehouse.train.company.orchestrator.entity.enums.*;
import io.bytebakehouse.train.company.orchestrator.repository.*;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.UUID;

@Configuration
public class DataSeeder {

    @Bean
    @Order(2)
    public CommandLineRunner seedDatabase(
            UserAccountRepository userAccountRepository,
            PassengerRepository passengerRepository,
            StationRepository stationRepository,
            RouteRepository routeRepository,
            RouteStopRepository routeStopRepository,
            TrainRepository trainRepository,
            CarriageRepository carriageRepository,
            SeatRepository seatRepository,
            TripRepository tripRepository,
            FareRepository fareRepository,
            BookingRepository bookingRepository,
            TicketRepository ticketRepository,
            PaymentRepository paymentRepository,
            SeatReservationRepository seatReservationRepository
    ) {
        return args -> {
            // Users
            List<UserAccount> users = new ArrayList<>();
            for (int i = 1; i <= 10; i++) {
                UserAccount user = new UserAccount();
                user.setEmail("user" + i + "@traincompany.com");
                user.setPasswordHash("hashed_password_" + i);
                user.setFullName("User " + i);
                user.setPhone("+1-555-" + String.format("%04d", i));
                user.setLocale("en_US");
                users.add(user);
            }
            userAccountRepository.saveAll(users);

            // Passengers
            List<Passenger> passengers = new ArrayList<>();
            for (int i = 0; i < users.size(); i++) {
                Passenger p = new Passenger();
                p.setUser(users.get(i));
                p.setFirstName("FirstName" + (i + 1));
                p.setLastName("LastName" + (i + 1));
                p.setDateOfBirth(LocalDate.of(1980 + i, 1 + (i % 12), 1 + (i % 28)));
                p.setDocumentType(DocumentType.passport);
                p.setDocumentNumber("PASS" + String.format("%06d", i + 1));
                passengers.add(p);
            }
            passengerRepository.saveAll(passengers);

            // Stations
            String[] stationCodes = {"ROM", "MIL", "VEN", "FLO", "NAP", "TUR", "BOL", "GEN"};
            String[] cities = {"Rome", "Milan", "Venice", "Florence", "Naples", "Turin", "Bologna", "Genoa"};
            List<Station> stations = new ArrayList<>();
            for (int i = 0; i < stationCodes.length; i++) {
                Station s = new Station();
                s.setCode(stationCodes[i]);
                s.setName(cities[i] + " Central");
                s.setCity(cities[i]);
                s.setCountry("Italy");
                s.setLatitude(BigDecimal.valueOf(40 + i));
                s.setLongitude(BigDecimal.valueOf(10 + i));
                s.setTimezone("Europe/Rome");
                stations.add(s);
            }
            stationRepository.saveAll(stations);

            // Routes
            List<Route> routes = new ArrayList<>();
            for (int i = 0; i < 3; i++) {
                Route r = new Route();
                r.setCode("ROUTE-" + (i + 1));
                r.setName("Express Route " + (i + 1));
                r.setNotes("High-speed service");
                routes.add(r);
            }
            routeRepository.saveAll(routes);

            // Trains
            List<Train> trains = new ArrayList<>();
            for (int i = 1; i <= 5; i++) {
                Train t = new Train();
                t.setRegistration("TRAIN-" + i);
                t.setModel("Model-X" + i);
                t.setOperator("TrainCompany");
                t.setCapacity(200 + (i * 50));
                trains.add(t);
            }
            trainRepository.saveAll(trains);

            // Carriages & Seats
            List<Carriage> carriages = new ArrayList<>();
            List<Seat> seats = new ArrayList<>();
            for (Train train : trains) {
                for (int c = 1; c <= 4; c++) {
                    Carriage carriage = new Carriage();
                    carriage.setTrain(train);
                    carriage.setCarriageNumber(c);
                    carriage.setCarriageType(c <= 2 ? CarriageType.coach : CarriageType.sleeper);
                    carriage.setCapacity(50);
                    carriages.add(carriage);
                }
            }
            carriageRepository.saveAll(carriages);

            for (Carriage carriage : carriages) {
                for (int s = 1; s <= 20; s++) {
                    Seat seat = new Seat();
                    seat.setCarriage(carriage);
                    seat.setSeatNumber(s + (s % 2 == 0 ? "A" : "B"));
                    seat.setSeatClass(s <= 10 ? SeatClass.economy : SeatClass.standard);
                    seat.setPosition(s % 2 == 0 ? "window" : "aisle");
                    seat.setAccessible(s == 1);
                    seats.add(seat);
                }
            }
            seatRepository.saveAll(seats);

            // Fares
            List<Fare> fares = new ArrayList<>();
            String[] fareCodes = {"ECON-STD", "ECON-FLEX", "FIRST-PRM", "BUS-FLEX"};
            SeatClass[] fareClasses = {SeatClass.economy, SeatClass.economy, SeatClass.first, SeatClass.business};
            BigDecimal[] prices = {BigDecimal.valueOf(29.99), BigDecimal.valueOf(49.99), BigDecimal.valueOf(99.99), BigDecimal.valueOf(149.99)};
            for (int i = 0; i < fareCodes.length; i++) {
                Fare f = new Fare();
                f.setCode(fareCodes[i]);
                f.setName("Fare " + fareCodes[i]);
                f.setDescription("Travel with " + fareClasses[i]);
                f.setPrice(prices[i]);
                f.setCurrency("EUR");
                f.setSeatClass(fareClasses[i]);
                f.setRefundable(i % 2 == 1);
                f.setRefundPolicy(i % 2 == 1 ? FareRefundPolicy.fully_refundable : FareRefundPolicy.non_refundable);
                fares.add(f);
            }
            fareRepository.saveAll(fares);

            // Trips
            List<Trip> trips = new ArrayList<>();
            LocalDate today = LocalDate.now();
            for (int i = 0; i < 5; i++) {
                Trip trip = new Trip();
                trip.setRoute(routes.get(i % routes.size()));
                trip.setTrain(trains.get(i % trains.size()));
                trip.setServiceDate(today.plusDays(i));
                trip.setDepartureTime(LocalTime.of(8 + i, 0));
                trip.setArrivalTime(LocalTime.of(12 + i, 30));
                trip.setDepartureStation(stations.get(i % stations.size()));
                trip.setArrivalStation(stations.get((i + 2) % stations.size()));
                trip.setStatus("scheduled");
                trips.add(trip);
            }
            tripRepository.saveAll(trips);

            // Bookings, Tickets, Payments, Seat Reservations
            List<Booking> bookings = new ArrayList<>();
            List<Ticket> tickets = new ArrayList<>();
            List<Payment> payments = new ArrayList<>();
            List<SeatReservation> reservations = new ArrayList<>();

            for (int i = 0; i < 20; i++) {
                Booking booking = new Booking();
                booking.setUser(users.get(i % users.size()));
                booking.setBookingRef("BKG-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase());
                booking.setStatus(i % 5 == 0 ? BookingStatus.pending : BookingStatus.confirmed);
                booking.setTotalAmount(BigDecimal.valueOf(50 + (i * 10)));
                booking.setCurrency("EUR");
                booking.setExpiresAt(OffsetDateTime.now().plusDays(7));
                bookings.add(booking);

                // Payment
                Payment payment = new Payment();
                payment.setBooking(booking);
                payment.setAmount(booking.getTotalAmount());
                payment.setCurrency("EUR");
                payment.setMethod("card");
                payment.setStatus(booking.getStatus() == BookingStatus.confirmed ? PaymentStatus.completed : PaymentStatus.pending);
                payment.setPaidAt(booking.getStatus() == BookingStatus.confirmed ? OffsetDateTime.now() : null);
                payments.add(payment);

                // Ticket
                Ticket ticket = new Ticket();
                ticket.setBooking(booking);
                ticket.setPassenger(passengers.get(i % passengers.size()));
                ticket.setTrip(trips.get(i % trips.size()));
                ticket.setFare(fares.get(i % fares.size()));
                ticket.setSeat(seats.get(i % seats.size()));
                ticket.setTicketRef("TKT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase());
                ticket.setPrice(BigDecimal.valueOf(30 + (i * 5)));
                ticket.setCurrency("EUR");
                ticket.setStatus(booking.getStatus() == BookingStatus.confirmed ? TicketStatus.issued : TicketStatus.reserved);
                tickets.add(ticket);

                // Seat Reservation
                SeatReservation reservation = new SeatReservation();
                reservation.setTrip(trips.get(i % trips.size()));
                reservation.setSeat(seats.get(i % seats.size()));
                reservation.setReservedByBooking(booking);
                reservation.setReservedUntil(OffsetDateTime.now().plusHours(2));
                reservation.setStatus("reserved");
                reservations.add(reservation);
            }

            bookingRepository.saveAll(bookings);
            paymentRepository.saveAll(payments);
            ticketRepository.saveAll(tickets);
            seatReservationRepository.saveAll(reservations);

            // Link tickets back to reservations
            for (int i = 0; i < tickets.size() && i < reservations.size(); i++) {
                reservations.get(i).setTicket(tickets.get(i));
            }
            seatReservationRepository.saveAll(reservations);
            //TODO: Replace with Logger
            System.out.println("✅ Database seeded with sample data:");
            System.out.println("   - " + users.size() + " users");
            System.out.println("   - " + passengers.size() + " passengers");
            System.out.println("   - " + stations.size() + " stations");
            System.out.println("   - " + routes.size() + " routes");
            System.out.println("   - " + trains.size() + " trains");
            System.out.println("   - " + carriages.size() + " carriages");
            System.out.println("   - " + seats.size() + " seats");
            System.out.println("   - " + fares.size() + " fares");
            System.out.println("   - " + trips.size() + " trips");
            System.out.println("   - " + bookings.size() + " bookings");
            System.out.println("   - " + tickets.size() + " tickets");
            System.out.println("   - " + payments.size() + " payments");
            System.out.println("   - " + reservations.size() + " seat reservations");
        };
    }
}
