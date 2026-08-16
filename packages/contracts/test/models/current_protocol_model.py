"""Independent raffle.fun arithmetic, lifecycle, ownership, and randomness model.

This module intentionally imports no Solidity artifacts, generated ABI, SDK helper, or
production constant. Values are supplied by tests so a production constant mutation
cannot silently mutate this oracle with it.
"""

from dataclasses import dataclass, field
from enum import Enum, auto
from fractions import Fraction


class Status(Enum):
    ACTIVE = auto()
    DRAWING = auto()
    NFT_WON = auto()
    CASH_WON = auto()
    REFUNDING = auto()
    CLOSED = auto()


@dataclass(frozen=True)
class Split:
    fee: int
    distributable: int
    winner_cash: int
    sponsor_cash: int


def split_gross(gross: int, *, threshold_met: bool) -> Split:
    if gross < 0:
        raise ValueError("negative gross")
    fee = gross * 5 // 100
    distributable = gross - fee
    winner_cash = 0 if threshold_met else distributable * 4 // 5
    return Split(fee, distributable, winner_cash, distributable - winner_cash)


def modulo_bias(ticket_count: int) -> dict[str, Fraction | int]:
    """Exact direct-modulo distribution over a uniform 256-bit word."""
    if ticket_count <= 0:
        raise ValueError("ticket_count must be positive")
    domain = 1 << 256
    quotient, heavy_residues = divmod(domain, ticket_count)
    ideal = Fraction(1, ticket_count)
    heavy_probability = Fraction(quotient + 1, domain) if heavy_residues else ideal
    light_probability = Fraction(quotient, domain)
    return {
        "domain": domain,
        "quotient": quotient,
        "heavy_residues": heavy_residues,
        "heavy_probability": heavy_probability,
        "light_probability": light_probability,
        "absolute_advantage": heavy_probability - ideal,
        "relative_advantage": (heavy_probability - ideal) / ideal,
    }


def selective_reveal(
    *, tickets_owned: int, total_tickets: int, ticket_price: int, award_value: int
) -> dict[str, Fraction]:
    """One-attempt provider payoff when unfavorable outcomes time out to refunds.

    Payoffs are net of the provider's ticket payment. The model excludes gas and the
    native oracle fee, which can be subtracted separately by the requester/provider.
    """
    if not 0 < tickets_owned <= total_tickets:
        raise ValueError("provider must own a positive in-range ticket count")
    if ticket_price < 0 or award_value < 0:
        raise ValueError("negative value")
    ownership = Fraction(tickets_owned, total_tickets)
    stake = tickets_owned * ticket_price
    honest = ownership * award_value - stake
    selective = ownership * (award_value - stake)
    return {
        "ownership_fraction": ownership,
        "honest_expected_net": honest,
        "selective_expected_net": selective,
        "expected_advantage": selective - honest,
        "favorable_probability": ownership,
        "timeout_probability": 1 - ownership,
        "expected_attempts_until_favorable": 1 / ownership,
    }


@dataclass
class Model:
    price: int
    threshold: int
    status: Status = Status.ACTIVE
    owners: dict[int, str] = field(default_factory=dict)
    approvals: dict[int, str] = field(default_factory=dict)
    total: int = 0
    gross: int = 0
    unsettled: int = 0
    refund_liability: int = 0
    winner_cash: int = 0
    sponsor_claim: int = 0
    treasury_claim: int = 0
    winning_ticket: int = 0
    resolved: bool = False
    prize_claimed: bool = False
    quote_paid: int = 0

    def buy(self, owner: str, quantity: int) -> list[int]:
        if self.status is not Status.ACTIVE or not 1 <= quantity <= 100:
            raise ValueError("invalid purchase")
        ids = list(range(self.total + 1, self.total + quantity + 1))
        for ticket_id in ids:
            self.owners[ticket_id] = owner
        self.total += quantity
        amount = self.price * quantity
        self.gross += amount
        self.unsettled += amount
        return ids

    def transfer(self, ticket_id: int, sender: str, recipient: str) -> None:
        if self.owners.get(ticket_id) != sender:
            raise ValueError("not owner")
        if self.status is Status.DRAWING:
            raise ValueError("drawing lock")
        if self.status in (Status.NFT_WON, Status.CASH_WON) and ticket_id == self.winning_ticket:
            raise ValueError("winner lock")
        self.owners[ticket_id] = recipient
        self.approvals.pop(ticket_id, None)

    def request(self) -> None:
        if self.status is not Status.ACTIVE or self.total == 0:
            raise ValueError("invalid request")
        self.status = Status.DRAWING

    def callback(self, random_word: int) -> None:
        if self.status is not Status.DRAWING:
            return
        self.winning_ticket = random_word % self.total + 1
        self.resolved = True
        split = split_gross(self.gross, threshold_met=self.total >= self.threshold)
        if self.total >= self.threshold:
            self.status = Status.NFT_WON
        else:
            self.status = Status.CASH_WON
            self.unsettled = 0
            self.winner_cash = split.winner_cash
            self.sponsor_claim += split.sponsor_cash
            self.treasury_claim += split.fee

    def enable_refunds(self) -> None:
        if self.status not in (Status.ACTIVE, Status.DRAWING, Status.NFT_WON):
            raise ValueError("invalid refund origin")
        self.status = Status.REFUNDING
        self.refund_liability = self.unsettled
        self.unsettled = 0

    def redeem_winner(self, caller: str) -> int:
        if self.status not in (Status.NFT_WON, Status.CASH_WON):
            raise ValueError("invalid winner state")
        if self.owners.get(self.winning_ticket) != caller:
            raise ValueError("not owner")
        del self.owners[self.winning_ticket]
        self.approvals.pop(self.winning_ticket, None)
        if self.status is Status.NFT_WON:
            self.prize_claimed = True
            split = split_gross(self.gross, threshold_met=True)
            self.unsettled = 0
            self.sponsor_claim += split.sponsor_cash
            self.treasury_claim += split.fee
            return 0
        amount = self.winner_cash
        self.winner_cash = 0
        self.quote_paid += amount
        return amount

    def redeem_refunds(self, caller: str, ticket_ids: list[int]) -> int:
        if self.status is not Status.REFUNDING or not 1 <= len(ticket_ids) <= 100:
            raise ValueError("invalid refund")
        if len(set(ticket_ids)) != len(ticket_ids):
            raise ValueError("duplicate")
        if any(self.owners.get(ticket_id) != caller for ticket_id in ticket_ids):
            raise ValueError("not owner")
        for ticket_id in ticket_ids:
            del self.owners[ticket_id]
            self.approvals.pop(ticket_id, None)
        amount = self.price * len(ticket_ids)
        self.refund_liability -= amount
        self.quote_paid += amount
        return amount

    def claim_quote(self, account: str) -> int:
        if account == "sponsor":
            amount, self.sponsor_claim = self.sponsor_claim, 0
        elif account == "treasury":
            amount, self.treasury_claim = self.treasury_claim, 0
        else:
            raise ValueError("unknown claimant")
        if amount == 0:
            raise ValueError("empty claim")
        self.quote_paid += amount
        return amount

    @property
    def accounted(self) -> int:
        return (
            self.unsettled
            + self.refund_liability
            + self.winner_cash
            + self.sponsor_claim
            + self.treasury_claim
        )

    def assert_conservation(self) -> None:
        assert self.gross == self.accounted + self.quote_paid
        assert self.gross == self.price * self.total

