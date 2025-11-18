from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Iterable

import pandas as pd
import psycopg

from .config import DatabaseSettings

REPORT_SQL = """
WITH payment_summary AS (
    SELECT booking_id,
           SUM(amount) AS paid_amount,
           MAX(status) AS latest_payment_status
    FROM payments
    GROUP BY booking_id
)
SELECT
    t.ticket_ref,
    t.status AS ticket_status,
    t.price AS ticket_price,
    t.currency AS ticket_currency,
    t.issued_at,
    b.booking_ref,
    b.status AS booking_status,
    b.total_amount AS booking_total_amount,
    b.currency AS booking_currency,
    pay.paid_amount,
    pay.latest_payment_status,
    p.first_name AS passenger_first_name,
    p.last_name AS passenger_last_name,
    p.doc_type::text AS passenger_doc_type,
    trip.service_date,
    trip.departure_time,
    trip.arrival_time,
    dep.code AS departure_station_code,
    arr.code AS arrival_station_code,
    route.code AS route_code,
    fare.code AS fare_code,
    fare.seat_class::text AS fare_seat_class,
    seat.seat_number,
    carriage.carriage_number,
    train.registration AS train_registration
FROM tickets t
JOIN trips trip ON trip.id = t.trip_id
JOIN routes route ON route.id = trip.route_id
JOIN stations dep ON dep.id = trip.departure_station_id
JOIN stations arr ON arr.id = trip.arrival_station_id
LEFT JOIN bookings b ON b.id = t.booking_id
LEFT JOIN passengers p ON p.id = t.passenger_id
LEFT JOIN fares fare ON fare.id = t.fare_id
LEFT JOIN seats seat ON seat.id = t.seat_id
LEFT JOIN carriages carriage ON carriage.id = seat.carriage_id
LEFT JOIN trains train ON train.id = trip.train_id
LEFT JOIN payment_summary pay ON pay.booking_id = b.id
WHERE t.issued_at::date BETWEEN %(start_date)s AND %(end_date)s
ORDER BY trip.service_date, trip.departure_time, t.ticket_ref
"""


@dataclass
class TicketingReport:
    dataframe: pd.DataFrame

    def to_excel(self, path: Path | str) -> Path:
        target = Path(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        
        # Convert timezone-aware datetime columns to timezone-naive for Excel compatibility
        df = self.dataframe.copy()
        for col in df.select_dtypes(include=['datetimetz']).columns:
            df[col] = df[col].dt.tz_localize(None)
        
        with pd.ExcelWriter(target, engine="openpyxl") as writer:
            df.to_excel(writer, sheet_name="TicketingReport", index=False)
        return target


def fetch_ticket_report(
    settings: DatabaseSettings,
    start_date: date,
    end_date: date,
) -> TicketingReport:
    """Execute the report query and return a pandas dataframe wrapper."""

    if start_date > end_date:
        raise ValueError("start_date cannot be after end_date")

    with psycopg.connect(**settings.connection_kwargs()) as conn:
        with conn.cursor() as cur:
            cur.execute(REPORT_SQL, {"start_date": start_date, "end_date": end_date})
            rows: Iterable[tuple] = cur.fetchall()
            columns = [desc[0] for desc in cur.description]

    dataframe = pd.DataFrame(rows, columns=columns)
    return TicketingReport(dataframe=dataframe)
