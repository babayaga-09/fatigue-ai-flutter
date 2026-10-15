"""FPL team names → Transfermarkt club ids, so FPL fixtures can use our Elo and match model.

An explicit table rather than fuzzy matching: there are only ~30 clubs, ids never change, and a
wrong match would silently misprice every fixture."""

FPL_TO_TM: dict[str, int] = {
    "Arsenal": 11, "Aston Villa": 405, "Bournemouth": 989, "Brentford": 1148,
    "Brighton": 1237, "Burnley": 1132, "Chelsea": 631, "Crystal Palace": 873,
    "Everton": 29, "Fulham": 931, "Ipswich": 677, "Leeds": 399, "Leicester": 1003,
    "Liverpool": 31, "Luton": 1031, "Man City": 281, "Man Utd": 985, "Newcastle": 762,
    "Norwich": 1123, "Nott'm Forest": 703, "Sheffield Utd": 350, "Southampton": 180,
    "Spurs": 148, "Sunderland": 289, "Watford": 1010, "West Brom": 984, "West Ham": 379,
    "Wolves": 543, "Middlesbrough": 641, "Hull": 3008, "Stoke": 512, "Swansea": 2288,
    "Cardiff": 603, "Huddersfield": 1110, "QPR": 1039, "Reading": 1032, "Wigan": 1071,
    # the live API sometimes uses full names for newly promoted clubs
    "Coventry City": 990, "Coventry": 990, "Hull City": 3008, "Ipswich Town": 677,
}


class UnmappedTeam(KeyError):
    pass


def club_id(fpl_name: str) -> int:
    try:
        return FPL_TO_TM[fpl_name]
    except KeyError:
        raise UnmappedTeam(f"no Transfermarkt club for FPL team {fpl_name!r}; add it to "
                           "touchline/fpl/teams.py") from None
