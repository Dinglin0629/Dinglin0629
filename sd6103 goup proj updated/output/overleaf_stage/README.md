# SD6103 Data Systems Group Project

This folder contains the final PostgreSQL implementation and the latest verified
LaTeX report for the SD6103 group project.

## Final database

- PostgreSQL 18 database: `sd6103_housing`
- 26 towns
- 9,828 HDB-flat block-address records
- 972,461 resale transactions
- 129 hawker centres
- 42,909 flat--hawker proximity links

The schema uses the data-supported building grain: `hdb_flat(flat_id, ...)`.
There is no invented unit-level HDB-flat entity because the source has no unit
identifier. The M:N `flat_hawker_proximity` relation stores only `distance_m`;
`v_flat_hawker_proximity` derives the proximity band from `proximity_level`.
The official market-stall count is transformed once into the final ERM's
`has_fresh_market` attribute; unmatched values remain NULL rather than false.

The resale data combines all five official periods: 1990--1999,
2000--February 2012, March 2012--2014, 2015--2016, and 2017--present.

## Folder structure

- `data/raw`: downloaded source CSV files.
- `data/processed`: PostgreSQL-ready tables and five cumulative benchmark datasets.
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
psql -U postgres -d sd6103_housing -f sql/01_schema.sql
psql -U postgres -d sd6103_housing -f sql/02_load_data.sql
psql -U postgres -d sd6103_housing -f sql/03_queries.sql
```

Run `sql/05_benchmark.sql` for the controlled experiment: five cumulative dataset
sizes, six queries, five timed repetitions per query, plus the indexed largest-size
run. The final report was compiled with MiKTeX using `pdflatex`, `bibtex`, and two
additional `pdflatex` passes. The Overleaf ZIP includes `aaai-named.bst` and compiles
with pdfLaTeX without relying on local auxiliary files.
