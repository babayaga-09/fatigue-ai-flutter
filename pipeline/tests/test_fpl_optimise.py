import itertools

import pytest

from touchline.fpl.optimise import (
    Player,
    best_xi,
    chip_advice,
    pick_grid,
    sell_price,
    solve_squad,
    suggest_transfers,
)


def _squad():
    s, i = [], 0
    for pos, n in [("GK", 2), ("DEF", 5), ("MID", 5), ("FWD", 3)]:
        for _ in range(n):
            i += 1
            s.append(Player(i, pos, team=i % 8, price=50))
    return s


def test_best_xi_respects_formation():
    sq = _squad()
    pts = {p.id: (10 if p.pos == "DEF" else 1) for p in sq}  # 5 strong defenders
    x = best_xi(sq, pts)
    pos = [next(p.pos for p in sq if p.id == i) for i in x.xi]
    assert len(x.xi) == 11 and pos.count("GK") == 1
    assert pos.count("DEF") == 5 and pos.count("MID") >= 2 and pos.count("FWD") >= 1
    assert x.captain != x.vice and x.points == pytest.approx(5 * 10 + 6 * 1 + 10)
    assert x.bench[0] in [p.id for p in sq if p.pos == "GK"]  # bench keeper first


def test_sell_price_half_profit_rounded_down():
    assert sell_price(50, 53) == 51
    assert sell_price(50, 54) == 52
    assert sell_price(50, 47) == 47


def _pool(squad, extra):
    return squad + extra


def test_club_limit_and_budget_respected():
    sq = _squad()
    star_team = 99
    # three owned players already from team 99 -> a fourth cannot come in
    sq = [Player(p.id, p.pos, star_team if p.id in (3, 4, 5) else p.team, p.price) for p in sq]
    pricey = Player(100, "MID", 7, 200)
    blocked = Player(101, "MID", star_team, 50)
    ok = Player(102, "MID", 6, 55)
    horizon = [{100: 20.0, 101: 15.0, 102: 6.0} for _ in range(5)]
    sell = {p.id: p.price for p in sq}
    plans = suggest_transfers(sq, sell, bank=10, free_transfers=1,
                              pool=_pool(sq, [pricey, blocked, ok]), horizon=horizon)
    ins = {t[1] for p in plans for t in p.transfers}
    assert 100 not in ins and 101 not in ins and 102 in ins


def test_hit_suggested_only_when_gain_beats_hit_plus_margin():
    sq = _squad()
    sell = {p.id: p.price for p in sq}
    small = [Player(200, "FWD", 7, 50), Player(201, "MID", 6, 50)]
    owned = {p.id: 3.0 for p in sq}
    tiny = [{**owned, 200: 3.2, 201: 3.2} for _ in range(5)]  # +1 point each over 5 gameweeks
    plans = suggest_transfers(sq, sell, 0, 1, sq + small, tiny)
    two = [p for p in plans if len(p.transfers) == 2][0]
    assert two.hits == 4 and not two.worth_it
    big = [{**owned, 200: 9.0, 201: 9.0} for _ in range(5)]
    two = [p for p in suggest_transfers(sq, sell, 0, 1, sq + small, big)
           if len(p.transfers) == 2][0]
    assert two.worth_it and two.gain > 5


def test_solve_squad_is_legal_and_beats_greedy():
    pool = []
    i = 0
    for pos, n in [("GK", 4), ("DEF", 10), ("MID", 10), ("FWD", 6)]:
        for k in range(n):
            i += 1
            pool.append(Player(i, pos, team=i % 10, price=40 + (k * 7) % 70))
    weight = {p.id: p.price / 10 + (p.id % 5) for p in pool}
    ids = solve_squad(pool, 1000, weight)
    picked = [p for p in pool if p.id in ids]
    assert len(picked) == 15 and sum(p.price for p in picked) <= 1000
    for pos, n in [("GK", 2), ("DEF", 5), ("MID", 5), ("FWD", 3)]:
        assert sum(p.pos == pos for p in picked) == n
    assert max(sum(p.team == t for p in picked) for t in range(10)) <= 3
    # greedy by points-per-price is never better on starters
    greedy = sorted(pool, key=lambda p: -weight[p.id] / p.price)
    chosen, left = [], 1000
    need = {"GK": 2, "DEF": 5, "MID": 5, "FWD": 3}
    for p in greedy:
        if need[p.pos] and p.price <= left and sum(q.team == p.team for q in chosen) < 3:
            chosen.append(p)
            need[p.pos] -= 1
            left -= p.price
    if len(chosen) == 15:
        assert best_xi(picked, weight).points >= best_xi(chosen, weight).points - 1e-9


def test_budget_below_grid_returns_cheapest_flagged():
    grid = [{"budget": 950, "squad": [1]}, {"budget": 1000, "squad": [2]}]
    assert pick_grid(grid, 990) == (grid[0], False)
    assert pick_grid(grid, 900) == (grid[0], True)


def test_used_chips_are_never_advised():
    sq = _squad()
    horizon = [{p.id: 2.0 for p in sq} for _ in range(3)]
    adv = chip_advice(sq, horizon, [7, 8, 9], 100.0, 130.0, {7: 80.0},
                      chips_available={"bboost"})
    assert set(adv) == {"bboost"}
    adv = chip_advice(sq, horizon, [7, 8, 9], 100.0, 130.0, {7: 80.0},
                      chips_available={"wildcard", "freehit", "3xc", "bboost"})
    assert adv["wildcard"]["recommend"] and adv["freehit"]["recommend"]


def test_formations_cover_all_legal_shapes():
    from touchline.fpl.optimise import FORMATIONS
    legal = {(d, m, f) for d, m, f in itertools.product(range(3, 6), range(2, 6), range(1, 4))
             if d + m + f == 10}
    assert set(FORMATIONS) == legal


def test_golden_cases_are_deterministic_and_complete():
    from touchline.fpl.optimise import golden_cases
    a, b = golden_cases(), golden_cases()
    assert a == b and len(a) == 3
    assert all(len(c["plans"]) == 3 and len(c["best_xi"]["xi"]) == 11 for c in a)
