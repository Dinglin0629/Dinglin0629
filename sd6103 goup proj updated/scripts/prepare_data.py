"""Audit the GitHub-model CSV package before PostgreSQL loading."""
from __future__ import annotations
import csv, json
from datetime import date
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "data" / "processed"
START, END = date(2023, 1, 1), date(2026, 1, 1)
EXPECTED = {
    "town.csv": ["town_id", "town_name"],
    "hdb_flat.csv": ["flat_id", "town_id", "block", "street_name", "postal_code", "latitude", "longitude"],
    "resale_transaction.csv": ["transaction_id", "flat_id", "sale_month", "flat_type", "storey_range", "floor_area_sqm", "flat_model", "lease_commence_year", "remaining_lease_months", "resale_price", "source_row_key"],
    "hawker_centre.csv": ["hawker_id", "hawker_name", "address", "latitude", "longitude", "market_stall_count"],
    "nearby.csv": ["flat_id", "hawker_id", "distance_m"],
    "proximity_level.csv": ["proximity_level_id", "level_name", "min_distance_m", "max_distance_m", "upper_inclusive"],
}

def load(name: str) -> list[dict[str, str]]:
    with (DATA / name).open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != EXPECTED[name]:
            raise ValueError(f"{name}: unexpected columns {reader.fieldnames}")
        return list(reader)

def require_unique(records: list[dict[str, str]], keys: tuple[str, ...], label: str) -> None:
    values = [tuple(row[key] for key in keys) for row in records]
    if len(values) != len(set(values)):
        raise ValueError(f"{label}: duplicate key {keys}")

def main() -> None:
    manifest = json.loads((DATA / "data_manifest.json").read_text(encoding="utf-8"))
    if (manifest["start_inclusive"], manifest["end_exclusive"]) != (START.isoformat(), END.isoformat()):
        raise ValueError("Manifest must cover 2023-01-01 through 2025-12-31")
    tables = {name: load(name) for name in EXPECTED}
    require_unique(tables["town.csv"], ("town_id",), "town")
    require_unique(tables["hdb_flat.csv"], ("flat_id",), "hdb_flat")
    require_unique(tables["resale_transaction.csv"], ("transaction_id",), "resale_transaction")
    require_unique(tables["resale_transaction.csv"], ("source_row_key",), "resale_transaction")
    require_unique(tables["hawker_centre.csv"], ("hawker_id",), "hawker_centre")
    require_unique(tables["nearby.csv"], ("flat_id", "hawker_id"), "nearby")
    flat_ids = {row["flat_id"] for row in tables["hdb_flat.csv"]}
    hawker_ids = {row["hawker_id"] for row in tables["hawker_centre.csv"]}
    for row in tables["resale_transaction.csv"]:
        month = date.fromisoformat(row["sale_month"])
        if not START <= month < END or row["flat_id"] not in flat_ids:
            raise ValueError(f"Out-of-scope/orphan transaction {row['transaction_id']}")
    for row in tables["nearby.csv"]:
        if row["flat_id"] not in flat_ids or row["hawker_id"] not in hawker_ids:
            raise ValueError(f"Orphan nearby pair {(row['flat_id'], row['hawker_id'])}")
    actual = {"town": len(tables["town.csv"]), "hdb_flat": len(tables["hdb_flat.csv"]),
              "resale_transaction": len(tables["resale_transaction.csv"]),
              "hawker_centre": len(tables["hawker_centre.csv"]), "nearby": len(tables["nearby.csv"]),
              "proximity_level": len(tables["proximity_level.csv"])}
    if actual != manifest["table_rows"]:
        raise ValueError(f"Row counts differ: {actual} != {manifest['table_rows']}")
    print("PASS", actual, "scope 2023-01-01 through 2025-12-31")

if __name__ == "__main__":
    main()
