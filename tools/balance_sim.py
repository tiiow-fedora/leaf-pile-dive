"""Balance simulation for Leaf Pile Dive. Mirrors the numbers in src/shared/Config.luau
(keep them in sync by hand; DevTest checks a few of them in-game).

Model: the player swings the rake every SWING_S seconds. Each swing collects the leaves in
radius r. Leaf supply per yard is N leaves that respawn RESPAWN_S after pickup, so the
collection rate is capped by supply. Each leaf is worth yard.value * rake.mult * seasonMult
bag points. When the bag is full the player walks to the pile and dives from the best tower
level they can reach (climb time grows with height), then buys the best affordable upgrade
in a fixed priority. Prints the time each milestone is reached, free vs with 2x Leaves.
"""
import math

SWING_S = 0.55          # client swing cadence (server allows 3/s)
YARD_AREA = 100 * 100   # leaf field per yard (studs^2)
LEAVES_PER_YARD = 80
RESPAWN_S = 7.0
GOLDEN_CHANCE = 0.04    # golden leaf = 10x
GOLDEN_MULT = 10
WALK_TO_PILE_S = 5.0
CLIMB_S_PER_STUD = 0.28 # stairs: ~3.6 studs/s vertical
HEIGHT_DIV = 25.0       # dive mult = 1 + h / HEIGHT_DIV

RAKES = [  # name, cost, radius, mult
    ("Old Rake", 0, 7, 1), ("Garden Rake", 600, 8.5, 2), ("Wide Rake", 4800, 10, 4),
    ("Steel Rake", 32000, 11.5, 8), ("Golden Rake", 200000, 13, 16), ("Maple Rake", 1200000, 14.5, 32),
    ("Storm Rake", 7200000, 16, 64)]
BAGS = [  # name, cost, capacity
    ("Paper Bag", 0, 40), ("Sack", 150, 150), ("Wheelbarrow", 3600, 600), ("Leaf Cart", 24000, 2500),
    ("Trailer", 160000, 12000), ("Leaf Silo", 1040000, 60000), ("Mega Silo", 6400000, 300000)]
YARDS = [  # name, unlock cost, leaf value, tower height
    ("Backyard", 0, 1, 20), ("Park", 1500, 3, 30), ("Orchard", 20000, 8, 40),
    ("Pumpkin Patch", 144000, 20, 55), ("Maple Woods", 960000, 50, 70), ("Giant Oak", 6000000, 120, 90)]
SEASON_COST = lambda n: int(20_000_000 * (2 ** n))   # acorns needed for New Season n -> n+1
SEASON_BONUS = 0.5                                     # +50% leaf value per season


def leaves_per_swing(radius):
    # expected leaves inside the rake circle at the yard's steady-state density
    density = LEAVES_PER_YARD / YARD_AREA
    return density * math.pi * radius * radius * 1.8  # 1.8: players walk toward clusters


def run(leaves_mult=1.0, minutes=240, verbose=False):
    t = 0.0
    acorns = total = 0.0
    rake = bag = yard = 0
    unlocked = 1
    season = 0
    events = []
    supply_rate = LEAVES_PER_YARD / RESPAWN_S  # leaves/s the yard can regrow
    while t < minutes * 60:
        name, _, value, tower = YARDS[yard]
        r = RAKES[rake]
        cap = BAGS[bag][2] * (1)
        per_leaf = value * r[3] * (1 + SEASON_BONUS * season) * leaves_mult
        per_leaf *= (1 - GOLDEN_CHANCE) + GOLDEN_CHANCE * GOLDEN_MULT
        rate_leaves = min(leaves_per_swing(r[2]) / SWING_S, supply_rate)
        fill_s = max(SWING_S, cap / (per_leaf * rate_leaves))
        # choose the dive height that maximises acorns per second for this trip
        best = None
        for h in (0, tower * 0.5, tower):
            mult = 1 + h / HEIGHT_DIV
            trip = fill_s + WALK_TO_PILE_S + h * CLIMB_S_PER_STUD
            rate = cap * mult / trip
            if best is None or rate > best[0]:
                best = (rate, h, mult, trip)
        _, h, mult, trip = best
        t += trip
        gain = cap * mult
        acorns += gain
        total += gain
        # spend: next yard first if affordable, then rake/bag by cheaper next tier
        bought = True
        while bought:
            bought = False
            if unlocked < len(YARDS) and acorns >= YARDS[unlocked][1]:
                acorns -= YARDS[unlocked][1]
                events.append((t, f"unlock {YARDS[unlocked][0]}"))
                yard = unlocked
                unlocked += 1
                bought = True
                continue
            opts = []
            if rake + 1 < len(RAKES):
                opts.append((RAKES[rake + 1][1], "rake"))
            if bag + 1 < len(BAGS):
                opts.append((BAGS[bag + 1][1], "bag"))
            opts.sort()
            for cost, kind in opts:
                if acorns >= cost:
                    acorns -= cost
                    if kind == "rake":
                        rake += 1
                        events.append((t, f"buy {RAKES[rake][0]}"))
                    else:
                        bag += 1
                        events.append((t, f"buy {BAGS[bag][0]}"))
                    bought = True
                    break
        if unlocked == len(YARDS) and acorns >= SEASON_COST(season) and rake == len(RAKES) - 1:
            acorns -= SEASON_COST(season)
            season += 1
            rake = bag = 0
            acorns = 0
            events.append((t, f"NEW SEASON {season}"))
        if verbose and len(events) and events[-1][0] == t:
            pass
    return events, total


def fmt(t):
    return f"{int(t // 60):3d}:{int(t % 60):02d}"


if __name__ == "__main__":
    for label, mult in (("FREE", 1.0), ("2x LEAVES PASS", 2.0)):
        events, total = run(mult)
        print(f"== {label} ==")
        for t, e in events:
            if t < 240 * 60 and ("unlock" in e or "SEASON" in e or t < 600):
                print(f"  {fmt(t)}  {e}")
        print(f"  total acorns in 4 h: {total:,.0f}")
    # first-minute check: first dive time with the starting kit
    r, b = RAKES[0], BAGS[0]
    rate = min(leaves_per_swing(r[2]) / SWING_S, LEAVES_PER_YARD / RESPAWN_S)
    per_leaf = (1 - GOLDEN_CHANCE) + GOLDEN_CHANCE * GOLDEN_MULT
    print(f"first bag full after ~{b[2] / (rate * per_leaf):.0f} s of raking ({rate:.1f} leaves/s)")
