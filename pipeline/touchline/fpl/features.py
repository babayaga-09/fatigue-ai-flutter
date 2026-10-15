"""Walk-forward features for the FPL model.

Every value for gameweek g comes only from gameweeks before g in the same season, plus the
player's previous-season totals at half weight. Per-90 rates are shrunk toward the position
average (empirical-Bayes style: k "prior 90s" of the average), so a player with two good games
does not look like a star."""
import numpy as np
import pandas as pd

from touchline.fpl.scoring import RULES
from touchline.fpl.teams import club_id

RATES = {  # event column -> prior strength in 90-minute units
    "expected_goals": 5.0, "expected_assists": 5.0, "bonus": 8.0, "saves": 5.0,
    "yellow_cards": 10.0, "red_cards": 30.0,
}
PREV_WEIGHT = 0.5
DC_K = 5.0


def gw_table(arch: pd.DataFrame) -> pd.DataFrame:
    """One row per (season, element, gw): double gameweeks summed."""
    a = arch.copy()
    thr = pd.Series([RULES[s].dc_threshold.get(p, np.inf) for s, p in
                     zip(a.season, a.position, strict=True)], index=a.index, dtype=float)
    a["dc_hit"] = ((a.defensive_contribution >= thr) & (a.minutes > 0)).astype(int)
    a["apps60"] = (a.minutes >= 60).astype(int)
    a["played"] = (a.minutes > 0).astype(int)
    sums = ["minutes", "starts", "total_points", "xP", "goals_scored", "assists", "dc_hit",
            "apps60", "played", *RATES]
    g = a.groupby(["season", "element", "gw"], sort=True)
    out = g[sums].sum()
    out["n_fix"] = g.size()
    last = g[["name", "position", "team", "value", "selected"]].last()
    return out.join(last).reset_index()


def position_priors(gwt: pd.DataFrame) -> dict:
    """Per-90 event rates and DC hit rate by position, from the rows given (training data)."""
    pri = {}
    for pos, d in gwt[gwt.minutes > 0].groupby("position"):
        n90 = d.minutes.sum() / 90.0
        pri[pos] = {c: d[c].sum() / n90 for c in RATES}
        pri[pos]["dc"] = d.dc_hit.sum() / max(d.apps60.sum(), 1)
    return pri


def player_gw_features(gwt: pd.DataFrame, priors: dict) -> pd.DataFrame:
    f = gwt.sort_values(["season", "element", "gw"]).reset_index(drop=True)
    grp = f.groupby(["season", "element"], sort=False)

    def before(col):  # season total of col over earlier gameweeks only
        return grp[col].cumsum() - f[col]

    for w in (1, 3, 6):
        f[f"min_last{w}"] = grp["minutes"].transform(
            lambda s, w=w: s.shift(1).rolling(w, min_periods=1).sum()).fillna(0.0)
    for w in (3, 6):
        f[f"starts_last{w}"] = grp["starts"].transform(
            lambda s, w=w: s.shift(1).rolling(w, min_periods=1).sum()).fillna(0.0)
    n_before = grp.cumcount()
    f["played_share"] = (before("played") / n_before.where(n_before > 0)).fillna(0.0)
    f["gws_seen"] = n_before

    # previous season totals, joined by name (FPL element ids change every season)
    seasons = sorted(f.season.unique())
    prev_of = dict(zip(seasons[1:], seasons[:-1], strict=False))
    tot = f.groupby(["season", "name"])[["minutes", "apps60", "dc_hit", *RATES]].sum()
    keys = list(zip(f.season.map(prev_of), f.name, strict=True))
    prev = tot.reindex(keys).fillna(0.0).reset_index(drop=True)

    mins = before("minutes") + PREV_WEIGHT * prev["minutes"]
    for col, k in RATES.items():
        prior = f.position.map(lambda p, c=col: priors.get(p, {}).get(c, 0.0))
        ev = before(col) + PREV_WEIGHT * prev[col]
        f[col + "_90"] = (ev + k * prior) / (mins / 90.0 + k)
    dc_prior = f.position.map(lambda p: priors.get(p, {}).get("dc", 0.0))
    apps = before("apps60") + PREV_WEIGHT * prev["apps60"]
    f["dc_rate"] = (before("dc_hit") + PREV_WEIGHT * prev["dc_hit"] + DC_K * dc_prior) \
        / (apps + DC_K)
    return f


def fixture_strength(fixtures: pd.DataFrame, team_names: dict, elo_history: pd.DataFrame,
                     model) -> pd.DataFrame:
    """Per (fixture, FPL team): expected goals for/against and clean-sheet chance from the Elo
    rating each club held just before kickoff."""
    fx = fixtures.dropna(subset=["kickoff_time"]).copy()
    fx["club_h"] = fx.team_h.map(lambda t: club_id(team_names[int(t)]))
    fx["club_a"] = fx.team_a.map(lambda t: club_id(team_names[int(t)]))
    h = elo_history.rename(columns={"date": "kickoff_time", "rating": "r"}).copy()
    h["kickoff_time"] = pd.to_datetime(h.kickoff_time, utc=True)
    h = h.sort_values("kickoff_time")
    fx = fx.sort_values("kickoff_time")
    for side in ("h", "a"):
        fx = pd.merge_asof(fx, h.rename(columns={"club_id": f"club_{side}", "r": f"r_{side}"}),
                           on="kickoff_time", by=f"club_{side}", direction="backward",
                           allow_exact_matches=False)
    fx[["r_h", "r_a"]] = fx[["r_h", "r_a"]].fillna(1400.0)  # unseen club: a weak side
    d = (fx.r_h - fx.r_a).to_numpy()
    lh, la = model.rates(d)
    m = model.score_matrices(d)
    cs_h, cs_a = m[:, :, 0].sum(axis=1), m[:, 0, :].sum(axis=1)
    base = {"fixture": fx.id.to_numpy(), "event": fx.event.to_numpy(),
            "kickoff_time": fx.kickoff_time.to_numpy()}
    home = pd.DataFrame({**base, "team": fx.team_h.to_numpy(), "was_home": True,
                         "lam_for": lh, "lam_against": la, "p_cs": cs_h})
    away = pd.DataFrame({**base, "team": fx.team_a.to_numpy(), "was_home": False,
                         "lam_for": la, "lam_against": lh, "p_cs": cs_a})
    out = pd.concat([home, away], ignore_index=True).sort_values(["team", "kickoff_time"])
    # a player's rates already include his team's usual strength, so fixtures are priced
    # relative to that team's earlier fixtures (no peeking at its later schedule)
    prior_mean = out.groupby("team").lam_for.transform(
        lambda s: s.shift(1).expanding().mean())
    out["att_mult"] = (out.lam_for / prior_mean.fillna(out.lam_for)).clip(0.4, 2.5)
    return out.reset_index(drop=True)
