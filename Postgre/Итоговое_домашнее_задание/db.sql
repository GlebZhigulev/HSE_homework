\set ON_ERROR_STOP on

DROP DATABASE IF EXISTS ucl_db;
CREATE DATABASE ucl_db;

\connect ucl_db

-- Создаём отдельную схему ucl

CREATE SCHEMA IF NOT EXISTS ucl;
SET search_path = ucl;

/* ============================================================
   (2) Таблицы
   ============================================================ */
BEGIN;

-- ------------------------------------------------------------
-- Таблица season (Сезон турнира)
-- Хранит один сезон ЛЧ: например, 2024/2025.
-- code — человекочитаемое обозначение сезона, уникально.
-- date_start/date_end — рамки сезона; CHECK гарантирует корректный порядок дат.
-- ------------------------------------------------------------
CREATE TABLE season (
  season_id   bigserial PRIMARY KEY,
  code        varchar(9) NOT NULL UNIQUE,
  date_start  date NOT NULL,
  date_end    date NOT NULL,
  CONSTRAINT season_dates_ck CHECK (date_start < date_end)
);

-- ------------------------------------------------------------
-- Таблица team (Команда/клуб)
-- Справочник клубов: уникальное название, страна, (опционально) город и стадион.
-- ------------------------------------------------------------
CREATE TABLE team (
  team_id       bigserial PRIMARY KEY,
  name          varchar(120) NOT NULL UNIQUE,
  country       varchar(80)  NOT NULL,
  city          varchar(80),
  home_stadium  varchar(120)
);

-- ------------------------------------------------------------
-- Таблица season_stage (Этап сезона)
-- Описывает структуру турнира внутри конкретного сезона:
--   league, playoffs, r16, qf, sf, final и т.д.
-- stage привязан к season_id (FK), в одном сезоне:
--   - code уникален (season_id, code),
--   - порядок order_no уникален (season_id, order_no),
--   - order_no > 0 позволяет упорядочивать этапы.
-- ------------------------------------------------------------
CREATE TABLE season_stage (
  stage_id   bigserial PRIMARY KEY,
  season_id  bigint NOT NULL REFERENCES season(season_id) ON DELETE CASCADE,
  code       varchar(20) NOT NULL,  
  name       varchar(50) NOT NULL,
  order_no   int NOT NULL,
  CONSTRAINT season_stage_code_uq UNIQUE (season_id, code),
  CONSTRAINT season_stage_order_uq UNIQUE (season_id, order_no),
  CONSTRAINT season_stage_order_ck CHECK (order_no > 0)
);

-- ------------------------------------------------------------
-- Таблица team_season (Участие команды в сезоне)
-- Связующая таблица "команда ↔ сезон" (M:N).
-- tournament_outcome — итог выступления команды в данном сезоне:
-- например winner, eliminated_qf и т.п. (в учебной версии хранится как текст).
-- ------------------------------------------------------------
CREATE TABLE team_season (
  team_id   bigint NOT NULL REFERENCES team(team_id) ON DELETE CASCADE,
  season_id bigint NOT NULL REFERENCES season(season_id) ON DELETE CASCADE,
  tournament_outcome varchar(30) NOT NULL,
  PRIMARY KEY (team_id, season_id)
);

-- ------------------------------------------------------------
-- Таблица player (Игрок)
-- Справочник футболистов.
-- position — позиция игрока в компактной форме (GK/DF/MF/FW).
-- CHECK ограничивает допустимые значения позиции.
-- ------------------------------------------------------------
CREATE TABLE player (
  player_id    bigserial PRIMARY KEY,
  first_name   varchar(60) NOT NULL,
  last_name    varchar(60) NOT NULL,
  birth_date   date,
  nationality  varchar(80),
  position     varchar(20) NOT NULL,
  CONSTRAINT player_position_ck CHECK (position IN ('GK','DF','MF','FW'))
);

