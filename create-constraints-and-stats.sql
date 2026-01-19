DELETE FROM movie_keyword WHERE keyword_id NOT IN (SELECT id FROM keyword);
ALTER TABLE movie_keyword ADD CONSTRAINT movie_keyword_keyword_id_fkey FOREIGN KEY (keyword_id) REFERENCES keyword(id) ON DELETE CASCADE;
-- SET default_statistics_target = 10000;
CREATE STATISTICS keyword_stats ON keyword, id FROM keyword;
-- ANALYZE keyword;
-- ANALYZE movie_keyword;
