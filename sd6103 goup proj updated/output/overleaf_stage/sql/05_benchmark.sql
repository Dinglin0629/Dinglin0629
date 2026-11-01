SET search_path = housing, public;

DROP INDEX IF EXISTS idx_transaction_type_month;
DROP INDEX IF EXISTS idx_transaction_remaining_lease;
DROP INDEX IF EXISTS idx_proximity_block_distance;
DROP INDEX IF EXISTS idx_hawker_fresh_market;

DROP TABLE IF EXISTS benchmark_results;
CREATE TABLE benchmark_results (
  size_level integer NOT NULL,
  transaction_rows bigint NOT NULL,
  query_no integer NOT NULL,
  repetition integer NOT NULL,
  indexed boolean NOT NULL,
  execution_ms numeric(14,3) NOT NULL
);

CREATE TEMP TABLE benchmark_transaction_stage (
 block varchar(16), street_name varchar(120), sale_month date, flat_type varchar(20),
 storey_range varchar(20), floor_area_sqm numeric(7,2), flat_model varchar(60),
 lease_commence_year smallint, remaining_lease_months integer,
 resale_price numeric(12,2), source_row_key char(64));

CREATE TEMP TABLE benchmark_queries (query_no integer PRIMARY KEY, sql_text text NOT NULL);
INSERT INTO benchmark_queries VALUES
(1, $q$SELECT t.town_name, rt.flat_type, avg(rt.resale_price/rt.floor_area_sqm), count(*)
 FROM resale_transaction rt JOIN hdb_flat f USING(flat_id) JOIN town t USING(town_id)
 WHERE sale_month >= (SELECT max(sale_month)-interval '3 years' FROM resale_transaction)
 GROUP BY t.town_name,rt.flat_type$q$),
(2, $q$SELECT t.town_name, width_bucket(rt.remaining_lease_months,0,1188,3),
 percentile_cont(0.5) WITHIN GROUP(ORDER BY rt.resale_price), avg(rt.resale_price/rt.floor_area_sqm),count(*)
 FROM resale_transaction rt JOIN hdb_flat f USING(flat_id) JOIN town t USING(town_id)
 GROUP BY t.town_name,width_bucket(rt.remaining_lease_months,0,1188,3)$q$),
(3, $q$WITH top_towns AS (SELECT f.town_id FROM resale_transaction rt JOIN hdb_flat f USING(flat_id)
 WHERE rt.flat_type='3 ROOM' GROUP BY f.town_id ORDER BY avg(rt.floor_area_sqm) DESC LIMIT 10)
 SELECT t.town_name,extract(year from rt.sale_month),max(rt.resale_price)
 FROM resale_transaction rt JOIN hdb_flat f USING(flat_id) JOIN town t USING(town_id)
 WHERE f.town_id IN (SELECT town_id FROM top_towns)
 GROUP BY t.town_name,extract(year from rt.sale_month)$q$),
(4, $q$WITH nearest AS (SELECT DISTINCT ON(flat_id) flat_id,proximity_level_id
 FROM v_flat_hawker_proximity ORDER BY flat_id,distance_m)
 SELECT t.town_name,rt.flat_type,avg(rt.resale_price) FILTER(WHERE n.proximity_level_id=1),
 avg(rt.resale_price) FILTER(WHERE n.proximity_level_id=3)
 FROM resale_transaction rt JOIN hdb_flat f USING(flat_id) JOIN town t USING(town_id)
 JOIN nearest n USING(flat_id) GROUP BY t.town_name,rt.flat_type$q$),
(5, $q$SELECT t.town_name,p.level_name,avg(rt.resale_price),count(DISTINCT rt.transaction_id)
 FROM resale_transaction rt JOIN hdb_flat f USING(flat_id) JOIN town t USING(town_id)
 JOIN v_flat_hawker_proximity p USING(flat_id)
 JOIN hawker_centre h USING(hawker_id) WHERE h.has_fresh_market IS TRUE
 GROUP BY t.town_name,p.level_name HAVING avg(rt.resale_price)>200000$q$),
