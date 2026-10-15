"""FPL decisions: best XI, transfers with hit maths, the best squad for a budget, chip advice.

Transfers (0-2 moves) are searched exhaustively over a deterministic candidate list, so the
app's Dart port can reproduce the same answers exactly. Whole squads (Wildcard, Free Hit) are
an integer programme solved here and shipped in the bundle."""
from dataclasses import dataclass, field

import numpy as np
from scipy.optimize import Bounds, LinearConstraint, milp

SQUAD = {"GK": 2, "DEF": 5, "MID": 5, "FWD": 3}
XI_MIN = {"GK": 1, "DEF": 3, "MID": 2, "FWD": 1}
XI_MAX = {"GK": 1, "DEF": 5, "MID": 5, "FWD": 3}
CLUB_LIMIT = 3
HIT = 4
HIT_MARGIN = 1.0
BENCH_WEIGHT = 0.1
CANDIDATES_PER_POS = 25
DOUBLE_POOL = 40
FORMATIONS = [(d, m, 10 - d - m) for d in range(3, 6) for m in range(2, 6)
              if 1 <= 10 - d - m <= 3]


@dataclass(frozen=True)
class Player:
    id: int
    pos: str
    team: int
    price: int  # tenths of £m


@dataclass
class XI:
    xi: list[int]
    bench: list[int]
    captain: int
    vice: int
    points: float          # XI with the captain doubled
    bench_points: float


def best_xi(squad: list[Player], pts: dict[int, float]) -> XI:
    by = {p: sorted((q for q in squad if q.pos == p), key=lambda q: (-pts.get(q.id, 0.0), q.id))
          for p in SQUAD}
    best = None
    for d, m, f in FORMATIONS:
        pick = by["GK"][:1] + by["DEF"][:d] + by["MID"][:m] + by["FWD"][:f]
        total = sum(pts.get(q.id, 0.0) for q in pick)
        if best is None or total > best[0] + 1e-12:
            best = (total, pick)
    total, pick = best
    ids = {q.id for q in pick}
    outfield_bench = sorted((q for q in squad if q.id not in ids and q.pos != "GK"),
                            key=lambda q: (-pts.get(q.id, 0.0), q.id))
    gk_bench = [q for q in by["GK"][1:]]
    ranked = sorted(pick, key=lambda q: (-pts.get(q.id, 0.0), q.id))
    cap, vice = ranked[0].id, ranked[1].id
    bench = [q.id for q in gk_bench + outfield_bench]
    return XI([q.id for q in pick], bench, cap, vice, total + pts.get(cap, 0.0),
              sum(pts.get(i, 0.0) for i in bench))


def sell_price(buy: int, now: int) -> int:
    """FPL keeps half of any rise (rounded down to £0.1m); falls are passed on in full."""
    return buy + (now - buy) // 2 if now > buy else now


def horizon_value(squad: list[Player], horizon: list[dict[int, float]]) -> float:
    total = 0.0
    for pts in horizon:
        x = best_xi(squad, pts)
        total += x.points + BENCH_WEIGHT * x.bench_points
    return total


@dataclass
class Plan:
    transfers: list[tuple[int, int]]  # (out id, in id)
    value: float
    gain: float = 0.0
    hits: int = 0
    worth_it: bool = False
    note: str = ""
    extra: dict = field(default_factory=dict)


def _legal(squad: list[Player]) -> bool:
    teams: dict[int, int] = {}
    for p in squad:
        teams[p.team] = teams.get(p.team, 0) + 1
    return max(teams.values()) <= CLUB_LIMIT


