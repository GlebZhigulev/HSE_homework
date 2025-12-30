--
-- PostgreSQL database dump
--

-- Dumped from database version 14.5 (Debian 14.5-2.pgdg110+2)
-- Dumped by pg_dump version 14.5 (Debian 14.5-2.pgdg110+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY ucl.ucl_match DROP CONSTRAINT IF EXISTS ucl_match_stage_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.ucl_match DROP CONSTRAINT IF EXISTS ucl_match_season_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.ucl_match DROP CONSTRAINT IF EXISTS ucl_match_home_team_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.ucl_match DROP CONSTRAINT IF EXISTS ucl_match_away_team_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.team_season DROP CONSTRAINT IF EXISTS team_season_team_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.team_season DROP CONSTRAINT IF EXISTS team_season_season_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.season_stage DROP CONSTRAINT IF EXISTS season_stage_season_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.player_team_contract DROP CONSTRAINT IF EXISTS player_team_contract_team_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.player_team_contract DROP CONSTRAINT IF EXISTS player_team_contract_player_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.player_match DROP CONSTRAINT IF EXISTS player_match_team_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.player_match DROP CONSTRAINT IF EXISTS player_match_player_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.player_match DROP CONSTRAINT IF EXISTS player_match_match_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.match_event DROP CONSTRAINT IF EXISTS match_event_team_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.match_event DROP CONSTRAINT IF EXISTS match_event_related_player_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.match_event DROP CONSTRAINT IF EXISTS match_event_player_id_fkey;
ALTER TABLE IF EXISTS ONLY ucl.match_event DROP CONSTRAINT IF EXISTS match_event_match_id_fkey;
DROP TRIGGER IF EXISTS match_stage_season_ck ON ucl.ucl_match;
DROP TRIGGER IF EXISTS event_team_player_ck ON ucl.match_event;
DROP INDEX IF EXISTS ucl.ucl_match_stage_dt_idx;
DROP INDEX IF EXISTS ucl.ucl_match_season_dt_idx;
DROP INDEX IF EXISTS ucl.ucl_match_home_dt_idx;
DROP INDEX IF EXISTS ucl.ucl_match_away_dt_idx;
DROP INDEX IF EXISTS ucl.player_team_contract_team_idx;
DROP INDEX IF EXISTS ucl.player_team_contract_player_idx;
DROP INDEX IF EXISTS ucl.player_match_team_match_idx;
DROP INDEX IF EXISTS ucl.match_event_player_match_idx;
DROP INDEX IF EXISTS ucl.match_event_match_type_idx;
DROP INDEX IF EXISTS ucl.match_event_match_min_idx;
ALTER TABLE IF EXISTS ONLY ucl.ucl_match DROP CONSTRAINT IF EXISTS ucl_match_pkey;
ALTER TABLE IF EXISTS ONLY ucl.team_season DROP CONSTRAINT IF EXISTS team_season_pkey;
ALTER TABLE IF EXISTS ONLY ucl.team DROP CONSTRAINT IF EXISTS team_pkey;
ALTER TABLE IF EXISTS ONLY ucl.team DROP CONSTRAINT IF EXISTS team_name_key;
ALTER TABLE IF EXISTS ONLY ucl.season_stage DROP CONSTRAINT IF EXISTS season_stage_pkey;
ALTER TABLE IF EXISTS ONLY ucl.season_stage DROP CONSTRAINT IF EXISTS season_stage_order_uq;
ALTER TABLE IF EXISTS ONLY ucl.season_stage DROP CONSTRAINT IF EXISTS season_stage_code_uq;
ALTER TABLE IF EXISTS ONLY ucl.season DROP CONSTRAINT IF EXISTS season_pkey;
ALTER TABLE IF EXISTS ONLY ucl.season DROP CONSTRAINT IF EXISTS season_code_key;
ALTER TABLE IF EXISTS ONLY ucl.player_team_contract DROP CONSTRAINT IF EXISTS player_team_contract_pkey;
ALTER TABLE IF EXISTS ONLY ucl.player DROP CONSTRAINT IF EXISTS player_pkey;
ALTER TABLE IF EXISTS ONLY ucl.player_match DROP CONSTRAINT IF EXISTS player_match_unique;
ALTER TABLE IF EXISTS ONLY ucl.player_match DROP CONSTRAINT IF EXISTS player_match_pkey;
ALTER TABLE IF EXISTS ONLY ucl.match_event DROP CONSTRAINT IF EXISTS match_event_pkey;
ALTER TABLE IF EXISTS ucl.ucl_match ALTER COLUMN match_id DROP DEFAULT;
ALTER TABLE IF EXISTS ucl.team ALTER COLUMN team_id DROP DEFAULT;
ALTER TABLE IF EXISTS ucl.season_stage ALTER COLUMN stage_id DROP DEFAULT;
ALTER TABLE IF EXISTS ucl.season ALTER COLUMN season_id DROP DEFAULT;
ALTER TABLE IF EXISTS ucl.player_team_contract ALTER COLUMN contract_id DROP DEFAULT;
ALTER TABLE IF EXISTS ucl.player_match ALTER COLUMN player_match_id DROP DEFAULT;
ALTER TABLE IF EXISTS ucl.player ALTER COLUMN player_id DROP DEFAULT;
ALTER TABLE IF EXISTS ucl.match_event ALTER COLUMN event_id DROP DEFAULT;
DROP SEQUENCE IF EXISTS ucl.ucl_match_match_id_seq;
DROP TABLE IF EXISTS ucl.ucl_match;
DROP SEQUENCE IF EXISTS ucl.team_team_id_seq;
DROP TABLE IF EXISTS ucl.team_season;
DROP TABLE IF EXISTS ucl.team;
DROP SEQUENCE IF EXISTS ucl.season_stage_stage_id_seq;
DROP TABLE IF EXISTS ucl.season_stage;
DROP SEQUENCE IF EXISTS ucl.season_season_id_seq;
DROP TABLE IF EXISTS ucl.season;
DROP SEQUENCE IF EXISTS ucl.player_team_contract_contract_id_seq;
DROP TABLE IF EXISTS ucl.player_team_contract;
DROP SEQUENCE IF EXISTS ucl.player_player_id_seq;
DROP SEQUENCE IF EXISTS ucl.player_match_player_match_id_seq;
DROP TABLE IF EXISTS ucl.player_match;
DROP TABLE IF EXISTS ucl.player;
DROP SEQUENCE IF EXISTS ucl.match_event_event_id_seq;
DROP TABLE IF EXISTS ucl.match_event;
DROP FUNCTION IF EXISTS ucl.trg_match_stage_season_consistency();
DROP FUNCTION IF EXISTS ucl.trg_event_team_and_player_consistency();
DROP FUNCTION IF EXISTS ucl.get_player_season_summary(p_season_code character varying, p_last_name character varying);
DROP FUNCTION IF EXISTS ucl.get_league_table(p_season_code character varying);
DROP SCHEMA IF EXISTS ucl;
--
-- Name: ucl; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ucl;


ALTER SCHEMA ucl OWNER TO postgres;

--
-- Name: get_league_table(character varying); Type: FUNCTION; Schema: ucl; Owner: postgres
--

CREATE FUNCTION ucl.get_league_table(p_season_code character varying) RETURNS TABLE(pos integer, team_name character varying, played integer, wins integer, draws integer, losses integer, goals_for integer, goals_against integer, goal_diff integer, points integer)
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


ALTER FUNCTION ucl.get_league_table(p_season_code character varying) OWNER TO postgres;

--
-- Name: get_player_season_summary(character varying, character varying); Type: FUNCTION; Schema: ucl; Owner: postgres
--

CREATE FUNCTION ucl.get_player_season_summary(p_season_code character varying, p_last_name character varying) RETURNS TABLE(player_name text, matches_played integer, total_minutes integer, goals integer, yellow_cards integer, red_cards integer)
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


ALTER FUNCTION ucl.get_player_season_summary(p_season_code character varying, p_last_name character varying) OWNER TO postgres;

--
-- Name: trg_event_team_and_player_consistency(); Type: FUNCTION; Schema: ucl; Owner: postgres
--

CREATE FUNCTION ucl.trg_event_team_and_player_consistency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_home bigint;
  v_away bigint;
  v_exists boolean;
BEGIN
  SELECT home_team_id, away_team_id INTO v_home, v_away
  FROM ucl.ucl_match
  WHERE match_id = NEW.match_id;

  IF v_home IS NULL THEN
    RAISE EXCEPTION 'Match % not found', NEW.match_id;
  END IF;

  IF NEW.team_id <> v_home AND NEW.team_id <> v_away THEN
    RAISE EXCEPTION 'Event team_id % is not a participant of match % (home %, away %)',
      NEW.team_id, NEW.match_id, v_home, v_away;
  END IF;

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

  IF NEW.event_type = 'substitution' AND NEW.related_player_id IS NOT NULL THEN
    -- optional consistency: both players should be registered in player_match
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


ALTER FUNCTION ucl.trg_event_team_and_player_consistency() OWNER TO postgres;

--
-- Name: trg_match_stage_season_consistency(); Type: FUNCTION; Schema: ucl; Owner: postgres
--

CREATE FUNCTION ucl.trg_match_stage_season_consistency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_stage_season_id bigint;
BEGIN
  SELECT season_id INTO v_stage_season_id
  FROM ucl.season_stage
  WHERE stage_id = NEW.stage_id;

  IF v_stage_season_id IS NULL THEN
    RAISE EXCEPTION 'Stage % not found', NEW.stage_id;
  END IF;

  IF v_stage_season_id <> NEW.season_id THEN
    RAISE EXCEPTION 'Stage % belongs to season %, but match refers to season %',
      NEW.stage_id, v_stage_season_id, NEW.season_id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION ucl.trg_match_stage_season_consistency() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: match_event; Type: TABLE; Schema: ucl; Owner: postgres
--

CREATE TABLE ucl.match_event (
    event_id bigint NOT NULL,
    match_id bigint NOT NULL,
    team_id bigint NOT NULL,
    event_type character varying(20) NOT NULL,
    minute integer NOT NULL,
    player_id bigint,
    related_player_id bigint,
    CONSTRAINT match_event_minute_ck CHECK (((minute >= 0) AND (minute <= 130))),
    CONSTRAINT match_event_players_ck CHECK ((NOT (((event_type)::text <> 'substitution'::text) AND (related_player_id IS NOT NULL)))),
    CONSTRAINT match_event_type_ck CHECK (((event_type)::text = ANY ((ARRAY['goal'::character varying, 'yellow'::character varying, 'red'::character varying, 'substitution'::character varying, 'own_goal'::character varying, 'penalty_goal'::character varying])::text[])))
);


ALTER TABLE ucl.match_event OWNER TO postgres;

--
-- Name: match_event_event_id_seq; Type: SEQUENCE; Schema: ucl; Owner: postgres
--

CREATE SEQUENCE ucl.match_event_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ucl.match_event_event_id_seq OWNER TO postgres;

--
-- Name: match_event_event_id_seq; Type: SEQUENCE OWNED BY; Schema: ucl; Owner: postgres
--

ALTER SEQUENCE ucl.match_event_event_id_seq OWNED BY ucl.match_event.event_id;


--
-- Name: player; Type: TABLE; Schema: ucl; Owner: postgres
--

CREATE TABLE ucl.player (
    player_id bigint NOT NULL,
    first_name character varying(60) NOT NULL,
    last_name character varying(60) NOT NULL,
    birth_date date,
    nationality character varying(80),
    "position" character varying(20) NOT NULL,
    CONSTRAINT player_position_ck CHECK ((("position")::text = ANY ((ARRAY['GK'::character varying, 'DF'::character varying, 'MF'::character varying, 'FW'::character varying])::text[])))
);


ALTER TABLE ucl.player OWNER TO postgres;

--
-- Name: player_match; Type: TABLE; Schema: ucl; Owner: postgres
--

CREATE TABLE ucl.player_match (
    player_match_id bigint NOT NULL,
    match_id bigint NOT NULL,
    player_id bigint NOT NULL,
    team_id bigint NOT NULL,
    minutes_played integer DEFAULT 0 NOT NULL,
    started boolean DEFAULT false NOT NULL,
    CONSTRAINT player_match_minutes_ck CHECK (((minutes_played >= 0) AND (minutes_played <= 130)))
);


ALTER TABLE ucl.player_match OWNER TO postgres;

--
-- Name: player_match_player_match_id_seq; Type: SEQUENCE; Schema: ucl; Owner: postgres
--

CREATE SEQUENCE ucl.player_match_player_match_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ucl.player_match_player_match_id_seq OWNER TO postgres;

--
-- Name: player_match_player_match_id_seq; Type: SEQUENCE OWNED BY; Schema: ucl; Owner: postgres
--

ALTER SEQUENCE ucl.player_match_player_match_id_seq OWNED BY ucl.player_match.player_match_id;


--
-- Name: player_player_id_seq; Type: SEQUENCE; Schema: ucl; Owner: postgres
--

CREATE SEQUENCE ucl.player_player_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ucl.player_player_id_seq OWNER TO postgres;

--
-- Name: player_player_id_seq; Type: SEQUENCE OWNED BY; Schema: ucl; Owner: postgres
--

ALTER SEQUENCE ucl.player_player_id_seq OWNED BY ucl.player.player_id;


--
-- Name: player_team_contract; Type: TABLE; Schema: ucl; Owner: postgres
--

CREATE TABLE ucl.player_team_contract (
    contract_id bigint NOT NULL,
    player_id bigint NOT NULL,
    team_id bigint NOT NULL,
    start_date date NOT NULL,
    end_date date,
    contract_type character varying(20) DEFAULT 'transfer'::character varying NOT NULL,
    CONSTRAINT contract_dates_ck CHECK (((end_date IS NULL) OR (start_date <= end_date))),
    CONSTRAINT contract_type_ck CHECK (((contract_type)::text = ANY ((ARRAY['transfer'::character varying, 'loan'::character varying])::text[])))
);


ALTER TABLE ucl.player_team_contract OWNER TO postgres;

--
-- Name: player_team_contract_contract_id_seq; Type: SEQUENCE; Schema: ucl; Owner: postgres
--

CREATE SEQUENCE ucl.player_team_contract_contract_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ucl.player_team_contract_contract_id_seq OWNER TO postgres;

--
-- Name: player_team_contract_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: ucl; Owner: postgres
--

ALTER SEQUENCE ucl.player_team_contract_contract_id_seq OWNED BY ucl.player_team_contract.contract_id;


--
-- Name: season; Type: TABLE; Schema: ucl; Owner: postgres
--

CREATE TABLE ucl.season (
    season_id bigint NOT NULL,
    code character varying(9) NOT NULL,
    date_start date NOT NULL,
    date_end date NOT NULL,
    CONSTRAINT season_dates_ck CHECK ((date_start < date_end))
);


ALTER TABLE ucl.season OWNER TO postgres;

--
-- Name: season_season_id_seq; Type: SEQUENCE; Schema: ucl; Owner: postgres
--

CREATE SEQUENCE ucl.season_season_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ucl.season_season_id_seq OWNER TO postgres;

--
-- Name: season_season_id_seq; Type: SEQUENCE OWNED BY; Schema: ucl; Owner: postgres
--

ALTER SEQUENCE ucl.season_season_id_seq OWNED BY ucl.season.season_id;


--
-- Name: season_stage; Type: TABLE; Schema: ucl; Owner: postgres
--

CREATE TABLE ucl.season_stage (
    stage_id bigint NOT NULL,
    season_id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(50) NOT NULL,
    order_no integer NOT NULL,
    CONSTRAINT season_stage_order_ck CHECK ((order_no > 0))
);


ALTER TABLE ucl.season_stage OWNER TO postgres;

--
-- Name: season_stage_stage_id_seq; Type: SEQUENCE; Schema: ucl; Owner: postgres
--

CREATE SEQUENCE ucl.season_stage_stage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ucl.season_stage_stage_id_seq OWNER TO postgres;

--
-- Name: season_stage_stage_id_seq; Type: SEQUENCE OWNED BY; Schema: ucl; Owner: postgres
--

ALTER SEQUENCE ucl.season_stage_stage_id_seq OWNED BY ucl.season_stage.stage_id;


--
-- Name: team; Type: TABLE; Schema: ucl; Owner: postgres
--

CREATE TABLE ucl.team (
    team_id bigint NOT NULL,
    name character varying(120) NOT NULL,
    country character varying(80) NOT NULL,
    city character varying(80),
    home_stadium character varying(120)
);


ALTER TABLE ucl.team OWNER TO postgres;

--
-- Name: team_season; Type: TABLE; Schema: ucl; Owner: postgres
--

CREATE TABLE ucl.team_season (
    team_id bigint NOT NULL,
    season_id bigint NOT NULL,
    tournament_outcome character varying(30) NOT NULL
);


ALTER TABLE ucl.team_season OWNER TO postgres;

--
-- Name: team_team_id_seq; Type: SEQUENCE; Schema: ucl; Owner: postgres
--

CREATE SEQUENCE ucl.team_team_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ucl.team_team_id_seq OWNER TO postgres;

--
-- Name: team_team_id_seq; Type: SEQUENCE OWNED BY; Schema: ucl; Owner: postgres
--

ALTER SEQUENCE ucl.team_team_id_seq OWNED BY ucl.team.team_id;


--
-- Name: ucl_match; Type: TABLE; Schema: ucl; Owner: postgres
--

CREATE TABLE ucl.ucl_match (
    match_id bigint NOT NULL,
    season_id bigint NOT NULL,
    stage_id bigint NOT NULL,
    match_datetime timestamp without time zone NOT NULL,
    home_team_id bigint NOT NULL,
    away_team_id bigint NOT NULL,
    venue character varying(120),
    city character varying(80),
    home_goals integer DEFAULT 0 NOT NULL,
    away_goals integer DEFAULT 0 NOT NULL,
    CONSTRAINT match_goals_ck CHECK (((home_goals >= 0) AND (away_goals >= 0))),
    CONSTRAINT match_teams_ck CHECK ((home_team_id <> away_team_id))
);


ALTER TABLE ucl.ucl_match OWNER TO postgres;

--
-- Name: ucl_match_match_id_seq; Type: SEQUENCE; Schema: ucl; Owner: postgres
--

CREATE SEQUENCE ucl.ucl_match_match_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ucl.ucl_match_match_id_seq OWNER TO postgres;

--
-- Name: ucl_match_match_id_seq; Type: SEQUENCE OWNED BY; Schema: ucl; Owner: postgres
--

ALTER SEQUENCE ucl.ucl_match_match_id_seq OWNED BY ucl.ucl_match.match_id;


--
-- Name: match_event event_id; Type: DEFAULT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.match_event ALTER COLUMN event_id SET DEFAULT nextval('ucl.match_event_event_id_seq'::regclass);


--
-- Name: player player_id; Type: DEFAULT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player ALTER COLUMN player_id SET DEFAULT nextval('ucl.player_player_id_seq'::regclass);


--
-- Name: player_match player_match_id; Type: DEFAULT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_match ALTER COLUMN player_match_id SET DEFAULT nextval('ucl.player_match_player_match_id_seq'::regclass);


--
-- Name: player_team_contract contract_id; Type: DEFAULT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_team_contract ALTER COLUMN contract_id SET DEFAULT nextval('ucl.player_team_contract_contract_id_seq'::regclass);


--
-- Name: season season_id; Type: DEFAULT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.season ALTER COLUMN season_id SET DEFAULT nextval('ucl.season_season_id_seq'::regclass);


--
-- Name: season_stage stage_id; Type: DEFAULT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.season_stage ALTER COLUMN stage_id SET DEFAULT nextval('ucl.season_stage_stage_id_seq'::regclass);


--
-- Name: team team_id; Type: DEFAULT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.team ALTER COLUMN team_id SET DEFAULT nextval('ucl.team_team_id_seq'::regclass);


--
-- Name: ucl_match match_id; Type: DEFAULT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.ucl_match ALTER COLUMN match_id SET DEFAULT nextval('ucl.ucl_match_match_id_seq'::regclass);


--
-- Data for Name: match_event; Type: TABLE DATA; Schema: ucl; Owner: postgres
--

COPY ucl.match_event (event_id, match_id, team_id, event_type, minute, player_id, related_player_id) FROM stdin;
1	1	1	goal	23	2	\N
2	1	2	goal	44	3	\N
3	1	1	goal	77	1	\N
4	1	2	yellow	68	4	\N
5	8	1	goal	61	1	\N
6	8	2	yellow	70	3	\N
7	8	1	substitution	88	2	1
\.


--
-- Data for Name: player; Type: TABLE DATA; Schema: ucl; Owner: postgres
--

COPY ucl.player (player_id, first_name, last_name, birth_date, nationality, "position") FROM stdin;
1	Jude	Bellingham	2003-06-29	England	MF
2	Vin??cius	J??nior	2000-07-12	Brazil	FW
3	Erling	Haaland	2000-07-21	Norway	FW
4	Kevin	De Bruyne	1991-06-28	Belgium	MF
5	Harry	Kane	1993-07-28	England	FW
6	Jamal	Musiala	2003-02-26	Germany	MF
7	Kylian	Mbapp??	1998-12-20	France	FW
8	Ousmane	Demb??l??	1997-05-15	France	FW
\.


--
-- Data for Name: player_match; Type: TABLE DATA; Schema: ucl; Owner: postgres
--

COPY ucl.player_match (player_match_id, match_id, player_id, team_id, minutes_played, started) FROM stdin;
1	1	1	1	90	t
2	1	2	1	90	t
3	1	3	2	90	t
4	1	4	2	75	t
5	8	1	1	90	t
6	8	2	1	88	t
7	8	3	2	90	t
8	8	4	2	90	t
\.


--
-- Data for Name: player_team_contract; Type: TABLE DATA; Schema: ucl; Owner: postgres
--

COPY ucl.player_team_contract (contract_id, player_id, team_id, start_date, end_date, contract_type) FROM stdin;
1	1	1	2024-07-01	\N	transfer
2	2	1	2024-07-01	\N	transfer
3	3	2	2024-07-01	\N	transfer
4	4	2	2024-07-01	\N	transfer
5	5	3	2024-07-01	\N	transfer
6	6	3	2024-07-01	\N	transfer
7	7	4	2024-07-01	\N	transfer
8	8	4	2024-07-01	\N	transfer
\.


--
-- Data for Name: season; Type: TABLE DATA; Schema: ucl; Owner: postgres
--

COPY ucl.season (season_id, code, date_start, date_end) FROM stdin;
1	2024/2025	2024-07-01	2025-06-30
\.


--
-- Data for Name: season_stage; Type: TABLE DATA; Schema: ucl; Owner: postgres
--

COPY ucl.season_stage (stage_id, season_id, code, name, order_no) FROM stdin;
1	1	league	League phase	1
2	1	playoffs	Knockout phase play-offs	2
3	1	r16	Round of 16	3
4	1	qf	Quarter-finals	4
5	1	sf	Semi-finals	5
6	1	final	Final	6
\.


--
-- Data for Name: team; Type: TABLE DATA; Schema: ucl; Owner: postgres
--

COPY ucl.team (team_id, name, country, city, home_stadium) FROM stdin;
1	Real Madrid	Spain	Madrid	Santiago Bernab??u
2	Manchester City	England	Manchester	Etihad Stadium
3	Bayern Munich	Germany	Munich	Allianz Arena
4	Paris Saint-Germain	France	Paris	Parc des Princes
\.


--
-- Data for Name: team_season; Type: TABLE DATA; Schema: ucl; Owner: postgres
--

COPY ucl.team_season (team_id, season_id, tournament_outcome) FROM stdin;
1	1	winner
2	1	eliminated_sf
3	1	eliminated_qf
4	1	eliminated_playoffs
\.


--
-- Data for Name: ucl_match; Type: TABLE DATA; Schema: ucl; Owner: postgres
--

COPY ucl.ucl_match (match_id, season_id, stage_id, match_datetime, home_team_id, away_team_id, venue, city, home_goals, away_goals) FROM stdin;
1	1	1	2024-09-18 21:00:00	1	2	Santiago Bernab??u	Madrid	2	1
2	1	1	2024-09-19 21:00:00	3	4	Allianz Arena	Munich	1	1
3	1	1	2024-10-02 21:00:00	2	3	Etihad Stadium	Manchester	3	2
4	1	1	2024-10-03 21:00:00	4	1	Parc des Princes	Paris	0	1
5	1	2	2025-02-12 21:00:00	4	3	Parc des Princes	Paris	2	2
6	1	2	2025-02-19 21:00:00	3	4	Allianz Arena	Munich	2	1
7	1	4	2025-04-09 21:00:00	1	3	Santiago Bernab??u	Madrid	2	0
8	1	6	2025-05-31 21:00:00	1	2	Allianz Arena	Munich	1	0
\.


--
-- Name: match_event_event_id_seq; Type: SEQUENCE SET; Schema: ucl; Owner: postgres
--

SELECT pg_catalog.setval('ucl.match_event_event_id_seq', 7, true);


--
-- Name: player_match_player_match_id_seq; Type: SEQUENCE SET; Schema: ucl; Owner: postgres
--

SELECT pg_catalog.setval('ucl.player_match_player_match_id_seq', 8, true);


--
-- Name: player_player_id_seq; Type: SEQUENCE SET; Schema: ucl; Owner: postgres
--

SELECT pg_catalog.setval('ucl.player_player_id_seq', 8, true);


--
-- Name: player_team_contract_contract_id_seq; Type: SEQUENCE SET; Schema: ucl; Owner: postgres
--

SELECT pg_catalog.setval('ucl.player_team_contract_contract_id_seq', 8, true);


--
-- Name: season_season_id_seq; Type: SEQUENCE SET; Schema: ucl; Owner: postgres
--

SELECT pg_catalog.setval('ucl.season_season_id_seq', 1, true);


--
-- Name: season_stage_stage_id_seq; Type: SEQUENCE SET; Schema: ucl; Owner: postgres
--

SELECT pg_catalog.setval('ucl.season_stage_stage_id_seq', 6, true);


--
-- Name: team_team_id_seq; Type: SEQUENCE SET; Schema: ucl; Owner: postgres
--

SELECT pg_catalog.setval('ucl.team_team_id_seq', 4, true);


--
-- Name: ucl_match_match_id_seq; Type: SEQUENCE SET; Schema: ucl; Owner: postgres
--

SELECT pg_catalog.setval('ucl.ucl_match_match_id_seq', 8, true);


--
-- Name: match_event match_event_pkey; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.match_event
    ADD CONSTRAINT match_event_pkey PRIMARY KEY (event_id);


--
-- Name: player_match player_match_pkey; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_match
    ADD CONSTRAINT player_match_pkey PRIMARY KEY (player_match_id);


--
-- Name: player_match player_match_unique; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_match
    ADD CONSTRAINT player_match_unique UNIQUE (match_id, player_id);


--
-- Name: player player_pkey; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player
    ADD CONSTRAINT player_pkey PRIMARY KEY (player_id);


--
-- Name: player_team_contract player_team_contract_pkey; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_team_contract
    ADD CONSTRAINT player_team_contract_pkey PRIMARY KEY (contract_id);


--
-- Name: season season_code_key; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.season
    ADD CONSTRAINT season_code_key UNIQUE (code);


--
-- Name: season season_pkey; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.season
    ADD CONSTRAINT season_pkey PRIMARY KEY (season_id);


--
-- Name: season_stage season_stage_code_uq; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.season_stage
    ADD CONSTRAINT season_stage_code_uq UNIQUE (season_id, code);


--
-- Name: season_stage season_stage_order_uq; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.season_stage
    ADD CONSTRAINT season_stage_order_uq UNIQUE (season_id, order_no);


--
-- Name: season_stage season_stage_pkey; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.season_stage
    ADD CONSTRAINT season_stage_pkey PRIMARY KEY (stage_id);


--
-- Name: team team_name_key; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.team
    ADD CONSTRAINT team_name_key UNIQUE (name);


--
-- Name: team team_pkey; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.team
    ADD CONSTRAINT team_pkey PRIMARY KEY (team_id);


--
-- Name: team_season team_season_pkey; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.team_season
    ADD CONSTRAINT team_season_pkey PRIMARY KEY (team_id, season_id);


--
-- Name: ucl_match ucl_match_pkey; Type: CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.ucl_match
    ADD CONSTRAINT ucl_match_pkey PRIMARY KEY (match_id);


--
-- Name: match_event_match_min_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX match_event_match_min_idx ON ucl.match_event USING btree (match_id, minute);


--
-- Name: match_event_match_type_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX match_event_match_type_idx ON ucl.match_event USING btree (match_id, event_type);


--
-- Name: match_event_player_match_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX match_event_player_match_idx ON ucl.match_event USING btree (player_id, match_id);


--
-- Name: player_match_team_match_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX player_match_team_match_idx ON ucl.player_match USING btree (team_id, match_id);


--
-- Name: player_team_contract_player_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX player_team_contract_player_idx ON ucl.player_team_contract USING btree (player_id, start_date);


--
-- Name: player_team_contract_team_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX player_team_contract_team_idx ON ucl.player_team_contract USING btree (team_id, start_date);


--
-- Name: ucl_match_away_dt_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX ucl_match_away_dt_idx ON ucl.ucl_match USING btree (away_team_id, match_datetime);


--
-- Name: ucl_match_home_dt_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX ucl_match_home_dt_idx ON ucl.ucl_match USING btree (home_team_id, match_datetime);


--
-- Name: ucl_match_season_dt_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX ucl_match_season_dt_idx ON ucl.ucl_match USING btree (season_id, match_datetime);


--
-- Name: ucl_match_stage_dt_idx; Type: INDEX; Schema: ucl; Owner: postgres
--

CREATE INDEX ucl_match_stage_dt_idx ON ucl.ucl_match USING btree (stage_id, match_datetime);


--
-- Name: match_event event_team_player_ck; Type: TRIGGER; Schema: ucl; Owner: postgres
--

CREATE TRIGGER event_team_player_ck BEFORE INSERT OR UPDATE OF match_id, team_id, player_id, related_player_id ON ucl.match_event FOR EACH ROW EXECUTE FUNCTION ucl.trg_event_team_and_player_consistency();


--
-- Name: ucl_match match_stage_season_ck; Type: TRIGGER; Schema: ucl; Owner: postgres
--

CREATE TRIGGER match_stage_season_ck BEFORE INSERT OR UPDATE OF season_id, stage_id ON ucl.ucl_match FOR EACH ROW EXECUTE FUNCTION ucl.trg_match_stage_season_consistency();


--
-- Name: match_event match_event_match_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.match_event
    ADD CONSTRAINT match_event_match_id_fkey FOREIGN KEY (match_id) REFERENCES ucl.ucl_match(match_id) ON DELETE CASCADE;


--
-- Name: match_event match_event_player_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.match_event
    ADD CONSTRAINT match_event_player_id_fkey FOREIGN KEY (player_id) REFERENCES ucl.player(player_id) ON DELETE SET NULL;


--
-- Name: match_event match_event_related_player_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.match_event
    ADD CONSTRAINT match_event_related_player_id_fkey FOREIGN KEY (related_player_id) REFERENCES ucl.player(player_id) ON DELETE SET NULL;


--
-- Name: match_event match_event_team_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.match_event
    ADD CONSTRAINT match_event_team_id_fkey FOREIGN KEY (team_id) REFERENCES ucl.team(team_id) ON DELETE RESTRICT;


--
-- Name: player_match player_match_match_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_match
    ADD CONSTRAINT player_match_match_id_fkey FOREIGN KEY (match_id) REFERENCES ucl.ucl_match(match_id) ON DELETE CASCADE;


--
-- Name: player_match player_match_player_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_match
    ADD CONSTRAINT player_match_player_id_fkey FOREIGN KEY (player_id) REFERENCES ucl.player(player_id) ON DELETE CASCADE;


--
-- Name: player_match player_match_team_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_match
    ADD CONSTRAINT player_match_team_id_fkey FOREIGN KEY (team_id) REFERENCES ucl.team(team_id) ON DELETE RESTRICT;


--
-- Name: player_team_contract player_team_contract_player_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_team_contract
    ADD CONSTRAINT player_team_contract_player_id_fkey FOREIGN KEY (player_id) REFERENCES ucl.player(player_id) ON DELETE CASCADE;


--
-- Name: player_team_contract player_team_contract_team_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.player_team_contract
    ADD CONSTRAINT player_team_contract_team_id_fkey FOREIGN KEY (team_id) REFERENCES ucl.team(team_id) ON DELETE CASCADE;


--
-- Name: season_stage season_stage_season_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.season_stage
    ADD CONSTRAINT season_stage_season_id_fkey FOREIGN KEY (season_id) REFERENCES ucl.season(season_id) ON DELETE CASCADE;


--
-- Name: team_season team_season_season_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.team_season
    ADD CONSTRAINT team_season_season_id_fkey FOREIGN KEY (season_id) REFERENCES ucl.season(season_id) ON DELETE CASCADE;


--
-- Name: team_season team_season_team_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.team_season
    ADD CONSTRAINT team_season_team_id_fkey FOREIGN KEY (team_id) REFERENCES ucl.team(team_id) ON DELETE CASCADE;


--
-- Name: ucl_match ucl_match_away_team_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.ucl_match
    ADD CONSTRAINT ucl_match_away_team_id_fkey FOREIGN KEY (away_team_id) REFERENCES ucl.team(team_id) ON DELETE RESTRICT;


--
-- Name: ucl_match ucl_match_home_team_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.ucl_match
    ADD CONSTRAINT ucl_match_home_team_id_fkey FOREIGN KEY (home_team_id) REFERENCES ucl.team(team_id) ON DELETE RESTRICT;


--
-- Name: ucl_match ucl_match_season_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.ucl_match
    ADD CONSTRAINT ucl_match_season_id_fkey FOREIGN KEY (season_id) REFERENCES ucl.season(season_id) ON DELETE CASCADE;


--
-- Name: ucl_match ucl_match_stage_id_fkey; Type: FK CONSTRAINT; Schema: ucl; Owner: postgres
--

ALTER TABLE ONLY ucl.ucl_match
    ADD CONSTRAINT ucl_match_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES ucl.season_stage(stage_id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

