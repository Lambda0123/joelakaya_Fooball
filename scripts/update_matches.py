import json
import urllib.request
from datetime import datetime, timedelta, timezone

LEAGUES = {
    "caf": [
        ("africa.cup_of_nations", "CAF / CAN"),
        ("caf.champions", "CAF Champions League"),
        ("caf.confed", "CAF Confederation Cup"),
    ],
    "ucl": [
        ("uefa.champions", "UEFA Champions League"),
    ],
    "world": [
        ("fifa.world", "Coupe du Monde"),
    ],
    "extra": [
        ("fra.1", "France - Ligue 1"),
        ("esp.1", "Espagne - LaLiga"),
        ("ger.1", "Allemagne - Bundesliga"),
        ("eng.1", "Angleterre - Premier League"),
    ],
}

def get_json(url):
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 FootballMatchTracker",
            "Accept": "application/json",
        },
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def get_status(event):
    status = (event.get("status") or {}).get("type") or {}
    name = status.get("name", "")

    if (
        "IN_PROGRESS" in name
        or "HALFTIME" in name
        or "FIRST_HALF" in name
        or "SECOND_HALF" in name
        or "OVERTIME" in name
    ):
        return "LIVE"

    if "FINAL" in name:
        return "FINAL"

    return "UPCOMING"


def team_name(competitor):
    team = competitor.get("team") or {}

    return (
        team.get("displayName")
        or team.get("shortDisplayName")
        or team.get("name")
        or "Équipe"
    )


def team_score(competitor):
    try:
        return int(competitor.get("score"))
    except:
        return None


def main():

    now = datetime.now(timezone.utc)

    start = now - timedelta(days=2)
    end = now + timedelta(days=14)

    dates = f"{start:%Y%m%d}-{end:%Y%m%d}"

    matches = {}
    errors = []

    for category, leagues in LEAGUES.items():

        for league, competition_name in leagues:

            url = (
                "https://site.api.espn.com/apis/site/v2/sports/soccer/"
                + league
                + "/scoreboard?dates="
                + dates
            )

            try:

                data = get_json(url)

                for event in data.get("events", []):

                    competitions = event.get("competitions") or []

                    if not competitions:
                        continue

                    competition = competitions[0]

                    competitors = competition.get("competitors") or []

                    home = next(
                        (
                            c for c in competitors
                            if c.get("homeAway") == "home"
                        ),
                        None,
                    )

                    away = next(
                        (
                            c for c in competitors
                            if c.get("homeAway") == "away"
                        ),
                        None,
                    )

                    if not home or not away:
                        continue

                    status = get_status(event)

                    match = {
                        "id": str(event.get("id")),
                        "date": event.get("date"),
                        "home": team_name(home),
                        "away": team_name(away),
                        "homeScore": team_score(home),
                        "awayScore": team_score(away),
                        "competition": competition_name,
                        "category": (
                            category
                            if category in ["caf", "ucl", "world"]
                            else "extra"
                        ),
                        "status": status,
                        "statusLabel": {
                            "LIVE": "EN DIRECT",
                            "FINAL": "Terminé",
                            "UPCOMING": "À venir",
                        }[status],
                    }

                    matches[str(event.get("id"))] = match

            except Exception as error:

                errors.append(
                    f"{league}: {str(error)}"
                )

    result = {
        "generatedAt": now.isoformat(),
        "source": "ESPN public scoreboard API",
        "errors": errors,
        "matches": sorted(
            matches.values(),
            key=lambda x: x.get("date") or ""
        ),
    }

    with open(
        "matches.json",
        "w",
        encoding="utf-8"
    ) as file:

        json.dump(
            result,
            file,
            ensure_ascii=False,
            indent=2
        )

    print(
        f"{len(result['matches'])} matchs récupérés."
    )

    if errors:

        print("Erreurs rencontrées :")

        for error in errors:
            print("-", error)


if __name__ == "__main__":
    main()
