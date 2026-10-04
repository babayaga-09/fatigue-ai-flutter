import pandas as pd

from touchline.ingest.club_map import map_clubs, norm_tokens, similarity


def test_norm_tokens_strips_noise_and_accents():
    assert norm_tokens("Club Atlético de Madrid") == ["atletico", "madrid"]
    assert norm_tokens("1. FSV Mainz 05") == ["mainz"]


def test_similarity_prefers_exact_over_subset():
    assert similarity("Paris Saint-Germain FC", "Paris Saint-Germain") > \
        similarity("Paris Saint-Germain FC", "Paris FC")


def test_map_real_names_one_to_one():
    fd = pd.DataFrame([
        (524, "Paris Saint-Germain FC", "PSG", "FR1"), (1045, "Paris FC", "Paris FC", "FR1"),
        (98, "AC Milan", "Milan", "IT1"), (108, "FC Internazionale Milano", "Inter", "IT1"),
        (110, "SS Lazio", "Lazio", "IT1"), (5, "FC Bayern München", "Bayern", "L1"),
        (77, "Athletic Club", "Athletic", "ES1"), (1076, "Coventry City FC", "Coventry City", "GB1"),
    ], columns=["fd_id", "name", "short", "tm_league"])
    tm = pd.DataFrame([
        (583, "Paris Saint-Germain", "FR1"), (10004, "Paris FC", "FR1"),
        (5, "AC Milan", "IT1"), (46, "Inter Milan", "IT1"),
        (398, "Società Sportiva Lazio S.p.A.", "IT1"), (27, "Bayern Munich", "L1"),
        (621, "Athletic Bilbao", "ES1"), (603, "Cardiff City", "GB1"), (1003, "Leicester City", "GB1"),
    ], columns=["club_id", "name", "league"])
    m = map_clubs(fd, tm, overrides={})
    assert m == {524: 583, 1045: 10004, 98: 5, 108: 46, 110: 398, 5: 27, 77: 621}
    assert 1076 not in m  # Coventry is new to the dataset


def test_overrides_win():
    fd = pd.DataFrame([(1, "Foo", "Foo", "GB1")], columns=["fd_id", "name", "short", "tm_league"])
    tm = pd.DataFrame([(9, "Bar", "GB1")], columns=["club_id", "name", "league"])
    assert map_clubs(fd, tm, overrides={1: 9}) == {1: 9}
