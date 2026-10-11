"""F4 — career curve: a GRU reads a player's last six seasons and forecasts his market value
one, two and three seasons ahead as 10th/50th/90th percentiles (pinball loss). The baseline is
the empirical ageing curve: median value change by position and age."""
from dataclasses import dataclass

import numpy as np
import pandas as pd
import torch
from torch import nn

from touchline.features.players import POS_GROUPS

H, LMAX = 3, 6
QS = (0.1, 0.5, 0.9)
_BASE = 7  # rel log value, abs log value, age, minutes, ga90, has stats, present
F = _BASE + len(POS_GROUPS)
_POS = {p: i for i, p in enumerate(POS_GROUPS)}


def yearly_panel(valuations, players, stats) -> pd.DataFrame:
    v = valuations[valuations.value > 0].copy()
    d = pd.to_datetime(v.date)
    v["season"] = np.where(d.dt.month >= 7, d.dt.year, d.dt.year - 1)
    v = v.assign(date=d).sort_values("date").groupby(["player_id", "season"]).tail(1)
    v["log_value"] = np.log(v.value.astype(float))
    v = v.merge(players[["player_id", "dob", "position"]], on="player_id", how="left")
    ref = pd.to_datetime((v.season + 1).astype(str) + "-07-01")
    v["age"] = (ref - pd.to_datetime(v.dob)).dt.days / 365.25
    st = stats[["player_id", "season", "minutes", "ga90"]]
    v = v.merge(st, on=["player_id", "season"], how="left")
    v["has_stats"] = v.minutes.notna().astype(float)
    return v[["player_id", "season", "log_value", "age", "position", "minutes", "ga90",
              "has_stats"]].reset_index(drop=True)


@dataclass
class CareerData:
    x: np.ndarray
    y: np.ndarray
    last: np.ndarray
    meta: pd.DataFrame

    def subset(self, mask) -> "CareerData":
        mask = np.asarray(mask)
        return CareerData(self.x[mask], self.y[mask], self.last[mask],
                          self.meta[mask].reset_index(drop=True))


def build(panel, ends, need_targets=True, ids=None, min_log_value=None) -> CareerData:
    ends = sorted(set(int(e) for e in ends))
    xs, ys, lasts, metas = [], [], [], []
    cols = ["season", "log_value", "age", "position", "minutes", "ga90", "has_stats"]
    for pid, g in panel.groupby("player_id", sort=True):
        if ids is not None and pid not in ids:
            continue
        rec = {int(r[0]): r[1:] for r in g[cols].itertuples(index=False)}
        for e in ends:
            if e not in rec:
                continue
            lv0, age0, pos0 = rec[e][0], rec[e][1], rec[e][2]
            if min_log_value is not None and lv0 < min_log_value:
                continue
            fut = [rec[e + h][0] if (e + h) in rec else np.nan for h in range(1, H + 1)]
            if need_targets and np.isnan(fut).any():
                continue
            x = np.zeros((LMAX, F), np.float32)
            for i, s in enumerate(range(e - LMAX + 1, e + 1)):
                if s not in rec:
                    continue
                lv, age, pos, mins, ga90, has = rec[s]
                x[i, :_BASE] = [lv - lv0, (lv - 14.0) / 2.0,
                                ((age if age == age else 26.0) - 26.0) / 5.0,
                                (mins if mins == mins else 0.0) / 3000.0,
                                ga90 if ga90 == ga90 else 0.0, has, 1.0]
                if pos in _POS:
                    x[i, _BASE + _POS[pos]] = 1.0
            xs.append(x)
            ys.append(np.array(fut, np.float32) - lv0)
            lasts.append(lv0)
            metas.append({"player_id": pid, "end": e, "age": age0, "position": pos0})
    meta = pd.DataFrame(metas, columns=["player_id", "end", "age", "position"])
    return CareerData(np.asarray(xs, np.float32).reshape(-1, LMAX, F),
                      np.asarray(ys, np.float32).reshape(-1, H),
                      np.asarray(lasts, np.float32), meta)


