-- SET default_statistics_target = 10000;
CREATE STATISTICS movie_keyword_keyword_stats (mcv)
ON k.keyword
FROM movie_keyword mk JOIN keyword k ON (mk.keyword_id = k.id);
-- ANALYZE keyword;
-- ANALYZE movie_keyword;
