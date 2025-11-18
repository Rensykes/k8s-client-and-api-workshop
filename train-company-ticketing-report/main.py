from __future__ import annotations

import argparse
import sys
from datetime import date
from pathlib import Path

from train_company_ticketing_report.config import DatabaseSettings
from train_company_ticketing_report.report_service import fetch_ticket_report


def parse_iso_date(value: str, arg_name: str) -> date:
    try:
        return date.fromisoformat(value)
    except ValueError as exc:  # pragma: no cover - argparse exit path
        raise SystemExit(f"Invalid {arg_name}: {value!r}. Expected ISO format YYYY-MM-DD") from exc


def default_start_date() -> date:
    today = date.today()
    return today.replace(day=1)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate the train ticketing Excel report.")
    parser.add_argument("--start-date", help="Inclusive start date (YYYY-MM-DD)")
    parser.add_argument("--end-date", help="Inclusive end date (YYYY-MM-DD)")
    parser.add_argument("--output", default="ticketing-report.xlsx", help="Path to the Excel file to write")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    start_date = parse_iso_date(args.start_date, "--start-date") if args.start_date else default_start_date()
    end_date = parse_iso_date(args.end_date, "--end-date") if args.end_date else date.today()

    settings = DatabaseSettings.from_env()
    report = fetch_ticket_report(settings=settings, start_date=start_date, end_date=end_date)

    output_path = Path(args.output)
    report.to_excel(output_path)

    print(f"Exported {len(report.dataframe)} rows to {output_path.resolve()}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
