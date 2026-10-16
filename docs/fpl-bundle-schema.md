# FPL bundle (`fpl-bundle.json.gz`), schema 1

Written by `python -m touchline.fpl.run_fpl`, refreshed daily (live FPL data, saved model) and
retrained weekly. Published beside the main bundle on the `data-latest` release and served next to
the web build at `data/fpl-bundle.json.gz`.

```jsonc
{
  "fpl_schema_version": 1,
  "generated_at": "2026-10-16T06:00:00Z",
  "season": "2026-27",
  "source": "ours",            // "ours" = Touchline's model passed its gate; "fpl" = FPL's ep_next shipped
  "next_gw": 8,                // first gameweek whose deadline is still ahead
  "gameweeks": [{"id": 8, "name": "Gameweek 8", "deadline": "2026-10-24T10:00:00Z"}],  // horizon, up to 6
  "teams": [{"id": 1, "name": "Arsenal", "short": "ARS", "club_id": 11}],               // club_id = Touchline/Transfermarkt id
  "players": [{
    "id": 427, "name": "Saka", "full": "Bukayo Saka", "team": 1, "pos": "MID",
    "price": 103,              // tenths of £m (103 = £10.3m)
    "status": "a",             // FPL: a available, d doubtful, i injured, s suspended, u unavailable, n not in squad
    "news": null, "chance": null,   // chance of playing next round (0-100) when flagged
    "sel": 41.2,               // selected by %
    "p_play": 0.93,            // P(any minutes) in the next gameweek
    "xpts": [6.1, 5.4, 4.9, 5.8, 5.2, 4.7],   // expected points per horizon gameweek (0 = blank)
    "why": {"minutes": 1.8, "attack": 2.9, "defence": 0.4, "bonus": 0.6, "other": 0.4}  // next gameweek; null when source = "fpl"
  }],
  "wildcard": [{"budget": 1000, "squad": [/* 15 player ids */]}],               // budgets 950-1100 step 10
  "free_hit": [{"gw": 8, "budget": 1000, "squad": [/* 15 player ids */]}],    // per horizon gameweek × budget
  "models": { /* contents of fpl_metrics.json: evaluation vs FPL's xP */ }
}
```

The app picks the Wildcard / Free Hit squad for the largest grid budget within the manager's
squad value plus bank; if every grid squad costs more, it shows the cheapest one, flagged.
