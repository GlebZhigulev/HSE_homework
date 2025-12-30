-- 04_player_matches_and_events.sql
-- Цель: показать участие игрока в матчах сезона и связанные с ним события (голы/карточки/замены).

\set season_code '2024/2025'
\set player_last_name 'Bellingham'

WITH s AS (
  SELECT season_id
  FROM ucl.season
  WHERE code = :'season_code'
),
p AS (
  SELECT player_id, first_name, last_name
  FROM ucl.player
  WHERE last_name = :'player_last_name'
  ORDER BY player_id
  LIMIT 1
),
pm AS (
  SELECT
    m.match_id,
    m.match_datetime,
    st.code AS stage_code,
    st.name AS stage_name,
    tm.name AS team_in_match,
    pm.minutes_played,
    pm.started
  FROM ucl.player_match pm
  JOIN ucl.ucl_match m ON m.match_id = pm.match_id
  JOIN ucl.season_stage st ON st.stage_id = m.stage_id
  JOIN ucl.team tm ON tm.team_id = pm.team_id
  WHERE pm.player_id = (SELECT player_id FROM p)
    AND m.season_id = (SELECT season_id FROM s)
)
SELECT
  pm.match_datetime,
  pm.stage_code,
  pm.team_in_match,
  pm.minutes_played,
  pm.started,
  ev.minute AS event_minute,
  ev.event_type,
  ev_team.name AS event_team,
  CASE
    WHEN ev.event_type = 'substitution' THEN
      (pout.first_name || ' ' || pout.last_name) || ' -> ' || (pin.first_name || ' ' || pin.last_name)
    ELSE
      (pl.first_name || ' ' || pl.last_name)
  END AS event_detail
FROM pm
LEFT JOIN ucl.match_event ev
  ON ev.match_id = pm.match_id
  AND (ev.player_id = (SELECT player_id FROM p) OR ev.related_player_id = (SELECT player_id FROM p))
LEFT JOIN ucl.team ev_team ON ev_team.team_id = ev.team_id
LEFT JOIN ucl.player pl   ON pl.player_id   = ev.player_id
LEFT JOIN ucl.player pout ON pout.player_id = ev.player_id
LEFT JOIN ucl.player pin  ON pin.player_id  = ev.related_player_id
ORDER BY pm.match_datetime, ev.minute NULLS LAST, ev.event_type;
