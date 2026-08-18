import random
import unittest
from fractions import Fraction

from current_protocol_model import (
    Model,
    Status,
    modulo_bias,
    split_gross,
)


class CurrentProtocolModelTest(unittest.TestCase):
    def test_sequential_ids_and_ranges_partition_entries(self) -> None:
        model = Model(entry_price=1_000_000, reserve_entries=100)
        first = model.buy("alice", 20)
        second = model.buy("bob", 7)
        self.assertEqual((first, second), (1, 2))
        self.assertEqual((model.tickets[first].first, model.tickets[first].last), (1, 20))
        self.assertEqual((model.tickets[second].first, model.tickets[second].last), (21, 27))
        model.assert_invariants()

    def test_ticket_remains_a_transferable_bearer_claim(self) -> None:
        model = Model(entry_price=1_000_000, reserve_entries=1)
        ticket = model.buy("alice", 10)
        model.end_sale()
        model.transfer(ticket, "alice", "bob")
        model.request()
        model.callback(0)
        model.transfer(ticket, "bob", "carol")
        model.claim_winner(ticket, caller="keeper", to="carol")

    def test_refund_right_follows_ticket_transfer(self) -> None:
        model = Model(entry_price=1_000_000, reserve_entries=10)
        ticket = model.buy("alice", 4)
        model.end_sale()
        model.enable_refunds(timeout_elapsed=True)
        model.transfer(ticket, "alice", "bob")
        with self.assertRaises(ValueError):
            model.refund_tickets([ticket], caller="alice", to="alice")
        self.assertEqual(
            model.refund_tickets([ticket], caller="bob", to="bob"),
            4_000_000,
        )
        model.assert_invariants()

    def test_reserve_equality_is_nft_and_one_below_is_cash(self) -> None:
        below = Model(entry_price=1_000_000, reserve_entries=10)
        below.buy("alice", 9)
        below.end_sale()
        below.request()
        below.callback(0)
        self.assertEqual(below.status, Status.CASH_WON)

        equal = Model(entry_price=1_000_000, reserve_entries=10)
        equal.buy("alice", 10)
        equal.end_sale()
        equal.request()
        equal.callback(0)
        self.assertEqual(equal.status, Status.NFT_WON)

    def test_cash_is_final_eighty_five_fifteen_gross_split(self) -> None:
        model = Model(entry_price=1_000_000, reserve_entries=2)
        ticket = model.buy("alice", 1)
        model.end_sale()
        model.request()
        model.callback(0)
        self.assertEqual(model.treasury_claim, 50_000)
        self.assertEqual(model.winner_cash, 800_000)
        self.assertEqual(model.sponsor_claim, 150_000)
        with self.assertRaises(ValueError):
            model.enable_refunds(timeout_elapsed=True)
        self.assertEqual(
            model.claim_winner(ticket, caller="keeper", to="alice"), 800_000
        )
        model.assert_invariants()

    def test_third_party_cannot_redirect_but_current_bearer_can(self) -> None:
        third_party = Model(entry_price=1_000_000, reserve_entries=1)
        ticket = third_party.buy("alice", 1)
        third_party.end_sale()
        third_party.request()
        third_party.callback(0)
        with self.assertRaises(ValueError):
            third_party.claim_winner(ticket, caller="keeper", to="mallory")
        third_party.claim_winner(ticket, caller="keeper", to="alice")

        owner = Model(entry_price=1_000_000, reserve_entries=1)
        ticket = owner.buy("alice", 1)
        owner.end_sale()
        owner.request()
        owner.callback(0)
        owner.claim_winner(ticket, caller="alice", to="bob")
        owner.assert_invariants()

    def test_all_timeout_origins_preserve_full_weighted_refunds(self) -> None:
        for origin in (Status.ACTIVE, Status.DRAWING, Status.NFT_WON):
            model = Model(entry_price=1_000_000, reserve_entries=3)
            first = model.buy("alice", 2)
            second = model.buy("alice", 5)
            model.end_sale()
            if origin is not Status.ACTIVE:
                model.request()
            if origin is Status.NFT_WON:
                model.callback(0)
            with self.assertRaises(ValueError):
                model.enable_refunds()
            model.enable_refunds(timeout_elapsed=True)
            self.assertEqual(model.refund_liability, 7_000_000)
            self.assertEqual(
                model.refund_tickets(
                    [first, second], caller="alice", to="recipient"
                ),
                7_000_000,
            )
            model.assert_invariants()

    def test_purchase_partition_does_not_change_entry_or_economics(self) -> None:
        one = Model(entry_price=1_000_000, reserve_entries=101)
        many = Model(entry_price=1_000_000, reserve_entries=101)
        one.buy("alice", 100)
        for _ in range(100):
            many.buy("alice", 1)
        for model in (one, many):
            model.end_sale()
            model.request()
            model.callback(77)
        self.assertEqual(one.winning_entry, many.winning_entry)
        self.assertEqual(one.accounted, many.accounted)
        self.assertEqual(one.winner_cash, many.winner_cash)

    def test_randomized_terminal_drains_under_preserved_seeds(self) -> None:
        for seed in (0x524146464C45, 0x20260818):
            rng = random.Random(seed)
            for _ in range(2_000):
                total = rng.randint(1, 100)
                reserve = rng.randint(1, 120)
                model = Model(entry_price=1_000_000, reserve_entries=reserve)
                remaining = total
                tickets: list[int] = []
                while remaining:
                    entries = min(remaining, rng.randint(1, 20))
                    tickets.append(model.buy("alice", entries))
                    remaining -= entries
                model.end_sale()
                model.request()
                if rng.choice((True, False)):
                    model.callback(rng.getrandbits(256))
                    if model.status is Status.NFT_WON:
                        winner = model.containing_tickets(model.winning_entry)[0]
                        model.claim_winner(
                            winner, caller="keeper", to="alice"
                        )
                    else:
                        winner = model.containing_tickets(model.winning_entry)[0]
                        model.claim_winner(
                            winner, caller="keeper", to="alice"
                        )
                        model.recover_sponsor_prize()
                else:
                    model.enable_refunds(timeout_elapsed=True)
                    model.refund_tickets(
                        tickets, caller="alice", to="alice"
                    )
                    model.recover_sponsor_prize()
                for account in ("sponsor", "treasury"):
                    try:
                        model.claim_quote(account)
                    except ValueError:
                        pass
                model.assert_invariants()
                self.assertEqual(model.accounted, 0)

    def test_split_and_modulo_bias_conserve_exactly(self) -> None:
        for gross in (0, 1, 19, 20, 1_000_000, 10**30):
            for nft_won in (False, True):
                split = split_gross(gross, nft_won=nft_won)
                self.assertEqual(
                    split.fee + split.winner_cash + split.sponsor_cash, gross
                )
        for count in (1, 2, 3, 10, 1_000_000, 2**32 - 1):
            result = modulo_bias(count)
            heavy = result["heavy_residues"]
            probability = (
                heavy * result["heavy_probability"]
                + (count - heavy) * result["light_probability"]
            )
            self.assertEqual(probability, 1)

    def test_empty_sponsor_cancel_is_the_only_pre_timeout_refund_path(self) -> None:
        model = Model(entry_price=1_000_000, reserve_entries=1)
        with self.assertRaises(ValueError):
            model.enable_refunds()
        model.enable_refunds(sponsor_empty_cancel=True)
        self.assertEqual(model.status, Status.REFUNDING)
        self.assertEqual(model.refund_liability, 0)


if __name__ == "__main__":
    unittest.main()
