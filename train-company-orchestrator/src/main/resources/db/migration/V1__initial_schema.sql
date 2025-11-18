-- Enable UUID generation (pgcrypto)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-------------------------
-- ENUMS
-------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ticket_status') THEN
        CREATE TYPE ticket_status AS ENUM ('reserved','issued','checked_in','cancelled','refunded');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'booking_status') THEN
        CREATE TYPE booking_status AS ENUM ('pending','confirmed','cancelled','failed');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
        CREATE TYPE payment_status AS ENUM ('pending','completed','failed','refunded');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'seat_class') THEN
        CREATE TYPE seat_class AS ENUM ('economy','standard','first','business');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'carriage_type') THEN
        CREATE TYPE carriage_type AS ENUM ('coach','sleeper','dining','cargo');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'doc_type') THEN
        CREATE TYPE doc_type AS ENUM ('id_card','passport','other');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fare_refund_policy') THEN
        CREATE TYPE fare_refund_policy AS ENUM ('non_refundable','partially_refundable','fully_refundable');
    END IF;
END$$;

-------------------------
-- USERS (accounts)
-------------------------
CREATE TABLE IF NOT EXISTS users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text UNIQUE NOT NULL,
    password_hash text,
    full_name text,
    phone text,
    locale text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (lower(email));

-------------------------
-- PASSENGERS
-------------------------
CREATE TABLE IF NOT EXISTS passengers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    date_of_birth date,
    doc_type doc_type,
    doc_number text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_passengers_user ON passengers (user_id);

-------------------------
-- STATIONS
-------------------------
CREATE TABLE IF NOT EXISTS stations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text UNIQUE,
    name text NOT NULL,
    city text,
    region text,
    country text,
    latitude numeric(9,6),
    longitude numeric(9,6),
    timezone text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stations_city ON stations (city);

-------------------------
-- ROUTES & ROUTE_STOPS
-------------------------
CREATE TABLE IF NOT EXISTS routes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text UNIQUE,
    name text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS route_stops (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id uuid NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    station_id uuid NOT NULL REFERENCES stations(id) ON DELETE RESTRICT,
    stop_sequence integer NOT NULL,
    scheduled_arrival interval,
    scheduled_departure interval,
    dwell_seconds integer,
    UNIQUE (route_id, stop_sequence),
    UNIQUE (route_id, station_id)
);

CREATE INDEX IF NOT EXISTS idx_route_stops_route ON route_stops(route_id);

-------------------------
-- TRAINS, CARRIAGES, SEATS
-------------------------
CREATE TABLE IF NOT EXISTS trains (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    registration text UNIQUE,
    model text,
    operator text,
    capacity integer,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS carriages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    train_id uuid NOT NULL REFERENCES trains(id) ON DELETE CASCADE,
    carriage_number integer NOT NULL,
    carriage_type carriage_type NOT NULL DEFAULT 'coach',
    capacity integer,
    notes text,
    UNIQUE (train_id, carriage_number)
);

CREATE TABLE IF NOT EXISTS seats (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    carriage_id uuid NOT NULL REFERENCES carriages(id) ON DELETE CASCADE,
    seat_number text NOT NULL,
    seat_class seat_class NOT NULL DEFAULT 'standard',
    position text,
    is_accessible boolean DEFAULT false,
    UNIQUE (carriage_id, seat_number)
);

CREATE INDEX IF NOT EXISTS idx_seats_carriage ON seats(carriage_id);

-------------------------
-- SERVICES / TRIPS
-------------------------
CREATE TABLE IF NOT EXISTS trips (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id uuid NOT NULL REFERENCES routes(id) ON DELETE RESTRICT,
    train_id uuid REFERENCES trains(id) ON DELETE SET NULL,
    service_date date NOT NULL,
    departure_time time NOT NULL,
    arrival_time time NOT NULL,
    departure_station_id uuid NOT NULL REFERENCES stations(id) ON DELETE RESTRICT,
    arrival_station_id uuid NOT NULL REFERENCES stations(id) ON DELETE RESTRICT,
    status text NOT NULL DEFAULT 'scheduled',
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(route_id, service_date)
);

CREATE INDEX IF NOT EXISTS idx_trips_route_date ON trips(route_id, service_date);
CREATE INDEX IF NOT EXISTS idx_trips_service_route ON trips(service_date, route_id);

