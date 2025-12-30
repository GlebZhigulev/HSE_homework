-- 03_stage_matches.sql
-- Цель: вывести все матчи выбранного этапа в выбранном сезоне.

\set season_code '2024/2025'
\set stage_code 'league'

SELECT
  m.match_datetime,
  h.name AS home_team,
  a.name AS away_team,
  (m.home_goals::text || ' - ' || m.away_goals::text) AS score,
  m.venue,
  m.city
FROM ucl.ucl_match m
JOIN ucl.team h ON h.team_id = m.home_team_id
JOIN ucl.team a ON a.team_id = m.away_team_id
WHERE m.season_id = (SELECT season_id FROM ucl.season WHERE code = :'season_code')
  AND m.stage_id = (
    SELECT stage_id
    FROM ucl.season_stage
    WHERE season_id = (SELECT season_id FROM ucl.season WHERE code = :'season_code')
      AND code = :'stage_code'
  )
ORDER BY m.match_datetime, home_team, away_team;