def suggest_transfers(squad: list[Player], sell: dict[int, int], bank: int,
                      free_transfers: int, pool: list[Player],
                      horizon: list[dict[int, float]], max_transfers: int = 2) -> list[Plan]:
    """Best plan with 0, 1 and 2 transfers. `sell` = selling price per owned player."""
    owned = {p.id for p in squad}
    total = {p.id: sum(h.get(p.id, 0.0) for h in horizon) for p in pool}
    cands = {pos: sorted((p for p in pool if p.pos == pos and p.id not in owned),
                         key=lambda p: (-total[p.id], p.id))[:CANDIDATES_PER_POS]
             for pos in SQUAD}
    base = horizon_value(squad, horizon)
    plans = [Plan([], base, 0.0, 0, True, "Roll the transfer")]

    singles = []
    for out in sorted(squad, key=lambda p: p.id):
        for new in cands[out.pos]:
            if bank + sell[out.id] < new.price:
                continue
            s = [new if p.id == out.id else p for p in squad]
            if _legal(s):
                singles.append((horizon_value(s, horizon), out, new))
    singles.sort(key=lambda t: (-t[0], t[1].id, t[2].id))
    if singles and max_transfers >= 1:
        v, out, new = singles[0]
        plans.append(_plan([(out.id, new.id)], v, base, free_transfers))
    if max_transfers >= 2:
        top = singles[:DOUBLE_POOL]
        best = None
        for i in range(len(top)):
            for j in range(i + 1, len(top)):
                (_, o1, n1), (_, o2, n2) = top[i], top[j]
                if o1.id == o2.id or n1.id == n2.id:
                    continue
                if bank + sell[o1.id] + sell[o2.id] < n1.price + n2.price:
                    continue
                s = [n1 if p.id == o1.id else n2 if p.id == o2.id else p for p in squad]
                if not _legal(s):
                    continue
                v = horizon_value(s, horizon)
                key = (v, -min(o1.id, o2.id))
                if best is None or key > best[0]:
                    best = (key, [(o1.id, n1.id), (o2.id, n2.id)], v)
        if best:
            plans.append(_plan(sorted(best[1]), best[2], base, free_transfers))
    return plans


def _plan(moves, value, base, free_transfers) -> Plan:
    hits = max(0, len(moves) - free_transfers) * HIT
    gain = value - base
    worth = gain - hits > (HIT_MARGIN if hits else 0.0)
    return Plan(moves, value, gain, hits, worth)


def solve_squad(pool: list[Player], budget: int, weight: dict[int, float],
                bench_weight: float = BENCH_WEIGHT) -> list[int]:
    """Best legal 15 under the budget: x = in squad, s = starts. Maximise starters' points plus
    a small bench value. Exact for one gameweek (Free Hit); for several gameweeks the XI is held
    fixed, a mild approximation for Wildcard planning."""
    n = len(pool)
    w = np.array([weight.get(p.id, 0.0) for p in pool])
    c = -np.concatenate([bench_weight * w, (1 - bench_weight) * w])  # x then s
    rows, lo, hi = [], [], []

    def add(coef_x, coef_s, lower, upper):
        rows.append(np.concatenate([coef_x, coef_s]))
        lo.append(lower)
        hi.append(upper)

    zero = np.zeros(n)
    price = np.array([p.price for p in pool], dtype=float)
    add(price, zero, 0, budget)
    for pos, k in SQUAD.items():
        m = np.array([p.pos == pos for p in pool], dtype=float)
        add(m, zero, k, k)
        add(zero, m, XI_MIN[pos], XI_MAX[pos])
    add(zero, np.ones(n), 11, 11)
    for t in sorted({p.team for p in pool}):
        add(np.array([p.team == t for p in pool], dtype=float), zero, 0, CLUB_LIMIT)
    eye = np.eye(n)
    for i in range(n):  # s_i <= x_i
        add(-eye[i], eye[i], -np.inf, 0)
    res = milp(c, constraints=LinearConstraint(np.array(rows), lo, hi),
               integrality=np.ones(2 * n), bounds=Bounds(0, 1))
    if not res.success:
        raise ValueError(f"no legal squad within budget {budget}")
    x = res.x[:n] > 0.5
    return sorted(p.id for p, keep in zip(pool, x, strict=True) if keep)


