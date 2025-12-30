-- 01_team_matches.sql
-- Цель: вывести все матчи выбранной команды в выбранном сезоне (дата/время, этап, соперник, место, счёт).

\set season_code '2024/2025'
\set team_name 'Real Madrid'

WITH s AS (
  SELECT season_id
  FROM ucl.season
  WHERE code = :'season_code'
),
t AS (
  SELECT team_id
  FROM ucl.team
  WHERE name = :'team_name'
)
SELECT
  m.match_datetime,
  st.code    AS stage_code,
  st.name    AS stage_name,
  CASE
    WHEN m.home_team_id = (SELECT team_id FROM t) THEN 'home'
    ELSE 'away'
  END AS venue_role,
  CASE
    WHEN m.home_team_id = (SELECT team_id FROM t) THEN opp.name
    ELSE home.name
  END AS opponent,
  m.venue,
  m.city,
  (m.home_goals::text || ' - ' || m.away_goals::text) AS score
FROM ucl.ucl_match m
JOIN ucl.season_stage st ON st.stage_id = m.stage_id
JOIN ucl.team home ON home.team_id = m.home_team_id
JOIN ucl.team opp  ON opp.team_id  = m.away_team_id
WHERE m.season_id = (SELECT season_id FROM s)
  AND (
    m.home_team_id = (SELECT team_id FROM t)
    OR m.away_team_id = (SELECT team_id FROM t)
  )
ORDER BY m.match_datetime;