(6, $q$SELECT t.town_name,p.level_name,h.has_fresh_market,count(DISTINCT f.flat_id),
 count(DISTINCT rt.transaction_id),avg(rt.resale_price)
 FROM town t JOIN hdb_flat f USING(town_id) JOIN resale_transaction rt USING(flat_id)
 JOIN flat_hawker_proximity fp USING(flat_id) JOIN proximity_level p
 ON fp.distance_m>=p.min_distance_m AND (fp.distance_m<p.max_distance_m
 OR (p.upper_inclusive AND fp.distance_m<=p.max_distance_m))
 JOIN hawker_centre h USING(hawker_id)
 GROUP BY t.town_name,p.level_name,h.has_fresh_market$q$);

CREATE OR REPLACE PROCEDURE run_six_queries(p_size integer, p_indexed boolean)
LANGUAGE plpgsql AS $$
DECLARE r record; i integer; started timestamptz; ignored bigint; n bigint;
BEGIN
  SELECT count(*) INTO n FROM resale_transaction;
  FOR r IN SELECT * FROM benchmark_queries ORDER BY query_no LOOP
    EXECUTE 'SELECT count(*) FROM (' || r.sql_text || ') result' INTO ignored; -- warm-up
    FOR i IN 1..5 LOOP
      started := clock_timestamp();
      EXECUTE 'SELECT count(*) FROM (' || r.sql_text || ') result' INTO ignored;
      INSERT INTO benchmark_results VALUES
        (p_size,n,r.query_no,i,p_indexed,extract(epoch FROM clock_timestamp()-started)*1000);
    END LOOP;
  END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE load_benchmark_size(p_size integer)
LANGUAGE plpgsql AS $$
DECLARE file_path text;
BEGIN
  file_path := U&'C:/Users/BUDINGLIN/OneDrive/Desktop/\5B66\4E1A\8BFE\7A0B/NTU MSC DS 2026 - 2027/2026 Semester 1/SD6103 Data Systems/SD6103 Data Systems Group Project/data/processed/resale_transaction_size'
               || p_size || '.csv';
  TRUNCATE resale_transaction, benchmark_transaction_stage RESTART IDENTITY;
  EXECUTE format('COPY benchmark_transaction_stage FROM %L WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')',file_path);
  INSERT INTO resale_transaction
   (flat_id,sale_month,flat_type,storey_range,floor_area_sqm,flat_model,lease_commence_year,remaining_lease_months,resale_price,source_row_key)
  SELECT f.flat_id,s.sale_month,s.flat_type,s.storey_range,s.floor_area_sqm,s.flat_model,s.lease_commence_year,
         s.remaining_lease_months,s.resale_price,s.source_row_key
  FROM benchmark_transaction_stage s JOIN hdb_flat f USING(block,street_name);
  ANALYZE resale_transaction;
  CALL run_six_queries(p_size,false);
END $$;

CALL load_benchmark_size(1);
CALL load_benchmark_size(2);
CALL load_benchmark_size(3);
CALL load_benchmark_size(4);
CALL load_benchmark_size(5);

CREATE INDEX idx_transaction_type_month ON resale_transaction(flat_type,sale_month)
 INCLUDE(flat_id,floor_area_sqm,resale_price);
CREATE INDEX idx_transaction_remaining_lease ON resale_transaction(remaining_lease_months)
 INCLUDE(flat_id,resale_price,floor_area_sqm);
CREATE INDEX idx_proximity_block_distance ON flat_hawker_proximity(flat_id,distance_m)
 INCLUDE(hawker_id);
CREATE INDEX idx_hawker_fresh_market ON hawker_centre(hawker_id) WHERE has_fresh_market IS TRUE;
ANALYZE;
CALL run_six_queries(5,true);

COPY (
 SELECT size_level,transaction_rows,query_no,indexed,
        round(avg(execution_ms),3) AS mean_ms,
        round(percentile_cont(0.5) WITHIN GROUP(ORDER BY execution_ms)::numeric,3) AS median_ms,
        round(stddev_samp(execution_ms),3) AS sd_ms
 FROM benchmark_results GROUP BY size_level,transaction_rows,query_no,indexed
 ORDER BY indexed,size_level,query_no
) TO 'C:/Users/BUDINGLIN/Desktop/SD6103 Data Systems Project/report/generated/benchmark_summary.csv'
WITH (FORMAT csv,HEADER true);

SELECT indexed,count(*) AS observations,min(execution_ms),round(avg(execution_ms),3),max(execution_ms)
FROM benchmark_results GROUP BY indexed ORDER BY indexed;