-------------------------
-- FARES & FARE RULES
-------------------------
CREATE TABLE IF NOT EXISTS fares (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text UNIQUE NOT NULL,
    name text,
    description text,
    price numeric(10,2) NOT NULL,
    currency char(3) DEFAULT 'EUR',
    seat_class seat_class,
    refundable boolean DEFAULT false,
    refund_policy fare_refund_policy DEFAULT 'non_refundable',
    valid_from timestamptz,
    valid_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fares_price ON fares (price);

-------------------------
-- BOOKINGS
-------------------------
CREATE TABLE IF NOT EXISTS bookings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    booking_ref text NOT NULL UNIQUE,
    status booking_status NOT NULL DEFAULT 'pending',
    total_amount numeric(12,2) NOT NULL DEFAULT 0,
    currency char(3) DEFAULT 'EUR',
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_bookings_user ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

-------------------------
-- PAYMENTS
-------------------------
CREATE TABLE IF NOT EXISTS payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    amount numeric(12,2) NOT NULL,
    currency char(3) DEFAULT 'EUR',
    method text,
    provider_reference text,
    status payment_status NOT NULL DEFAULT 'pending',
    paid_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments(booking_id);

-------------------------
-- TICKETS
-------------------------
CREATE TABLE IF NOT EXISTS tickets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id uuid REFERENCES bookings(id) ON DELETE SET NULL,
    passenger_id uuid REFERENCES passengers(id) ON DELETE SET NULL,
    trip_id uuid NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    fare_id uuid REFERENCES fares(id) ON DELETE SET NULL,
    seat_id uuid REFERENCES seats(id) ON DELETE SET NULL,
    ticket_ref text NOT NULL UNIQUE,
    price numeric(12,2) NOT NULL,
    currency char(3) DEFAULT 'EUR',
    status ticket_status NOT NULL DEFAULT 'issued',
    issued_at timestamptz NOT NULL DEFAULT now(),
    cancelled_at timestamptz,
    checked_in_at timestamptz,
    notes text
);

CREATE INDEX IF NOT EXISTS idx_tickets_booking ON tickets(booking_id);
CREATE INDEX IF NOT EXISTS idx_tickets_trip ON tickets(trip_id);
CREATE INDEX IF NOT EXISTS idx_tickets_passenger ON tickets(passenger_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_trip_seat ON tickets(trip_id, seat_id) WHERE seat_id IS NOT NULL;

-------------------------
-- SEAT RESERVATIONS
-------------------------
CREATE TABLE IF NOT EXISTS seat_reservations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id uuid NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    seat_id uuid NOT NULL REFERENCES seats(id) ON DELETE CASCADE,
    ticket_id uuid REFERENCES tickets(id) ON DELETE SET NULL,
    reserved_by_booking uuid REFERENCES bookings(id) ON DELETE SET NULL,
    reserved_at timestamptz NOT NULL DEFAULT now(),
    reserved_until timestamptz,
    status text NOT NULL DEFAULT 'reserved',
    UNIQUE (trip_id, seat_id)
);

CREATE INDEX IF NOT EXISTS idx_seat_res_trip ON seat_reservations(trip_id);
CREATE INDEX IF NOT EXISTS idx_seat_res_ticket ON seat_reservations(ticket_id);
CREATE INDEX IF NOT EXISTS idx_seatres_by_trip_status ON seat_reservations(trip_id, status);

-------------------------
-- REFUNDS / CANCELLATIONS
-------------------------
CREATE TABLE IF NOT EXISTS ticket_refunds (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id uuid NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    refunded_amount numeric(12,2) NOT NULL,
    currency char(3) DEFAULT 'EUR',
    processed_at timestamptz NOT NULL DEFAULT now(),
    reason text
);

-------------------------
-- AUDIT LOG
-------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id bigserial PRIMARY KEY,
    actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    object_type text NOT NULL,
    object_id text,
    action text NOT NULL,
    payload jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_logs(actor_user_id);

-------------------------
-- POD RECORDS (existing orchestrator feature)
-------------------------
CREATE TABLE IF NOT EXISTS pod_records (
    id bigserial PRIMARY KEY,
    name text NOT NULL,
    namespace text NOT NULL,
    status text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-------------------------
-- SAMPLE UTILITY FUNCTION
-------------------------
CREATE OR REPLACE FUNCTION gen_ref(prefix text, len int DEFAULT 8)
RETURNS text LANGUAGE sql AS $$
  SELECT upper(prefix || '-' || substring(md5(random()::text) from 1 for len));
$$;
