SET search_path = housing, public; -- Apply the measured four-index bundle.

CREATE INDEX idx_rt_type_month
ON resale_transaction (flat_type, sale_month)
INCLUDE (flat_id, floor_area_sqm, resale_price); -- Cover Q1 and both Q3 scans.

CREATE INDEX idx_rt_flat
ON resale_transaction (flat_id)
INCLUDE (transaction_id, resale_price); -- Support flat-led transaction lookups in Q4-Q6.

CREATE INDEX idx_nearby_flat_dist
ON nearby (flat_id, distance_m, hawker_id); -- Supply Q4's nearest-centre order.

CREATE INDEX idx_nearby_hawker
ON nearby (hawker_id)
INCLUDE (flat_id, distance_m); -- Cooperate with idx_rt_flat to remove Q6's spilling sort.

VACUUM (ANALYZE) resale_transaction; -- Equalise visibility and refresh planner statistics.
VACUUM (ANALYZE) nearby; -- Refresh statistics for both proximity access paths.

-- Deliberately omitted: an index on remaining_lease_months. Q2 classifies every
-- transaction with CASE and therefore cannot use that index to eliminate rows.