-- ------------------------------------------------------------
-- Таблица player_team_contract (Принадлежность игрока клубу во времени)
-- Моделирует трансферы/аренды: один игрок может быть в разных командах в разные периоды.
-- start_date/end_date задают временной интервал (end_date может быть NULL).
-- contract_type: transfer или loan.
-- Индексы по (player_id, start_date) и (team_id, start_date) ускоряют поиск контрактов по времени.
-- ------------------------------------------------------------
CREATE TABLE player_team_contract (
  contract_id   bigserial PRIMARY KEY,
  player_id     bigint NOT NULL REFERENCES player(player_id) ON DELETE CASCADE,
  team_id       bigint NOT NULL REFERENCES team(team_id) ON DELETE CASCADE,
  start_date    date NOT NULL,
  end_date      date,
  contract_type varchar(20) NOT NULL DEFAULT 'transfer',
  CONSTRAINT contract_dates_ck CHECK (end_date IS NULL OR start_date <= end_date),
  CONSTRAINT contract_type_ck CHECK (contract_type IN ('transfer','loan'))
);

CREATE INDEX player_team_contract_player_idx ON player_team_contract(player_id, start_date);
CREATE INDEX player_team_contract_team_idx   ON player_team_contract(team_id, start_date);

-- ------------------------------------------------------------
-- Таблица ucl_match (Матч)
-- Центральная сущность: матч между двумя командами в конкретном сезоне и на конкретном этапе.
-- season_id и stage_id задают контекст сезона/этапа.
-- home_team_id/away_team_id — роли команд (дом/гости).
-- home_goals/away_goals — итоговый счёт.
-- Ограничения:
--   - команды в матче не должны совпадать (match_teams_ck),
--   - голы не могут быть отрицательными (match_goals_ck).
-- Индексы:
--   - по сезону/времени и этапу/времени для выборок календаря,
--   - по командам/времени для выборок матчей команды.
-- ------------------------------------------------------------
CREATE TABLE ucl_match (
  match_id        bigserial PRIMARY KEY,
  season_id       bigint NOT NULL REFERENCES season(season_id) ON DELETE CASCADE,
  stage_id        bigint NOT NULL REFERENCES season_stage(stage_id) ON DELETE RESTRICT,
  match_datetime  timestamp NOT NULL,

  home_team_id    bigint NOT NULL REFERENCES team(team_id) ON DELETE RESTRICT,
  away_team_id    bigint NOT NULL REFERENCES team(team_id) ON DELETE RESTRICT,

  venue           varchar(120),
  city            varchar(80),

  home_goals      int NOT NULL DEFAULT 0,
  away_goals      int NOT NULL DEFAULT 0,

  CONSTRAINT match_teams_ck CHECK (home_team_id <> away_team_id),
  CONSTRAINT match_goals_ck CHECK (home_goals >= 0 AND away_goals >= 0)
);

CREATE INDEX ucl_match_season_dt_idx ON ucl_match(season_id, match_datetime);
CREATE INDEX ucl_match_stage_dt_idx  ON ucl_match(stage_id, match_datetime);
CREATE INDEX ucl_match_home_dt_idx   ON ucl_match(home_team_id, match_datetime);
CREATE INDEX ucl_match_away_dt_idx   ON ucl_match(away_team_id, match_datetime);

-- ------------------------------------------------------------
-- Таблица player_match (Участие игрока в матче)
-- Связь "игрок ↔ матч" с атрибутами:
--   team_id — за какую команду игрок выступал в данном матче (важно при трансферах),
--   minutes_played — сколько минут сыграл,
--   started — был ли в стартовом составе.
-- Ограничения:
--   - (match_id, player_id) уникальны: один игрок не может быть внесён дважды в тот же матч,
--   - minutes_played в разумных границах (0..130).
CREATE TABLE player_match (
  player_match_id bigserial PRIMARY KEY,
  match_id        bigint NOT NULL REFERENCES ucl_match(match_id) ON DELETE CASCADE,
  player_id       bigint NOT NULL REFERENCES player(player_id) ON DELETE CASCADE,
  team_id         bigint NOT NULL REFERENCES team(team_id) ON DELETE RESTRICT,
  minutes_played  int NOT NULL DEFAULT 0,
  started         boolean NOT NULL DEFAULT false,
  CONSTRAINT player_match_unique UNIQUE (match_id, player_id),
  CONSTRAINT player_match_minutes_ck CHECK (minutes_played BETWEEN 0 AND 130)
);

CREATE INDEX player_match_team_match_idx ON player_match(team_id, match_id);

