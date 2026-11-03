# SD6103 Data Systems Group Project

This folder contains the final PostgreSQL implementation and the latest verified
LaTeX report for the SD6103 group project.

## Final database

- PostgreSQL 18 database: `sd6103_housing`
- 26 towns
- 9,385 HDB-flat block-address records
- 78,670 resale transactions (1 January 2023--31 December 2025)
- 129 hawker centres
- 40,354 flat--hawker proximity links

The schema uses the data-supported building grain: `hdb_flat(flat_id, ...)`.
There is no invented unit-level HDB-flat entity because the source has no unit
identifier. The M:N `nearby` relation stores only `distance_m`;
`nearby_classified` derives the proximity band from `proximity_level`.
PostgreSQL generates `has_fresh_market` from the official market-stall count;
unmatched values remain NULL rather than false.

All Task 1--3 relations and queries follow the supplied GitHub model. The analytical
scope is fixed to 1 January 2023 through 31 December 2025; Q1 uses the same dates.

## Folder structure

- `data/raw`: downloaded source CSV files.
- `data/processed`: PostgreSQL-ready tables and five cumulative 2023--2025 benchmark datasets.
- `scripts`: reproducible download, transformation, and plotting scripts.
- `sql`: database creation, schema, loading, six queries, indexes, and benchmark SQL.
- `report`: latest LaTeX source, AAAI bibliography style, references, result CSVs,
  and report figures.
- `output/pdf/SD6103_Project_Report.pdf`: final locally verified PDF.
- `output/SD6103_Overleaf_Project.zip`: clean Overleaf-ready submission package.

## Reproduction

```powershell
powershell -File scripts/download_data.ps1
python scripts/prepare_data.py
psql -U postgres -f sql/00_create_database.sql
psql -U postgres -d sd6103_housing -f sql/02_load_data.sql
psql -U postgres -d sd6103_housing -f sql/03_queries.sql
```

Run `scripts/run_native.py` for the controlled experiment: five cumulative dataset
sizes, six queries, five timed repetitions per query, plus the indexed largest-size
run. The final report was compiled with MiKTeX using `pdflatex`, `bibtex`, and two
additional `pdflatex` passes. The Overleaf ZIP includes `aaai-named.bst` and compiles
with pdfLaTeX without relying on local auxiliary files.
