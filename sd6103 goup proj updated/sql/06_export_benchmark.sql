SET search_path = housing, public;
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
