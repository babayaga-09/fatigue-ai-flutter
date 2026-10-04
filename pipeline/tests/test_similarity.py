import pandas as pd

from touchline.models.similarity import similar_players


def test_nearest_is_the_lookalike_and_same_position():
    df = pd.DataFrame({
        "player_id": [1, 2, 3, 4], "position": ["Attack", "Attack", "Attack", "Defender"],
        "sub_position": ["Centre-Forward", "Centre-Forward", "Left Winger", "Centre-Back"],
        "g90": [0.8, 0.78, 0.1, 0.8], "a90": [0.2, 0.21, 0.5, 0.2],
        "minutes_share": [0.9, 0.88, 0.5, 0.9], "yellow90": [0.1, 0.1, 0.2, 0.1],
        "age": [25, 25.5, 30, 25], "club_elo": [1700, 1690, 1500, 1700]})
    sim = similar_players(df, k=2)
    assert sim[1][0] == 2
    assert 4 not in sim[1] and 1 not in sim[1]
    assert sim[4] == []  # alone in its position group