class CareerGRU(nn.Module):
    def __init__(self, f: int = F, hidden: int = 32):
        super().__init__()
        self.gru = nn.GRU(f, hidden, batch_first=True)
        self.head = nn.Sequential(nn.Linear(hidden, 32), nn.ReLU(), nn.Linear(32, H * len(QS)))

    def forward(self, x):
        _, h = self.gru(x)
        return self.head(h[-1]).view(-1, H, len(QS))


def _pinball(pred, y):
    q = torch.tensor(QS).view(1, 1, -1)
    e = y.unsqueeze(-1) - pred
    return torch.maximum(q * e, (q - 1) * e).mean()


def _age_bucket(age):
    return np.clip(np.round(np.nan_to_num(np.asarray(age, float), nan=26.0)), 17, 38)


@dataclass
class CareerModel:
    gru: CareerGRU
    curve: dict
    global_med: np.ndarray

    def predict(self, d: CareerData) -> np.ndarray:
        if len(d.y) == 0:
            return np.zeros((0, H, len(QS)))
        self.gru.eval()
        with torch.no_grad():
            out = self.gru(torch.from_numpy(d.x)).numpy()
        return np.sort(out, axis=2)

    def curve_delta(self, meta: pd.DataFrame) -> np.ndarray:
        ages = _age_bucket(meta.age)
        return np.array([self.curve.get((p, a), self.global_med)
                         for p, a in zip(meta.position, ages, strict=True)]).reshape(-1, H)


def _curve(d: CareerData) -> tuple[dict, np.ndarray]:
    df = d.meta.assign(bucket=_age_bucket(d.meta.age))
    out = {}
    for (pos, b), idx in df.groupby(["position", "bucket"]).groups.items():
        if len(idx) >= 20:
            out[(pos, b)] = np.median(d.y[np.asarray(idx)], axis=0)
    return out, np.median(d.y, axis=0)


def run_career(panel, test_end: int, epochs: int = 30, seed: int = 0,
               batch: int = 512, patience: int = 3) -> tuple[CareerModel, dict]:
    floor = np.log(200_000)
    train = build(panel, range(2012, test_end - 5), min_log_value=floor)
    val = build(panel, [test_end - 3], min_log_value=floor)
    test = build(panel, [test_end], min_log_value=floor)
    # Target windows never overlap: train targets <= test_end-3 < val targets <= test_end
    # < test targets.
    if len(train.y) == 0 or len(val.y) == 0 or len(test.y) == 0:
        raise ValueError("career split produced an empty set")
    torch.manual_seed(seed)
    gru = CareerGRU()
    opt = torch.optim.Adam(gru.parameters(), lr=1e-3)
    tx, ty = torch.from_numpy(train.x), torch.from_numpy(train.y)
    vx, vy = torch.from_numpy(val.x), torch.from_numpy(val.y)
    best, state, bad = np.inf, None, 0
    gen = torch.Generator().manual_seed(seed)
    for _ in range(epochs):
        gru.train()
        perm = torch.randperm(len(ty), generator=gen)
        for i in range(0, len(ty), batch):
            idx = perm[i:i + batch]
            opt.zero_grad()
            loss = _pinball(gru(tx[idx]), ty[idx])
            loss.backward()
            opt.step()
        gru.eval()
        with torch.no_grad():
            v = float(_pinball(gru(vx), vy))
        if v < best - 1e-5:
            best, state, bad = v, {k: t.clone() for k, t in gru.state_dict().items()}, 0
        else:
            bad += 1
            if bad >= patience:
                break
    gru.load_state_dict(state)
    curve, med = _curve(train)
    model = CareerModel(gru, curve, med)
    q = model.predict(test)
    base = model.curve_delta(test.meta)
    m = {"n_train": int(len(train.y)), "n_test": int(len(test.y)), "test_end": int(test_end)}
    for h in range(H):
        m[f"mae_h{h + 1}"] = float(np.mean(np.abs(q[:, h, 1] - test.y[:, h])))
        m[f"baseline_mae_h{h + 1}"] = float(np.mean(np.abs(base[:, h] - test.y[:, h])))
        m[f"coverage_h{h + 1}"] = float(np.mean((test.y[:, h] >= q[:, h, 0])
                                                & (test.y[:, h] <= q[:, h, 2])))
    return model, m
