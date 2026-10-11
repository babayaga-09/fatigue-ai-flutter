"""Trending score: recent output vs own baseline, market-value momentum, and forecast."""
import numpy as np
import pandas as pd


def _z(s: pd.Series) -> pd.Series:
    sd = s.std(ddof=0)
    return (s - s.mean()) / sd if sd and sd > 0 else s * 0.0


def _reasons(r) -> list[str]:
    out = []
    if r.last5_ga >= 3:
        out.append(f"{int(r.last5_ga)} goal involvements in last 5")
    if (pd.notna(r.value_change_pct) and r.value_change_pct >= 0.10
            and r.value_change >= 250_000):
        m = r.value_change / 1e6
        out.append(f"Value up €{m:.0f}M" if m >= 10 else f"Value up €{m:.1f}M")
    if pd.notna(r.forecast_ga5) and r.forecast_ga5 >= 2.0:
        out.append(f"Projected {r.forecast_ga5:.1f} G/A next 5")
    return out[:2]


def trending(df: pd.DataFrame, min_minutes: int = 900) -> pd.DataFrame:
    d = df.copy()
    d["last5_ga"] = d["last5_ga"].fillna(0)
    d["last5_minutes"] = d["last5_minutes"].fillna(0)
    last5_ga90 = np.where(d.last5_minutes >= 200,
                          d.last5_ga / d.last5_minutes.clip(lower=1) * 90, d.ga90)
    d["form_delta"] = last5_ga90 - d.ga90
    d["value_change"] = d.value_now - d.value_6m_ago
    d["value_change_pct"] = d.value_change / d.value_6m_ago.where(d.value_6m_ago > 0)
    ok = d.minutes >= min_minutes
    e = d[ok]
    score = (0.4 * _z(e.form_delta.fillna(0)) + 0.3 * _z(e.value_change_pct.fillna(0))
             + 0.3 * _z(e.forecast_ga5.fillna(0)))
    d["trend_score"] = np.nan
    d.loc[ok, "trend_score"] = score
    d["reasons"] = [_reasons(r) if q else []
                    for r, q in zip(d.itertuples(index=False), ok, strict=True)]
    return d[["player_id", "trend_score", "reasons"]]