def chip_advice(squad: list[Player], horizon: list[dict[int, float]], gws: list[int],
                best_plan_value: float, wildcard_value: float | None,
                free_hit_points: dict[int, float], chips_available: set[str]) -> dict:
    """Numbers behind each chip; `recommend` only when the threshold is met."""
    xis = [best_xi(squad, pts) for pts in horizon]
    out = {}
    if "wildcard" in chips_available and wildcard_value is not None:
        gain = wildcard_value - best_plan_value
        out["wildcard"] = {"gw": gws[0], "gain": gain, "recommend": gain >= 12}
    if "freehit" in chips_available and free_hit_points:
        gains = {g: free_hit_points[g] - (x.points) for g, x in zip(gws, xis, strict=True)
                 if g in free_hit_points}
        g = max(gains, key=gains.get)
        out["freehit"] = {"gw": g, "gain": gains[g], "recommend": gains[g] >= 15}
    if "3xc" in chips_available:
        caps = {g: _cap_pts(x, h) for g, x, h in zip(gws, xis, horizon, strict=True)}
        g = max(caps, key=caps.get)
        out["3xc"] = {"gw": g, "gain": caps[g], "recommend": True}
    if "bboost" in chips_available:
        bench = {g: x.bench_points for g, x in zip(gws, xis, strict=True)}
        g = max(bench, key=bench.get)
        out["bboost"] = {"gw": g, "gain": bench[g], "recommend": True}
    return out


def _cap_pts(x: XI, pts: dict[int, float]) -> float:
    return pts.get(x.captain, 0.0)


def pick_grid(grid: list[dict], budget: int) -> tuple[dict, bool]:
    """The pre-solved squad for the largest grid budget within `budget`; if every grid squad
    costs more, the cheapest one, flagged as over budget."""
    fits = [g for g in grid if g["budget"] <= budget]
    if fits:
        return max(fits, key=lambda g: g["budget"]), False
    return min(grid, key=lambda g: g["budget"]), True


def golden_cases(seed: int = 7) -> list[dict]:
    """Deterministic squads, pools and horizons with the expected best XI and transfer plans.
    The Dart port must reproduce these exactly (tests/fixtures/fpl_cases.json)."""
    rng = np.random.default_rng(seed)
    cases = []
    for case in range(3):
        pool, i = [], 0
        for pos, n in [("GK", 5), ("DEF", 14), ("MID", 14), ("FWD", 9)]:
            for _ in range(n):
                i += 1
                pool.append(Player(i, pos, int(rng.integers(1, 13)), int(rng.integers(40, 130))))
        squad = []
        for pos, n in SQUAD.items():
            squad += [p for p in pool if p.pos == pos][:n]
        while not _legal(squad):  # reshuffle teams until the starting squad is legal
            squad = [Player(p.id, p.pos, int(rng.integers(1, 13)), p.price) for p in squad]
        ids = {p.id for p in squad}
        pool = [next((q for q in squad if q.id == p.id), p) for p in pool]
        horizon = [{p.id: round(float(rng.gamma(2.0, 1.6)), 2) for p in pool} for _ in range(5)]
        sell = {p.id: p.price - int(rng.integers(0, 3)) for p in squad}
        bank, ft = int(rng.integers(0, 40)), case % 3
        x = best_xi(squad, horizon[0])
        plans = suggest_transfers(squad, sell, bank, ft, pool, horizon)
        cases.append({
            "pool": [p.__dict__ for p in pool], "squad": sorted(ids), "sell": sell,
            "bank": bank, "free_transfers": ft, "horizon": horizon,
            "best_xi": {"xi": sorted(x.xi), "bench": x.bench, "captain": x.captain,
                        "vice": x.vice, "points": round(x.points, 6)},
            "plans": [{"transfers": p.transfers, "value": round(p.value, 6),
                       "hits": p.hits, "worth_it": p.worth_it} for p in plans],
        })
    return cases
