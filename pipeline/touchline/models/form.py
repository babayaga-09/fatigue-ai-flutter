"""M5 — goal-involvement forecast over the next 5 appearances.

A GRU reads the last 10 appearances (minutes, goals, assists, cards, rest, venue, club and
opponent strength) plus static position/age, and outputs a Poisson rate. It is compared on
validation with a Poisson GLM on rolling averages; the better one is used for the app."""
from dataclasses import dataclass

import numpy as np
import pandas as pd
import torch
from sklearn.linear_model import PoissonRegressor
from sklearn.metrics import mean_absolute_error, mean_poisson_deviance
from torch import nn

from touchline.features.players import POS_GROUPS

SEQ_FEATS = ["m90", "goals", "assists", "yellow", "red", "rest", "is_home", "own_elo", "opp_elo"]
L, H = 10, 5
_GA = (SEQ_FEATS.index("goals"), SEQ_FEATS.index("assists"))


def appearance_features(eapps: pd.DataFrame, pre: pd.DataFrame) -> pd.DataFrame:
    df = eapps.merge(pre, on="game_id", how="left")
    home = df["is_home"] >= 1
    df["own_elo"] = np.where(home, df["elo_home"], df["elo_away"])
    df["opp_elo"] = np.where(home, df["elo_away"], df["elo_home"])
    df[["own_elo", "opp_elo"]] = (df[["own_elo", "opp_elo"]].fillna(1500.0) - 1500.0) / 200.0
    df["m90"] = df["minutes"] / 90.0
    df = df.sort_values(["player_id", "date", "game_id"]).reset_index(drop=True)
    df["rest"] = df.groupby("player_id")["date"].diff().dt.days.fillna(30).clip(0, 30) / 30.0
    df["ga"] = df["goals"] + df["assists"]
    df["yellow"] = df["yellow_cards"]
    df["red"] = df["red_cards"]
    return df


@dataclass
class SeqData:
    seq: np.ndarray
    static: np.ndarray
    y: np.ndarray
    end_date: np.ndarray
    player_id: np.ndarray

    def subset(self, mask) -> "SeqData":
        mask = np.asarray(mask)
        return SeqData(self.seq[mask], self.static[mask], self.y[mask], self.end_date[mask],
                       self.player_id[mask])

    def __len__(self):
        return len(self.y)


def _static(position, dob, when) -> list[float]:
    age = (pd.Timestamp(when) - dob).days / 365.25 if pd.notna(dob) else 26.0
    return [float(position == p) for p in POS_GROUPS] + [(age - 26.0) / 5.0]


def _collect(feats, players, ids, windows_fn) -> SeqData:
    meta = players.set_index("player_id")[["position", "dob"]]
    seqs, stats, ys, ends, pids = [], [], [], [], []
    for pid, g in feats[feats.player_id.isin(ids)].groupby("player_id", sort=True):
        x = g[SEQ_FEATS].to_numpy(np.float32)
        ga = g["ga"].to_numpy(np.float32)
        dates = g["date"].to_numpy()
        pos = meta.position.get(pid) if pid in meta.index else None
        dob = meta.dob.get(pid) if pid in meta.index else pd.NaT
        for e, target in windows_fn(len(g), ga):
            seqs.append(x[e - L:e])
            stats.append(_static(pos, dob, dates[e - 1]))
            ys.append(target)
            ends.append(dates[e - 1])
            pids.append(pid)
    n_s = len(POS_GROUPS) + 1
    return SeqData(np.asarray(seqs, np.float32).reshape(-1, L, len(SEQ_FEATS)),
                   np.asarray(stats, np.float32).reshape(-1, n_s), np.asarray(ys, np.float32),
                   np.asarray(ends, dtype="datetime64[ns]"), np.asarray(pids))


def build_sequences(feats, players, pool_ids, stride: int = 5) -> SeqData:
    def windows(n, ga):
        return [(e, float(ga[e:e + H].sum())) for e in range(L, n - H + 1, stride)]
    return _collect(feats, players, pool_ids, windows)


def latest_windows(feats, players, ids) -> SeqData:
    def windows(n, ga):
        return [(n, np.nan)] if n >= L else []
    return _collect(feats, players, ids, windows)