- ------------------------------------------------------------
-- Таблица match_event (Событие матча)
-- Фиксирует события матча: голы, карточки, замены и т.д.
-- Поля:
--   - event_type — тип события (ограничен CHECK),
--   - minute — минута события (0..130),
--   - player_id — основной участник события (может быть NULL),
--   - related_player_id — используется для замен (player_out -> player_in).
-- Ограничение match_event_players_ck:
--   related_player_id допускается только для event_type='substitution'.
-- Индексы ускоряют:
--   - хронологический вывод событий матча,
--   - поиск событий по типу в матче,
--   - поиск событий игрока в матче.
-- ------------------------------------------------------------
CREATE TABLE match_event (
  event_id           bigserial PRIMARY KEY,
  match_id           bigint NOT NULL REFERENCES ucl_match(match_id) ON DELETE CASCADE,
  team_id            bigint NOT NULL REFERENCES team(team_id) ON DELETE RESTRICT,
  event_type         varchar(20) NOT NULL,
  minute             int NOT NULL,
  player_id          bigint REFERENCES player(player_id) ON DELETE SET NULL,
  related_player_id  bigint REFERENCES player(player_id) ON DELETE SET NULL,

  CONSTRAINT match_event_type_ck CHECK (event_type IN ('goal','yellow','red','substitution','own_goal','penalty_goal')),
  CONSTRAINT match_event_minute_ck CHECK (minute BETWEEN 0 AND 130),


  CONSTRAINT match_event_players_ck CHECK (
    NOT (event_type <> 'substitution' AND related_player_id IS NOT NULL)
  )
);

CREATE INDEX match_event_match_min_idx   ON match_event(match_id, minute);
CREATE INDEX match_event_match_type_idx  ON match_event(match_id, event_type);
CREATE INDEX match_event_player_match_idx ON match_event(player_id, match_id);

COMMIT;

/* ============================================================
   (3) Триггеры
   ============================================================ */

-- ------------------------------------------------------------
-- Триггер #1: согласованность season_id матча и season_id этапа
-- Правило: этап (season_stage.stage_id) принадлежит строго одному сезону,
-- поэтому матч не может ссылаться на этап "чужого" сезона.
-- Срабатывает: BEFORE INSERT/UPDATE на ucl_match (изменение season_id или stage_id).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_match_stage_season_consistency()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_stage_season_id bigint;
BEGIN
  -- Определяем сезон, которому принадлежит выбранный этап
  SELECT season_id INTO v_stage_season_id
  FROM ucl.season_stage
  WHERE stage_id = NEW.stage_id;

  IF v_stage_season_id IS NULL THEN
    RAISE EXCEPTION 'Stage % not found', NEW.stage_id;
  END IF;
  -- Проверяем совпадение сезонов: этап и матч должны быть в одном сезоне
  IF v_stage_season_id <> NEW.season_id THEN
    RAISE EXCEPTION 'Stage % belongs to season %, but match refers to season %',
      NEW.stage_id, v_stage_season_id, NEW.season_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS match_stage_season_ck ON ucl_match;
CREATE TRIGGER match_stage_season_ck
BEFORE INSERT OR UPDATE OF season_id, stage_id ON ucl_match
FOR EACH ROW
EXECUTE FUNCTION trg_match_stage_season_consistency();


-- ------------------------------------------------------------
-- Триггер #2: корректность team_id и player_id для события матча
-- Правила:
--   1) team_id события должен быть одной из команд-участников матча (home/away).
--   2) если указан player_id, этот игрок должен быть зарегистрирован как участник матча (player_match).
--   3) для substitution related_player_id также должен быть зарегистрирован в player_match.
-- Срабатывает: BEFORE INSERT/UPDATE на match_event.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_event_team_and_player_consistency()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_home bigint;
  v_away bigint;
  v_exists boolean;
