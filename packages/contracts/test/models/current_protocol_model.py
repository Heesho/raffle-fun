"""Independent model for the fixed-price sequential-ticket raffle protocol.

This module imports no Solidity artifact, generated ABI, SDK helper, or production
constant. Tests supply the economic constants independently.
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


@dataclass(frozen=True)
class Split:
    fee: int
    winner_cash: int
    sponsor_cash: int


def split_gross(gross: int, *, nft_won: bool) -> Split:
    if gross < 0:
        raise ValueError("negative gross")
    fee = gross * 5 // 100
    distributable = gross - fee
    winner_cash = 0 if nft_won else gross * 80 // 100
    return Split(
        fee=fee,
        winner_cash=winner_cash,
        sponsor_cash=distributable if nft_won else distributable - winner_cash,
    )


def modulo_bias(entry_count: int) -> dict[str, Fraction | int]:
    if entry_count <= 0:
        raise ValueError("entry_count must be positive")
    domain = 1 << 256
    quotient, heavy_residues = divmod(domain, entry_count)
    ideal = Fraction(1, entry_count)
    heavy_probability = (
        Fraction(quotient + 1, domain) if heavy_residues else ideal
    )
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


@dataclass
class Ticket:
    first: int
    last: int
    owner: str
    consumed: bool = False

    @property
    def entries(self) -> int:
        return self.last - self.first + 1


@dataclass
class Model:
    entry_price: int
    reserve_entries: int
    status: Status = Status.ACTIVE
    sale_ended: bool = False
    tickets: dict[int, Ticket] = field(default_factory=dict)
    ticket_order: list[int] = field(default_factory=list)
    total_entries: int = 0
    gross: int = 0
    unsettled: int = 0
    refund_liability: int = 0
    winner_cash: int = 0
    sponsor_claim: int = 0
    treasury_claim: int = 0
    winning_entry: int = 0
    winning_ticket: int = 0
    prize_claimed: bool = False
    quote_paid: int = 0

    def buy(self, owner: str, entries: int) -> int:
        if (
            self.status is not Status.ACTIVE
            or self.sale_ended
            or not owner
            or entries <= 0
        ):
            raise ValueError("invalid purchase")
        if self.total_entries + entries >= 1 << 128:
            raise ValueError("entry overflow")
        first = self.total_entries + 1
        last = self.total_entries + entries
        ticket_id = len(self.ticket_order) + 1
        self.tickets[ticket_id] = Ticket(first, last, owner)
        self.ticket_order.append(ticket_id)
        self.total_entries = last
        amount = entries * self.entry_price
        self.gross += amount
        self.unsettled += amount
        return ticket_id

    def transfer(self, ticket_id: int, sender: str, recipient: str) -> None:
        ticket = self._live(ticket_id)
        if ticket.owner != sender or not recipient:
            raise ValueError("invalid transfer")
        ticket.owner = recipient

    def end_sale(self) -> None:
        self.sale_ended = True

    def request(self) -> None:
        if (
            self.status is not Status.ACTIVE
            or not self.sale_ended
            or self.total_entries == 0
        ):
            raise ValueError("invalid request")
        self.status = Status.DRAWING

    def callback(self, random_word: int) -> None:
        if self.status is not Status.DRAWING:
            return
        if random_word < 0:
            raise ValueError("negative random word")
        self.winning_entry = random_word % self.total_entries + 1
        split = split_gross(
            self.gross, nft_won=self.total_entries >= self.reserve_entries
        )
        if self.total_entries >= self.reserve_entries:
            self.status = Status.NFT_WON
        else:
            self.status = Status.CASH_WON
            self.unsettled = 0
            self.winner_cash = split.winner_cash
            self.treasury_claim += split.fee
            self.sponsor_claim += split.sponsor_cash

    def claim_winner(self, ticket_id: int, *, caller: str, to: str) -> int:
        if self.status not in (Status.NFT_WON, Status.CASH_WON):
            raise ValueError("invalid winner state")
        if not to:
            raise ValueError("invalid destination")
        ticket = self._live(ticket_id)
        if not ticket.first <= self.winning_entry <= ticket.last:
            raise ValueError("wrong ticket")
        if caller != ticket.owner and to != ticket.owner:
            raise ValueError("third party cannot redirect")
        ticket.consumed = True
        self.winning_ticket = ticket_id
        if self.status is Status.NFT_WON:
            split = split_gross(self.gross, nft_won=True)
            self.prize_claimed = True
            self.unsettled = 0
            self.treasury_claim += split.fee
            self.sponsor_claim += split.sponsor_cash
            return 0
        amount, self.winner_cash = self.winner_cash, 0
        self.quote_paid += amount
        return amount

    def enable_refunds(
        self, *, timeout_elapsed: bool = False, sponsor_empty_cancel: bool = False
    ) -> None:
        if self.status not in (Status.ACTIVE, Status.DRAWING, Status.NFT_WON):
            raise ValueError("invalid refund origin")
        immediate_empty_cancel = (
            self.status is Status.ACTIVE
            and self.total_entries == 0
            and sponsor_empty_cancel
        )
        if not timeout_elapsed and not immediate_empty_cancel:
            raise ValueError("refund timeout not elapsed")
        self.status = Status.REFUNDING
        self.refund_liability = self.unsettled
        self.unsettled = 0

    def refund_tickets(
        self, ticket_ids: list[int], *, caller: str, to: str
    ) -> int:
        if (
            self.status is not Status.REFUNDING
            or not to
            or not 1 <= len(ticket_ids) <= 100
        ):
            raise ValueError("invalid refund")
        if len(set(ticket_ids)) != len(ticket_ids):
            raise ValueError("duplicate")
        tickets = [self._live(ticket_id) for ticket_id in ticket_ids]
        if any(ticket.owner != caller for ticket in tickets):
            raise ValueError("not owner")
        entries = sum(ticket.entries for ticket in tickets)
        for ticket in tickets:
            ticket.consumed = True
        amount = entries * self.entry_price
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

    def recover_sponsor_prize(self) -> None:
        if self.status not in (Status.CASH_WON, Status.REFUNDING):
            raise ValueError("prize unavailable")
        if self.prize_claimed:
            raise ValueError("already claimed")
        self.prize_claimed = True

    @property
    def accounted(self) -> int:
        return (
            self.unsettled
            + self.refund_liability
            + self.winner_cash
            + self.sponsor_claim
            + self.treasury_claim
        )

    def containing_tickets(self, entry: int) -> list[int]:
        return [
            ticket_id
            for ticket_id in self.ticket_order
            if self.tickets[ticket_id].first
            <= entry
            <= self.tickets[ticket_id].last
        ]

    def assert_invariants(self) -> None:
        expected_first = 1
        for expected_ticket_id, ticket_id in enumerate(self.ticket_order, start=1):
            ticket = self.tickets[ticket_id]
            assert ticket_id == expected_ticket_id
            assert ticket.first == expected_first
            expected_first = ticket.last + 1
        assert expected_first - 1 == self.total_entries
        assert self.gross == self.entry_price * self.total_entries
        assert self.gross == self.accounted + self.quote_paid
        if self.winning_entry:
            assert len(self.containing_tickets(self.winning_entry)) == 1

    def _live(self, ticket_id: int) -> Ticket:
        ticket = self.tickets.get(ticket_id)
        if ticket is None or ticket.consumed:
            raise ValueError("missing ticket")
        return ticket