class FormGRU(nn.Module):
    def __init__(self, n_feat: int, n_static: int, hidden: int = 32):
        super().__init__()
        self.gru = nn.GRU(n_feat, hidden, batch_first=True)
        self.head = nn.Sequential(nn.Linear(hidden + n_static, 32), nn.ReLU(), nn.Linear(32, 1))

    def forward(self, seq, static):
        _, h = self.gru(seq)
        return self.head(torch.cat([h[-1], static], dim=1)).squeeze(1)  # log-rate


def _glm_x(d: SeqData) -> np.ndarray:
    ga = d.seq[:, :, _GA[0]] + d.seq[:, :, _GA[1]]
    return np.column_stack([ga.mean(1), ga[:, -5:].mean(1), d.seq[:, :, 0].mean(1), d.static])


@dataclass
class FormForecaster:
    kind: str
    gru: FormGRU | None = None
    glm: PoissonRegressor | None = None

    def predict(self, d: SeqData) -> np.ndarray:
        if len(d) == 0:
            return np.zeros(0)
        if self.kind == "gru":
            self.gru.eval()
            with torch.no_grad():
                out = self.gru(torch.from_numpy(d.seq), torch.from_numpy(d.static))
            return np.exp(out.numpy()).astype(float)
        return self.glm.predict(_glm_x(d))


def _naive(d: SeqData) -> np.ndarray:
    ga = d.seq[:, :, _GA[0]] + d.seq[:, :, _GA[1]]
    return np.clip(ga.mean(1) * H, 1e-3, None)


def _train_gru(train: SeqData, val: SeqData, epochs, seed, batch=512, patience=2) -> FormGRU:
    torch.manual_seed(seed)
    model = FormGRU(train.seq.shape[2], train.static.shape[1])
    opt = torch.optim.Adam(model.parameters(), lr=1e-3)
    loss_fn = nn.PoissonNLLLoss(log_input=True)
    tx, ts, ty = map(torch.from_numpy, (train.seq, train.static, train.y))
    vx, vs, vy = map(torch.from_numpy, (val.seq, val.static, val.y))
    best, best_state, bad = np.inf, None, 0
    gen = torch.Generator().manual_seed(seed)
    for _ in range(epochs):
        model.train()
        perm = torch.randperm(len(ty), generator=gen)
        for i in range(0, len(ty), batch):
            idx = perm[i:i + batch]
            opt.zero_grad()
            loss = loss_fn(model(tx[idx], ts[idx]), ty[idx])
            loss.backward()
            opt.step()
        model.eval()
        with torch.no_grad():
            v = float(loss_fn(model(vx, vs), vy))
        if v < best - 1e-5:
            best, best_state, bad = v, {k: t.clone() for k, t in model.state_dict().items()}, 0
        else:
            bad += 1
            if bad >= patience:
                break
    model.load_state_dict(best_state)
    return model


def run_form(data: SeqData, val_start, test_start, epochs: int = 15,
             seed: int = 0) -> tuple[FormForecaster, dict]:
    vs, ts = np.datetime64(val_start, "ns"), np.datetime64(test_start, "ns")
    train = data.subset(data.end_date < vs)
    val = data.subset((data.end_date >= vs) & (data.end_date < ts))
    test = data.subset(data.end_date >= ts)
    assert train.end_date.max() < vs and val.end_date.max() < ts

    gru = FormForecaster("gru", gru=_train_gru(train, val, epochs, seed))
    glm = FormForecaster("poisson_glm",
                         glm=PoissonRegressor(alpha=1e-4, max_iter=500).fit(_glm_x(train),
                                                                            train.y))

    def dev(pred, d):
        return float(mean_poisson_deviance(d.y, np.clip(pred, 1e-6, None)))

    chosen = gru if dev(gru.predict(val), val) <= dev(glm.predict(val), val) else glm
    pg, pl, pn = gru.predict(test), glm.predict(test), _naive(test)
    metrics = {"n_train": len(train), "n_val": len(val), "n_test": len(test),
               "gru_poisson_deviance": dev(pg, test), "glm_poisson_deviance": dev(pl, test),
               "naive_poisson_deviance": dev(pn, test),
               "gru_mae": float(mean_absolute_error(test.y, pg)),
               "glm_mae": float(mean_absolute_error(test.y, pl)),
               "naive_mae": float(mean_absolute_error(test.y, pn)),
               "chosen": chosen.kind}
    key = "gru" if chosen.kind == "gru" else "glm"
    metrics["poisson_deviance"] = metrics[f"{key}_poisson_deviance"]
    metrics["baseline_poisson_deviance"] = metrics["naive_poisson_deviance"]
    return chosen, metrics
