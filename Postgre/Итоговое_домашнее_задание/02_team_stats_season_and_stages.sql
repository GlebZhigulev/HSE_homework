-- 02_team_stats_season_and_stages.sql
-- Цель: посчитать статистику команды за сезон в целом и по этапам; для лигового этапа дополнительно показать очки и место.

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
),
team_rows AS (
  SELECT
    m.match_id,
    m.stage_id,
    st.code AS stage_code,
    st.name AS stage_name,
    CASE WHEN m.home_team_id = (SELECT team_id FROM t) THEN m.home_goals ELSE m.away_goals END AS gf,
    CASE WHEN m.home_team_id = (SELECT team_id FROM t) THEN m.away_goals ELSE m.home_goals END AS ga
  FROM ucl.ucl_match m
  JOIN ucl.season_stage st ON st.stage_id = m.stage_id
  WHERE m.season_id = (SELECT season_id FROM s)
    AND ((m.home_team_id = (SELECT team_id FROM t)) OR (m.away_team_id = (SELECT team_id FROM t)))
),
stage_stats AS (
  SELECT
    stage_code,
    stage_name,
    COUNT(*)::int AS played,
    SUM((gf > ga)::int) AS wins,
    SUM((gf = ga)::int) AS draws,
    SUM((gf < ga)::int) AS losses,
    SUM(gf)::int AS goals_for,
    SUM(ga)::int AS goals_against,
    (SUM(gf) - SUM(ga))::int AS goal_diff
  FROM team_rows
  GROUP BY stage_code, stage_name
),
season_total AS (
  SELECT
    'TOTAL'::text AS stage_code,
    'Season total'::text AS stage_name,
    COUNT(*)::int AS played,
    SUM((gf > ga)::int) AS wins,
    SUM((gf = ga)::int) AS draws,
    SUM((gf < ga)::int) AS losses,
    SUM(gf)::int AS goals_for,
    SUM(ga)::int AS goals_against,
    (SUM(gf) - SUM(ga))::int AS goal_diff
  FROM team_rows
),
league_table AS (
  WITH league_stage AS (
    SELECT stage_id
    FROM ucl.season_stage
    WHERE season_id = (SELECT season_id FROM s)
      AND code = 'league'
  ),
  match_rows AS (
    SELECT m.home_team_id AS team_id, m.home_goals AS gf, m.away_goals AS ga
    FROM ucl.ucl_match m
    WHERE m.stage_id = (SELECT stage_id FROM league_stage)
    UNION ALL
    SELECT m.away_team_id AS team_id, m.away_goals AS gf, m.home_goals AS ga
    FROM ucl.ucl_match m
    WHERE m.stage_id = (SELECT stage_id FROM league_stage)
  ),
  agg AS (
    SELECT
      team_id,
      COUNT(*)::int AS played,
      SUM(CASE WHEN gf > ga THEN 1 ELSE 0 END)::int AS wins,
      SUM(CASE WHEN gf = ga THEN 1 ELSE 0 END)::int AS draws,
      SUM(CASE WHEN gf < ga THEN 1 ELSE 0 END)::int AS losses,
      SUM(gf)::int AS goals_for,
      SUM(ga)::int AS goals_against,
      (SUM(gf) - SUM(ga))::int AS goal_diff,
      SUM(CASE WHEN gf > ga THEN 3 WHEN gf = ga THEN 1 ELSE 0 END)::int AS points
    FROM match_rows
    GROUP BY team_id
  )
  SELECT
    ROW_NUMBER() OVER (ORDER BY points DESC, goal_diff DESC, goals_for DESC, team_id)::int AS pos,
    team_id,
    points
  FROM agg
)
SELECT
  ss.stage_code,
  ss.stage_name,
  ss.played, ss.wins, ss.draws, ss.losses,
  ss.goals_for, ss.goals_against, ss.goal_diff,
  CASE
    WHEN ss.stage_code = 'league' THEN lt.points
    ELSE NULL
  END AS league_points,
  CASE
    WHEN ss.stage_code = 'league' THEN lt.pos
    ELSE NULL
  END AS league_pos
FROM (
  SELECT * FROM season_total
  UNION ALL
  SELECT * FROM stage_stats
) ss
LEFT JOIN league_table lt
  ON lt.team_id = (SELECT team_id FROM t) AND ss.stage_code = 'league'
ORDER BY
  CASE
    WHEN ss.stage_code = 'TOTAL' THEN 0
    ELSE 1
  END,
  ss.stage_code;