BEGIN
  -- Берём команды-участники матча
  SELECT home_team_id, away_team_id INTO v_home, v_away
  FROM ucl.ucl_match
  WHERE match_id = NEW.match_id;

  IF v_home IS NULL THEN
    RAISE EXCEPTION 'Match % not found', NEW.match_id;
  END IF;
  -- Проверяем, что team_id события относится к одному из участников матча
  IF NEW.team_id <> v_home AND NEW.team_id <> v_away THEN
    RAISE EXCEPTION 'Event team_id % is not a participant of match % (home %, away %)',
      NEW.team_id, NEW.match_id, v_home, v_away;
  END IF;
  -- Проверяем, что игрок (если указан) присутствует в player_match для данного матча
  IF NEW.player_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM ucl.player_match pm
      WHERE pm.match_id = NEW.match_id
        AND pm.player_id = NEW.player_id
    ) INTO v_exists;

    IF NOT v_exists THEN
      RAISE EXCEPTION 'Player % is not registered in player_match for match %',
        NEW.player_id, NEW.match_id;
    END IF;
  END IF;
  -- Для замены проверяем, что related_player_id также зарегистрирован в матче
  IF NEW.event_type = 'substitution' AND NEW.related_player_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM ucl.player_match pm
      WHERE pm.match_id = NEW.match_id
        AND pm.player_id = NEW.related_player_id
    ) INTO v_exists;

    IF NOT v_exists THEN
      RAISE EXCEPTION 'Related player % is not registered in player_match for match %',
        NEW.related_player_id, NEW.match_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS event_team_player_ck ON match_event;
CREATE TRIGGER event_team_player_ck
BEFORE INSERT OR UPDATE OF match_id, team_id, player_id, related_player_id ON match_event
FOR EACH ROW
EXECUTE FUNCTION trg_event_team_and_player_consistency();


/* ============================================================
   (4) Функции
   ============================================================ */

