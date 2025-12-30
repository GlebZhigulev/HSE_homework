-- 05_league_table.sql
-- Цель: вывести таблицу лигового этапа выбранного сезона (позиция, очки, W/D/L, голы).

\set season_code '2024/2025'

SELECT *
FROM ucl.get_league_table(:'season_code');
