"""Bounded arithmetic and state checks derived from the supplied Raffle bundle.

This is an independent model, not an EVM test or a substitute for execution.
Only the standard, fee-free quote-token assumption is modeled.
"""
from itertools import permutations, product
from pathlib import Path
import json
import random

PRICE = 1_000_000
MAX = (1 << 128) - 1
rng = random.Random(5)
checks = 0


def check(condition):
    global checks
    assert condition
    checks += 1


def partition(total, count):
    if count == 1:
        return [total]
    cuts = sorted(rng.sample(range(1, total), count - 1))
    return [b - a for a, b in zip([0] + cuts, cuts + [total])]


cases = [[1], [MAX], [1, MAX - 1], [MAX - 1, 1], [1] * 100]
for _ in range(1000):
    total = rng.randint(1, 10**12)
    cases.append(partition(total, min(total, rng.randint(1, 100))))

for entries in cases:
    total = 0
    ranges = []
    balance = 0
    pot = 0
    for count in entries:
        check(count > 0 and count <= MAX - total)
        first, last = total + 1, total + count
        ranges.append((first, last))
        total = last
        balance += count * PRICE
        pot += count * PRICE
        check(balance == pot == total * PRICE)
        check(len(ranges) <= total <= MAX)
    check(ranges[0][0] == 1 and ranges[-1][1] == total)
    check(all(ranges[i][1] + 1 == ranges[i + 1][0] for i in range(len(ranges) - 1)))
    for word in (0, 1, (1 << 256) - 1, rng.getrandbits(256)):
        winning = word % total + 1
        check(sum(first <= winning <= last for first, last in ranges) == 1)
        check(1 <= winning <= MAX)

    fee = pot * 500 // 10_000
    for cash in (False, True):
        winner = pot * 8000 // 10_000 if cash else 0
        sponsor = pot - fee - winner
        check(fee + winner + sponsor == pot)
        check(fee > 0 and sponsor > 0)
        check((cash and winner > 0) or (not cash and winner == 0))
        for order in permutations(('winner', 'sponsor', 'fee')):
            amounts = dict(winner=winner, sponsor=sponsor, fee=fee)
            remaining_balance = pot
            for role in order:
                remaining_balance -= amounts[role]
                amounts[role] = 0
                check(remaining_balance == sum(amounts.values()))
            check(remaining_balance == 0)

    refund_order = list(range(len(entries)))
    rng.shuffle(refund_order)
    liability = pot
    refund_balance = pot
    for ticket in refund_order:
        first, last = ranges[ticket]
        amount = (last - first + 1) * PRICE
        check(amount == entries[ticket] * PRICE)
        liability -= amount
        refund_balance -= amount
        check(liability == refund_balance >= 0)
    check(liability == 0)

end = 1_000_000
request_deadline = end + 2 * 86400
for now in (end - 1, end, request_deadline - 1, request_deadline, request_deadline + 1):
    buy = now < end
    request = end <= now < request_deadline
    refund = now >= request_deadline
    check(sum((buy, request, refund)) == 1)
for requested in (end, request_deadline - 1):
    deadline = requested + 2 * 86400
    for now in (deadline - 1, deadline, deadline + 1):
        check((now < deadline) != (now >= deadline))

result = {
    'model': 'Independent Python translation; no EVM execution',
    'cases': len(cases),
    'assertions_passed': checks,
    'properties': [
        'Paid entries equal the unsettled pot before resolution',
        'Ticket ranges partition every sold entry exactly once',
        'Ticket count cannot exceed the uint128 entry count',
        'Every random word selects one valid ticket range',
        'NFT and cash allocations conserve the complete sale pot',
        'All six payout orders preserve remaining liabilities',
        'Arbitrary refund order consumes each entry value exactly once',
        'Request and callback deadline boundaries do not overlap refunds',
    ],
    'limitations': [
        'No malicious external contract execution',
        'No deployed wrapper or token integration',
        'No compiler, gas, or bytecode verification',
    ],
}
Path(__file__).with_name('model-results.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