-- ------------------------------------------------------------
-- Функция #1: get_league_table(season_code)
-- Назначение: вычислить турнирную таблицу лигового этапа по результатам матчей.
-- Логика:
--   1) определить season_id по коду сезона;
--   2) найти stage_id для этапа code='league';
--   3) преобразовать каждый матч в две строки "со стороны команды";
--   4) агрегировать W/D/L, голы и очки;
--   5) ранжировать команды оконной функцией ROW_NUMBER().
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION ucl.get_league_table(p_season_code varchar)
RETURNS TABLE (
  pos int,
  team_name varchar,
  played int,
  wins int,
  draws int,
  losses int,
  goals_for int,
  goals_against int,
  goal_diff int,
  points int
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH s AS (
    SELECT season_id
    FROM ucl.season
    WHERE code = p_season_code
  ),
  league_stage AS (
    SELECT stage_id
    FROM ucl.season_stage
    WHERE season_id = (SELECT season_id FROM s)
      AND code = 'league'
  ),
  match_rows AS (
    SELECT
      m.match_id,
      m.home_team_id AS team_id,
      m.home_goals   AS gf,
      m.away_goals   AS ga
    FROM ucl.ucl_match m
    WHERE m.stage_id = (SELECT stage_id FROM league_stage)

    UNION ALL

    SELECT
      m.match_id,
      m.away_team_id AS team_id,
      m.away_goals   AS gf,
      m.home_goals   AS ga
    FROM ucl.ucl_match m
    WHERE m.stage_id = (SELECT stage_id FROM league_stage)
  ),
  agg AS (
    SELECT
      mr.team_id,
      COUNT(*)::int AS played,
      SUM(CASE WHEN mr.gf > mr.ga THEN 1 ELSE 0 END)::int AS wins,
      SUM(CASE WHEN mr.gf = mr.ga THEN 1 ELSE 0 END)::int AS draws,
      SUM(CASE WHEN mr.gf < mr.ga THEN 1 ELSE 0 END)::int AS losses,
      COALESCE(SUM(mr.gf), 0)::int AS goals_for,
      COALESCE(SUM(mr.ga), 0)::int AS goals_against,
      (COALESCE(SUM(mr.gf), 0) - COALESCE(SUM(mr.ga), 0))::int AS goal_diff,
      COALESCE(SUM(
        CASE
          WHEN mr.gf > mr.ga THEN 3
          WHEN mr.gf = mr.ga THEN 1
          ELSE 0
        END
      ), 0)::int AS points
    FROM match_rows mr
    GROUP BY mr.team_id
  )
  SELECT
    ROW_NUMBER() OVER (ORDER BY a.points DESC, a.goal_diff DESC, a.goals_for DESC, t.name)::int AS pos,
    t.name AS team_name,
    a.played, a.wins, a.draws, a.losses, a.goals_for, a.goals_against, a.goal_diff, a.points
  FROM agg a
  JOIN ucl.team t ON t.team_id = a.team_id
  ORDER BY pos;
END;
$$;



-- ------------------------------------------------------------
-- Функция #2: get_player_season_summary(season_code, last_name)
-- Назначение: агрегировать статистику игрока за сезон:
--   матчи, минуты, голы, карточки (по событиям match_event).
-- Логика:
--   1) найти season_id и player_id;
--   2) выбрать участия игрока в матчах сезона (player_match + ucl_match);
--   3) выбрать события игрока в матчах сезона (match_event + ucl_match);
--   4) посчитать агрегаты.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_player_season_summary(p_season_code varchar, p_last_name varchar)
RETURNS TABLE (
  player_name text,
  matches_played int,
  total_minutes int,
  goals int,
  yellow_cards int,
  red_cards int
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH s AS (
    SELECT season_id FROM ucl.season WHERE code = p_season_code
  ),
  pl AS (
    SELECT player_id, first_name, last_name
    FROM ucl.player
    WHERE last_name = p_last_name
    ORDER BY player_id
    LIMIT 1
  ),
  pm AS (
    SELECT pm.*
    FROM ucl.player_match pm
    JOIN ucl.ucl_match m ON m.match_id = pm.match_id
    WHERE pm.player_id = (SELECT player_id FROM pl)
      AND m.season_id = (SELECT season_id FROM s)
  ),
  ev AS (
    SELECT me.event_type
    FROM ucl.match_event me
    JOIN ucl.ucl_match m ON m.match_id = me.match_id
    WHERE me.player_id = (SELECT player_id FROM pl)
      AND m.season_id = (SELECT season_id FROM s)
  )
  SELECT
    (SELECT first_name || ' ' || last_name FROM pl) AS player_name,
    (SELECT COUNT(*) FROM pm)::int AS matches_played,
    (SELECT COALESCE(SUM(minutes_played), 0) FROM pm)::int AS total_minutes,
    (SELECT COUNT(*) FROM ev WHERE event_type IN ('goal','penalty_goal'))::int AS goals,
    (SELECT COUNT(*) FROM ev WHERE event_type = 'yellow')::int AS yellow_cards,
    (SELECT COUNT(*) FROM ev WHERE event_type = 'red')::int AS red_cards;
END;
$$;


/* ============================================================
   (5) Заполнение данными
   ============================================================ */

BEGIN;

SET search_path = ucl;

-- Сезоны
INSERT INTO season (code, date_start, date_end)
VALUES ('2024/2025', '2024-07-01', '2025-06-30');

-- Команды
INSERT INTO team (name, country, city, home_stadium) VALUES
('Real Madrid',         'Spain',   'Madrid',      'Santiago Bernabéu'),
('Manchester City',     'England', 'Manchester',  'Etihad Stadium'),
('Bayern Munich',       'Germany', 'Munich',      'Allianz Arena'),
('Paris Saint-Germain', 'France',  'Paris',       'Parc des Princes');

-- Стадии
INSERT INTO season_stage (season_id, code, name, order_no)
SELECT s.season_id, v.code, v.name, v.order_no
FROM season s
JOIN (VALUES
  ('league',   'League phase',                 1),
  ('playoffs', 'Knockout phase play-offs',     2),
  ('r16',      'Round of 16',                  3),
  ('qf',       'Quarter-finals',               4),
  ('sf',       'Semi-finals',                  5),
  ('final',    'Final',                        6)
) AS v(code, name, order_no) ON true
WHERE s.code = '2024/2025';

INSERT INTO team_season (team_id, season_id, tournament_outcome)
SELECT t.team_id, s.season_id,
       CASE t.name
         WHEN 'Real Madrid' THEN 'winner'
         WHEN 'Manchester City' THEN 'eliminated_sf'
         WHEN 'Bayern Munich' THEN 'eliminated_qf'
         ELSE 'eliminated_playoffs'
       END
FROM team t
JOIN season s ON s.code = '2024/2025';

-- Игроки
INSERT INTO player (first_name, last_name, birth_date, nationality, position) VALUES
('Jude',    'Bellingham', '2003-06-29', 'England', 'MF'),
('Vinícius','Júnior',     '2000-07-12', 'Brazil',  'FW'),
('Erling',  'Haaland',    '2000-07-21', 'Norway',  'FW'),
('Kevin',   'De Bruyne',  '1991-06-28', 'Belgium', 'MF'),
('Harry',   'Kane',       '1993-07-28', 'England', 'FW'),
('Jamal',   'Musiala',    '2003-02-26', 'Germany', 'MF'),
('Kylian',  'Mbappé',     '1998-12-20', 'France',  'FW'),
('Ousmane', 'Dembélé',    '1997-05-15', 'France',  'FW');

-- Контракты
INSERT INTO player_team_contract (player_id, team_id, start_date, end_date, contract_type)
SELECT p.player_id, t.team_id, '2024-07-01', NULL, 'transfer'
FROM player p
JOIN team t ON
  (p.last_name IN ('Bellingham','Júnior') AND t.name='Real Madrid')
  OR (p.last_name IN ('Haaland','De Bruyne') AND t.name='Manchester City')
  OR (p.last_name IN ('Kane','Musiala') AND t.name='Bayern Munich')
  OR (p.last_name IN ('Mbappé','Dembélé') AND t.name='Paris Saint-Germain');

-- Матчи
WITH s AS (
  SELECT season_id FROM season WHERE code='2024/2025'
),
st AS (
  SELECT stage_id, code FROM season_stage WHERE season_id=(SELECT season_id FROM s)
),
tm AS (
  SELECT team_id, name FROM team
)
INSERT INTO ucl_match (
  season_id, stage_id, match_datetime,
  home_team_id, away_team_id,
  venue, city, home_goals, away_goals
)
SELECT (SELECT season_id FROM s),
       (SELECT stage_id FROM st WHERE code='league'),
       TIMESTAMP '2024-09-18 21:00:00',
       (SELECT team_id FROM tm WHERE name='Real Madrid'),
       (SELECT team_id FROM tm WHERE name='Manchester City'),
       'Santiago Bernabéu', 'Madrid', 2, 1
UNION ALL
SELECT (SELECT season_id FROM s),
       (SELECT stage_id FROM st WHERE code='league'),
       TIMESTAMP '2024-09-19 21:00:00',
       (SELECT team_id FROM tm WHERE name='Bayern Munich'),
       (SELECT team_id FROM tm WHERE name='Paris Saint-Germain'),
       'Allianz Arena', 'Munich', 1, 1
UNION ALL
SELECT (SELECT season_id FROM s),
       (SELECT stage_id FROM st WHERE code='league'),
       TIMESTAMP '2024-10-02 21:00:00',
       (SELECT team_id FROM tm WHERE name='Manchester City'),
       (SELECT team_id FROM tm WHERE name='Bayern Munich'),
       'Etihad Stadium', 'Manchester', 3, 2
UNION ALL
SELECT (SELECT season_id FROM s),
       (SELECT stage_id FROM st WHERE code='league'),
       TIMESTAMP '2024-10-03 21:00:00',
       (SELECT team_id FROM tm WHERE name='Paris Saint-Germain'),
       (SELECT team_id FROM tm WHERE name='Real Madrid'),
       'Parc des Princes', 'Paris', 0, 1
UNION ALL
SELECT (SELECT season_id FROM s),
       (SELECT stage_id FROM st WHERE code='playoffs'),
       TIMESTAMP '2025-02-12 21:00:00',
       (SELECT team_id FROM tm WHERE name='Paris Saint-Germain'),
       (SELECT team_id FROM tm WHERE name='Bayern Munich'),
       'Parc des Princes', 'Paris', 2, 2
UNION ALL
SELECT (SELECT season_id FROM s),
       (SELECT stage_id FROM st WHERE code='playoffs'),
       TIMESTAMP '2025-02-19 21:00:00',
       (SELECT team_id FROM tm WHERE name='Bayern Munich'),
       (SELECT team_id FROM tm WHERE name='Paris Saint-Germain'),
       'Allianz Arena', 'Munich', 2, 1
UNION ALL
SELECT (SELECT season_id FROM s),
       (SELECT stage_id FROM st WHERE code='qf'),
       TIMESTAMP '2025-04-09 21:00:00',
       (SELECT team_id FROM tm WHERE name='Real Madrid'),
       (SELECT team_id FROM tm WHERE name='Bayern Munich'),
       'Santiago Bernabéu', 'Madrid', 2, 0
UNION ALL
SELECT (SELECT season_id FROM s),
       (SELECT stage_id FROM st WHERE code='final'),
       TIMESTAMP '2025-05-31 21:00:00',
       (SELECT team_id FROM tm WHERE name='Real Madrid'),
       (SELECT team_id FROM tm WHERE name='Manchester City'),
       'Allianz Arena', 'Munich', 1, 0;

-- Участие в матчах
WITH m AS (
  SELECT match_id FROM ucl_match WHERE match_datetime = TIMESTAMP '2024-09-18 21:00:00'
),
p AS (SELECT player_id, last_name FROM player),
t AS (SELECT team_id, name FROM team)
INSERT INTO player_match (match_id, player_id, team_id, minutes_played, started)
VALUES
((SELECT match_id FROM m), (SELECT player_id FROM p WHERE last_name='Bellingham'),
 (SELECT team_id FROM t WHERE name='Real Madrid'), 90, true),
((SELECT match_id FROM m), (SELECT player_id FROM p WHERE last_name='Júnior'),
 (SELECT team_id FROM t WHERE name='Real Madrid'), 90, true),
((SELECT match_id FROM m), (SELECT player_id FROM p WHERE last_name='Haaland'),
 (SELECT team_id FROM t WHERE name='Manchester City'), 90, true),
((SELECT match_id FROM m), (SELECT player_id FROM p WHERE last_name='De Bruyne'),
 (SELECT team_id FROM t WHERE name='Manchester City'), 75, true);

-- Матч
WITH m AS (
  SELECT match_id FROM ucl_match WHERE match_datetime = TIMESTAMP '2025-05-31 21:00:00'
),
p AS (SELECT player_id, last_name FROM player),
t AS (SELECT team_id, name FROM team)
INSERT INTO player_match (match_id, player_id, team_id, minutes_played, started)
VALUES
((SELECT match_id FROM m), (SELECT player_id FROM p WHERE last_name='Bellingham'),
 (SELECT team_id FROM t WHERE name='Real Madrid'), 90, true),
((SELECT match_id FROM m), (SELECT player_id FROM p WHERE last_name='Júnior'),
 (SELECT team_id FROM t WHERE name='Real Madrid'), 88, true),
((SELECT match_id FROM m), (SELECT player_id FROM p WHERE last_name='Haaland'),
 (SELECT team_id FROM t WHERE name='Manchester City'), 90, true),
((SELECT match_id FROM m), (SELECT player_id FROM p WHERE last_name='De Bruyne'),
 (SELECT team_id FROM t WHERE name='Manchester City'), 90, true);

-- События 
WITH m AS (
  SELECT match_id FROM ucl_match WHERE match_datetime = TIMESTAMP '2024-09-18 21:00:00'
),
p AS (SELECT player_id, last_name FROM player),
t AS (SELECT team_id, name FROM team)
INSERT INTO match_event (match_id, team_id, event_type, minute, player_id, related_player_id)
VALUES
((SELECT match_id FROM m), (SELECT team_id FROM t WHERE name='Real Madrid'),
 'goal', 23, (SELECT player_id FROM p WHERE last_name='Júnior'), NULL),
((SELECT match_id FROM m), (SELECT team_id FROM t WHERE name='Manchester City'),
 'goal', 44, (SELECT player_id FROM p WHERE last_name='Haaland'), NULL),
((SELECT match_id FROM m), (SELECT team_id FROM t WHERE name='Real Madrid'),
 'goal', 77, (SELECT player_id FROM p WHERE last_name='Bellingham'), NULL),
((SELECT match_id FROM m), (SELECT team_id FROM t WHERE name='Manchester City'),
 'yellow', 68, (SELECT player_id FROM p WHERE last_name='De Bruyne'), NULL);

-- Матч (финал)
WITH m AS (
  SELECT match_id FROM ucl_match WHERE match_datetime = TIMESTAMP '2025-05-31 21:00:00'
),
p AS (SELECT player_id, last_name FROM player),
t AS (SELECT team_id, name FROM team)
INSERT INTO match_event (match_id, team_id, event_type, minute, player_id, related_player_id)
VALUES
((SELECT match_id FROM m), (SELECT team_id FROM t WHERE name='Real Madrid'),
 'goal', 61, (SELECT player_id FROM p WHERE last_name='Bellingham'), NULL),
((SELECT match_id FROM m), (SELECT team_id FROM t WHERE name='Manchester City'),
 'yellow', 70, (SELECT player_id FROM p WHERE last_name='Haaland'), NULL),
((SELECT match_id FROM m), (SELECT team_id FROM t WHERE name='Real Madrid'),
 'substitution', 88,
 (SELECT player_id FROM p WHERE last_name='Júnior'),
 (SELECT player_id FROM p WHERE last_name='Bellingham'));

COMMIT;