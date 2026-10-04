"""Per-appearance enrichment and per-(player, season) feature tables."""
import numpy as np
import pandas as pd

from touchline.config import LEAGUES

POS_GROUPS = ["Attack", "Midfield", "Defender", "Goalkeeper"]
_LEAGUES = list(LEAGUES)


def season_ref_date(season: int) -> pd.Timestamp:
    return pd.Timestamp(int(season) + 1, 7, 1)


def _season_from_date(d: pd.Series) -> pd.Series:
    return pd.Series(np.where(d.dt.month >= 7, d.dt.year, d.dt.year - 1), index=d.index)


def enrich_appearances(apps: pd.DataFrame, games: pd.DataFrame) -> pd.DataFrame:
    g = games[["game_id", "season", "home_club_id", "away_club_id", "home_club_name",
               "away_club_name"]]
    e = apps.merge(g, on="game_id", how="left")
    e["season"] = e["season"].fillna(_season_from_date(e["date"])).astype(int)
    e["is_league"] = e["competition_id"].isin(_LEAGUES)
    known = e["home_club_id"].notna()
    home = known & (e["club_id"] == e["home_club_id"])
    e["is_home"] = np.where(~known, 0.5, home.astype(float))
    e["opp_name"] = np.where(home, e["away_club_name"], e["home_club_name"])
    e.loc[~known, "opp_name"] = None
    return e.sort_values(["player_id", "date", "game_id"]).reset_index(drop=True)


def season_stats(eapps: pd.DataFrame, games: pd.DataFrame) -> pd.DataFrame:
    keys = ["player_id", "season"]
    agg = eapps.groupby(keys).agg(apps=("game_id", "size"), minutes=("minutes", "sum"),
                                  goals=("goals", "sum"), assists=("assists", "sum"),
                                  yellow=("yellow_cards", "sum"),
                                  red=("red_cards", "sum")).reset_index()
    lg = eapps[eapps.is_league]
    lmin = lg.groupby(keys).agg(league_apps=("game_id", "size"),
                                league_minutes=("minutes", "sum")).reset_index()
    main = (lg.groupby(keys + ["club_id", "competition_id"])["minutes"].sum().reset_index()
              .sort_values("minutes", ascending=False).drop_duplicates(keys)
              .rename(columns={"competition_id": "league"})[keys + ["club_id", "league"]])
    lgames = games[games.competition_id.isin(_LEAGUES)]
    team_games = (pd.concat([
        lgames[["season", "home_club_id"]].rename(columns={"home_club_id": "club_id"}),
        lgames[["season", "away_club_id"]].rename(columns={"away_club_id": "club_id"})])
        .value_counts().rename("team_games").reset_index())
    out = (agg.merge(lmin, on=keys, how="left").merge(main, on=keys, how="left")
              .merge(team_games, on=["season", "club_id"], how="left"))
    out[["league_apps", "league_minutes"]] = out[["league_apps", "league_minutes"]].fillna(0)
    m90 = out["minutes"].clip(lower=1) / 90
    out["ga90"] = (out.goals + out.assists) / m90
    out["g90"] = out.goals / m90
    out["a90"] = out.assists / m90
    out["yellow90"] = out.yellow / m90
    out["minutes_share"] = out.league_minutes / (out.team_games * 90)
    return out


def add_prev_season(stats: pd.DataFrame) -> pd.DataFrame:
    prev = stats[["player_id", "season", "minutes", "ga90"]].copy()
    prev["season"] += 1
    prev = prev.rename(columns={"minutes": "prev_minutes", "ga90": "prev_ga90"})
    return stats.merge(prev, on=["player_id", "season"], how="left")


def display_population(stats: pd.DataFrame, players: pd.DataFrame, season: int) -> pd.DataFrame:
    """Players who played top-5 league football that season and are still in the dataset."""
    current = players.loc[players.last_season >= season, "player_id"]
    return stats[(stats.season == season) & stats.league.notna()
                 & stats.player_id.isin(current)]


def build_player_rows(stats, players, valuations, history, min_league_minutes: int = 450,
                      with_target: bool = True) -> pd.DataFrame:
    rows = stats[stats.league_minutes >= min_league_minutes].copy()
    rows["club_id"] = rows["club_id"].astype("int64")
    rows["ref"] = rows["season"].map(season_ref_date).astype("datetime64[ns]")
    meta = players[["player_id", "dob", "position", "sub_position", "foot", "height"]]
    rows = rows.merge(meta, on="player_id", how="left")
    rows["age"] = (rows["ref"] - rows["dob"]).dt.days / 365.25

    h = history.rename(columns={"date": "ref", "rating": "club_elo"}).copy()
    h["ref"] = h["ref"].astype("datetime64[ns]")
    h["club_id"] = h["club_id"].astype("int64")
    rows = pd.merge_asof(rows.sort_values("ref"), h.sort_values("ref"), on="ref", by="club_id",
                         direction="backward")
    if with_target:
        v = valuations.rename(columns={"value": "target_value"}).copy()
        v["ref"] = v["date"].astype("datetime64[ns]")
        v["player_id"] = v["player_id"].astype(rows["player_id"].dtype)
        rows = pd.merge_asof(rows.sort_values("ref"),
                             v[["player_id", "ref", "target_value"]].sort_values("ref"),
                             on="ref", by="player_id", direction="nearest",
                             tolerance=pd.Timedelta(days=90))
        rows = rows[rows.target_value > 0]
    return rows.drop(columns=["ref"]).reset_index(drop=True)
