SET search_path = housing, public;
TRUNCATE flat_hawker_proximity, resale_transaction, hawker_centre, hdb_flat, town RESTART IDENTITY CASCADE;
DROP TABLE IF EXISTS town_stage, block_stage, transaction_stage, hawker_stage, proximity_stage;

CREATE TEMP TABLE town_stage (town_name varchar(80));
COPY town_stage FROM 'C:/Users/BUDINGLIN/Desktop/SD6103 Data Systems Project/data/processed/town.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO town (town_name) SELECT town_name FROM town_stage ON CONFLICT DO NOTHING;

CREATE TEMP TABLE block_stage (town_name varchar(80), block varchar(16), street_name varchar(120), postal_code char(6), latitude numeric(9,6), longitude numeric(9,6));
COPY block_stage FROM 'C:/Users/BUDINGLIN/OneDrive/Desktop/学业课程/NTU MSC DS 2026 - 2027/2026 Semester 1/SD6103 Data Systems/SD6103 Data Systems Group Project/data/processed/hdb_flat.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO hdb_flat (town_id, block, street_name, postal_code, latitude, longitude)
SELECT t.town_id, s.block, s.street_name, NULLIF(NULLIF(btrim(s.postal_code), ''), 'NIL'), s.latitude, s.longitude FROM block_stage s JOIN town t USING (town_name) ON CONFLICT DO NOTHING;

CREATE TEMP TABLE transaction_stage (block varchar(16), street_name varchar(120), sale_month date, flat_type varchar(20), storey_range varchar(20), floor_area_sqm numeric(7,2), flat_model varchar(60), lease_commence_year smallint, remaining_lease_months integer, resale_price numeric(12,2), source_row_key char(64));
COPY transaction_stage FROM 'C:/Users/BUDINGLIN/OneDrive/Desktop/学业课程/NTU MSC DS 2026 - 2027/2026 Semester 1/SD6103 Data Systems/SD6103 Data Systems Group Project/data/processed/resale_transaction.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO resale_transaction (flat_id, sale_month, flat_type, storey_range, floor_area_sqm, flat_model, lease_commence_year, remaining_lease_months, resale_price, source_row_key)
SELECT f.flat_id, s.sale_month, s.flat_type, s.storey_range, s.floor_area_sqm, s.flat_model, s.lease_commence_year, s.remaining_lease_months, s.resale_price, s.source_row_key FROM transaction_stage s JOIN hdb_flat f USING (block, street_name) ON CONFLICT (source_row_key) DO NOTHING;

CREATE TEMP TABLE hawker_stage (hawker_name varchar(200), address varchar(300), longitude numeric(12,9), latitude numeric(12,9), has_fresh_market boolean);
COPY hawker_stage FROM 'C:/Users/BUDINGLIN/OneDrive/Desktop/学业课程/NTU MSC DS 2026 - 2027/2026 Semester 1/SD6103 Data Systems/SD6103 Data Systems Group Project/data/processed/hawker_centre.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO hawker_centre (hawker_name, address, longitude, latitude, has_fresh_market)
SELECT btrim(hawker_name), NULLIF(btrim(address), ''), longitude, latitude, has_fresh_market FROM hawker_stage ON CONFLICT (hawker_name) DO UPDATE SET address=EXCLUDED.address, longitude=EXCLUDED.longitude, latitude=EXCLUDED.latitude, has_fresh_market=EXCLUDED.has_fresh_market;

CREATE TEMP TABLE proximity_stage (block varchar(16), street_name varchar(120), hawker_name varchar(200), distance_m numeric(9,2));
COPY proximity_stage FROM 'C:/Users/BUDINGLIN/OneDrive/Desktop/学业课程/NTU MSC DS 2026 - 2027/2026 Semester 1/SD6103 Data Systems/SD6103 Data Systems Group Project/data/processed/flat_hawker_proximity.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
INSERT INTO flat_hawker_proximity (flat_id, hawker_id, distance_m)
SELECT f.flat_id, h.hawker_id, s.distance_m FROM proximity_stage s JOIN hdb_flat f USING (block, street_name) JOIN hawker_centre h USING (hawker_name) ON CONFLICT (flat_id, hawker_id) DO UPDATE SET distance_m=EXCLUDED.distance_m;

ANALYZE;
SELECT 'town' AS relation, count(*) AS rows FROM town
UNION ALL SELECT 'hdb_flat', count(*) FROM hdb_flat
UNION ALL SELECT 'resale_transaction', count(*) FROM resale_transaction
UNION ALL SELECT 'hawker_centre', count(*) FROM hawker_centre
UNION ALL SELECT 'flat_hawker_proximity', count(*) FROM flat_hawker_proximity
ORDER BY relation;
