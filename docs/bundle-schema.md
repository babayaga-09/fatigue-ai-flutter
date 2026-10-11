# Touchline bundle — schema v1

Gzipped strict JSON (`touchline-bundle.json.gz`). Produced weekly by `pipeline/`, consumed by
`app/`. Breaking changes bump `schema_version`; the app refuses unknown major versions and keeps
its cached bundle.

```jsonc
{
  "schema_version": 1,
  "generated_at": "2026-10-04T06:00:00Z",
  "data_through": {"players": "2026-06-28", "clubs": "2026-10-03"},
  "player_season": "2025/26",
  "leagues": [{"id": "GB1", "fd": "PL", "name": "Premier League"}],
  "clubs": [{
    "id": 11,                       // Transfermarkt club id; negative = football-data id (club new to dataset)
    "name": "Arsenal", "crest": "https://…png" /* or null */, "league": "GB1",
    "colors": ["#DB0007", "#FFFFFF"],   // traditional scarf colours (primary, secondary); null when unknown
    "elo": 1912.4, "elo_change_30d": 14.2,
    "form": ["W", "D", "W"],        // oldest → newest, up to 5
    "table": {"pos": 1, "played": 7, "points": 19, "gd": 12, "gf": 15, "ga": 3},
    "proj": {"exp_points": 81.3, "exp_pos": 1.7, "p_title": 0.41, "p_top4": 0.93, "p_releg": 0.0}
            // null in offline mode
  }],
  "fixtures": [{
    "id": 537001, "league": "GB1", "kickoff": "2026-10-05T14:00:00Z",
    "home": 11, "away": 31, "status": "TIMED",       // FINISHED fixtures are from the last 7 days
    "score": null,                                    // [home, away] when finished
    "p": [0.46, 0.26, 0.28],                          // home / draw / away (pre-match)
    "xg": [1.62, 1.08]                                // expected goals from the match model
  }],
  "players": [{
    "id": 342229, "name": "…", "img": "https://…",
    "club": 11,                      // current club id; may be absent from clubs[] (e.g. relegated since)
    "club_name": "Arsenal FC",       // always present — use this when club is not in clubs[]
    "league": "GB1",                 // league the player played in during player_season
    "pos": "Attack", "sub_pos": "Centre-Forward", "age": 24.3, "nat": "England",
    "foot": "right", "height": 185,
    "market_value": 80000000,
    "fair_value": 95000000,          // null if < 900 minutes
    "value_gap_pct": 0.19,           // (fair - market) / market; null if fair_value null
    "value_why": [{"f": "Goal involvements per 90", "effect_pct": 0.35}],
    "season": {"apps": 40, "minutes": 3200, "goals": 20, "assists": 8, "ga90": 0.79},
    "form": {"last5": [{"date": "2026-05-24", "opp": "…", "ga": 1, "min": 90}],
             "forecast_ga5": 3.1},   // forecast null if < 10 appearances or < 900 minutes
    "workload": {"index": 82, "band": "Heavy", "acwr": 1.21, "season_minutes": 4100,
                 "congested_apps": 12, "flag": true, "as_of": "2026-05-24"},  // null if no apps
    "value_history": [["2021-07-01", 20000000]],      // one point per year, oldest first
    "transfers": [{"date": "2023-07-01", "from": "…", "to": "…", "fee": 50000000}],
    "similar": [123, 456],           // same position group, nearest first
    "trend": {"score": 1.8, "reasons": ["5 G/A last 5"]}  // score null if < 900 min
  }],
  "models": { /* contents of metrics.json — shown on the in-app "How this works" sheet */ }
}
```

Money is whole EUR (integers). "Not enough data" is judged on total minutes in `player_season`
(< 900 → `fair_value`, `forecast_ga5`, `trend.score` null and `trend.reasons` empty). Dates are ISO `YYYY-MM-DD`, timestamps ISO UTC with `Z`. `null` always means
"not enough data" — the app must render a friendly empty state, never `0`.
