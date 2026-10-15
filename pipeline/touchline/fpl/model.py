"""Glue: team strength context from Touchline's Elo + match model, and per-fixture model rows."""
from pathlib import Path

import pandas as pd

from touchline import config
from touchline.fpl.features import fixture_strength, gw_table, player_gw_features, position_priors
from touchline.fpl.fetch import load_archive, load_fixtures, teams
from touchline.models import elo, match_model


def strength_context(tm: dict, fit_before: pd.Timestamp):
    """Elo history over all games (walk-forward by construction) and a match model fitted only
    on top-five league games before `fit_before`."""
    games = tm["games"]
    res = elo.run_elo(games)
    lg = games[games.competition_id.isin(list(config.LEAGUES))].merge(res.pre, on="game_id")
    lg["d"] = lg.elo_home - lg.elo_away
    fit = lg[(lg.season >= config.MODEL_FROM_SEASON)
             & (pd.to_datetime(lg.date) < fit_before.tz_localize(None))]
    model = match_model.fit_match_model(fit.d, fit.home_goals, fit.away_goals)
    return res.history, model


def model_rows(seasons: list[str], prior_seasons: list[str], raw_dir: Path,
               elo_history, model) -> pd.DataFrame:
    """One row per player-fixture for `seasons`: walk-forward features + fixture strength."""
    arch = load_archive(sorted(set(seasons) | set(prior_seasons)), raw_dir)
    gwt = gw_table(arch)
    priors = position_priors(gwt[gwt.season.isin(prior_seasons)])
    feats = player_gw_features(gwt, priors)
    feats = feats[feats.season.isin(seasons)]
    out = []
    for s in seasons:
        names = teams(s, raw_dir)
        by_name = {v: k for k, v in names.items()}
        st = fixture_strength(load_fixtures(s, raw_dir), names, elo_history, model)
        a = arch[arch.season == s][["season", "gw", "element", "fixture", "team", "minutes",
                                    "total_points"]].copy()
        a["team_id"] = a.team.map(by_name)
        a = a.merge(st[["fixture", "team", "att_mult", "p_cs", "lam_against", "lam_for"]],
                    left_on=["fixture", "team_id"], right_on=["fixture", "team"],
                    suffixes=("", "_s")).drop(columns=["team_s"])
        f = feats[feats.season == s].drop(columns=["minutes", "total_points", "team"])
        out.append(a.merge(f, on=["season", "gw", "element"]))
    return pd.concat(out, ignore_index=True)
