import numpy as np
import pandas as pd
import pytest


def make_league_games(n_seasons=3, n_clubs=6, league="GB1", seed=0, first_season=2020,
                      start_id=1):
    """Double round-robin seasons where club strength = club index (club 1 strongest)."""
    rng = np.random.default_rng(seed)
    strength = np.linspace(1.0, -1.0, n_clubs)
    rows, gid = [], start_id
    for s in range(n_seasons):
        season = first_season + s
        day = pd.Timestamp(season, 8, 1)
        for h in range(n_clubs):
            for a in range(n_clubs):
                if h == a:
                    continue
                lh = np.exp(0.25 + 0.5 * (strength[h] - strength[a]))
                la = np.exp(0.0 + 0.5 * (strength[a] - strength[h]))
                rows.append({"game_id": gid, "competition_id": league,
                             "competition_type": "domestic_league", "season": season,
                             "date": day, "home_club_id": h + 1, "away_club_id": a + 1,
                             "home_goals": int(rng.poisson(lh)), "away_goals": int(rng.poisson(la)),
                             "home_club_name": f"C{h + 1}", "away_club_name": f"C{a + 1}"})
                gid += 1
                day += pd.Timedelta(days=3)
    return pd.DataFrame(rows)


@pytest.fixture
def league_games():
    return make_league_games()
