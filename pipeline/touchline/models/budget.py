"""M8 — transfer budget planner: choose signings maximising total quality within a budget.

Quality score = the valuator's performance-based fair value (EUR m), price = market value.
Solved exactly as a 0/1 integer programme; a greedy value-per-euro pick is the baseline."""
import numpy as np
import pandas as pd
from scipy.optimize import Bounds, LinearConstraint, milp


def plan_signings(cands: pd.DataFrame, budget: float, needs: dict[str, int]) -> list[int]:
    c = cands[cands.pos.isin(needs)].reset_index(drop=True)
    if c.empty:
        return []
    n = len(c)
    rows, lo, hi = [c.price.to_numpy(float)], [0.0], [float(budget)]
    for pos, count in needs.items():
        rows.append((c.pos == pos).to_numpy(float))
        lo.append(count)
        hi.append(count)
    res = milp(c=-c.score.to_numpy(float), integrality=np.ones(n),
               bounds=Bounds(0, 1), constraints=LinearConstraint(np.vstack(rows), lo, hi))
    if not res.success:
        return []
    return [int(p) for p, x in zip(c.player_id, res.x) if x > 0.5]


def greedy_signings(cands: pd.DataFrame, budget: float, needs: dict[str, int]) -> list[int]:
    left, spent, picked = dict(needs), 0.0, []
    c = cands[cands.pos.isin(needs)].assign(r=lambda d: d.score / d.price.clip(lower=0.1))
    for row in c.sort_values("r", ascending=False).itertuples(index=False):
        if left.get(row.pos, 0) > 0 and spent + row.price <= budget:
            picked.append(int(row.player_id))
            spent += row.price
            left[row.pos] -= 1
    return picked
