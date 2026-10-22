"""Independent arithmetic checks for the supplied raffle source snapshot.

This script uses no repository tests, deployment, network, or external source.
It checks the mathematical bounds and partitions identified in the source review.
"""

import json
import random
from pathlib import Path

U128 = 2**128 - 1
U256 = 2**256 - 1
PRICE = 1_000_000
BPS = 10_000
FEE = 500
WINNER = 8_000
checked = 0


def check_total(n):
    global checked
    assert 0 <= n <= U128
    gross = n * PRICE
    fee = gross * FEE // BPS
    cash = gross * WINNER // BPS
    assert gross <= U256
    assert gross * WINNER <= U256
    assert fee == n * 50_000
    assert cash == n * 800_000
    assert gross - fee == n * 950_000
    assert gross - fee - cash == n * 150_000
    assert fee + cash + (gross - fee - cash) == gross
    if n:
        assert cash > 0
        for word in (0, 1, n - 1, n, n + 1, 2**128, U256):
            selected = word % n + 1
            assert 1 <= selected <= n <= U128
    checked += 1


for total in range(10_001):
    check_total(total)
for bits in range(1, 129):
    for total in (2**bits - 1, 2**bits - 2, min(2**bits, U128)):
        check_total(total)

rng = random.Random(9238)
partition_cases = 0
for _ in range(5_000):
    total = rng.randrange(1, U128 + 1)
    check_total(total)
    count = rng.randrange(1, 101)
    cuts = sorted(set([0, total] + [rng.randrange(0, total + 1) for _ in range(count - 1)]))
    tickets = [(left + 1, right) for left, right in zip(cuts, cuts[1:])]
    assert len(tickets) <= total
    assert tickets[0][0] == 1 and tickets[-1][1] == total
    assert all(1 <= first <= last <= U128 for first, last in tickets)
    assert sum(last - first + 1 for first, last in tickets) == total
    liability = total * PRICE
    rng.shuffle(tickets)
    for first, last in tickets:
        refund = (last - first + 1) * PRICE
        assert refund <= liability
        liability -= refund
    assert liability == 0
    partition_cases += 1

for before, addition in ((0, 1), (0, U128), (U128 - 1, 1), (U128, 1), (1, U128)):
    accepted = addition > 0 and addition <= U128 - before
    if accepted:
        assert before + 1 <= U128
        assert before + addition <= U128
    else:
        assert before + addition > U128

deadline_cases = []
for end in (1, 1_792_540_800, 2**64 - 1):
    deadline = end + 172_800
    assert deadline <= U256
    for now in (end - 1, end, deadline - 1, deadline, deadline + 1):
        request = end <= now < deadline
        refund = now >= deadline
        assert not (request and refund)
        deadline_cases.append((end, now, request, refund))

for supplied in (0, 1, 10**18, U256):
    for paid in (0, supplied // 2, supplied):
        excess = supplied - paid
        assert 0 <= excess <= supplied
        assert paid + excess == supplied

result = {
    "status": "passed",
    "kind": "independent_arithmetic_property_checks_not_evm_execution",
    "totals_checked": checked,
    "random_refund_partitions_checked": partition_cases,
    "deadline_cases_checked": len(deadline_cases),
    "max_total_entries": str(U128),
    "max_gross_raw": str(U128 * PRICE),
    "max_gross_bits": (U128 * PRICE).bit_length(),
    "max_percentage_product_bits": (U128 * PRICE * WINNER).bit_length(),
    "exact_raw_per_entry": {"protocol": 50_000, "cash_winner": 800_000, "cash_sponsor": 150_000, "nft_sponsor": 950_000},
    "modulo_note": "Each entry has either floor(2**256 / n) or ceil(2**256 / n) preimages; n <= 2**128 - 1 bounds the relative difference below 2**-128.",
}

out = Path(__file__).with_name("math_bounds.result.json")
out.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
