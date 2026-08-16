import random
import unittest
from fractions import Fraction

from current_protocol_model import (
    Model,
    Status,
    modulo_bias,
    selective_reveal,
    split_gross,
)


class CurrentProtocolModelTest(unittest.TestCase):
    def test_arithmetic_conserves_raw_units_at_division_boundaries(self) -> None:
        values = [0, 1, 4, 5, 19, 20, 99, 100, 10_000, 10_001, 10**30]
        for gross in values:
            for threshold_met in (False, True):
                split = split_gross(gross, threshold_met=threshold_met)
                self.assertEqual(split.fee + split.distributable, gross)
                self.assertEqual(
                    split.winner_cash + split.sponsor_cash, split.distributable
                )

    def test_purchase_partition_does_not_change_economics(self) -> None:
        one = Model(price=1_000_003, threshold=101)
        many = Model(price=1_000_003, threshold=101)
        one.buy("alice", 100)
        for _ in range(100):
            many.buy("alice", 1)
        one.request()
        many.request()
        one.callback(7)
        many.callback(7)
        self.assertEqual(one.accounted, many.accounted)
        self.assertEqual(one.winner_cash, many.winner_cash)

    def test_callback_timeout_race_is_first_transition_wins(self) -> None:
        callback_first = Model(price=10, threshold=2)
        callback_first.buy("alice", 1)
        callback_first.request()
        callback_first.callback(0)
        with self.assertRaises(ValueError):
            callback_first.enable_refunds()

        timeout_first = Model(price=10, threshold=1)
        timeout_first.buy("alice", 1)
        timeout_first.request()
        timeout_first.enable_refunds()
        timeout_first.callback(0)
        self.assertEqual(timeout_first.status, Status.REFUNDING)
        self.assertEqual(timeout_first.winning_ticket, 0)

    def test_drawing_and_winner_locks_but_refund_transfer_unlocks(self) -> None:
        model = Model(price=10, threshold=1)
        model.buy("alice", 2)
        model.request()
        with self.assertRaises(ValueError):
            model.transfer(1, "alice", "bob")
        model.callback(0)
        with self.assertRaises(ValueError):
            model.transfer(1, "alice", "bob")
        model.transfer(2, "alice", "bob")

        refund = Model(price=10, threshold=1)
        refund.buy("alice", 1)
        refund.request()
        refund.enable_refunds()
        refund.transfer(1, "alice", "bob")
        self.assertEqual(refund.redeem_refunds("bob", [1]), 10)
        refund.assert_conservation()

    def test_all_three_refund_origins_preserve_full_gross(self) -> None:
        for origin in (Status.ACTIVE, Status.DRAWING, Status.NFT_WON):
            model = Model(price=7, threshold=1)
            model.buy("alice", 3)
            if origin is not Status.ACTIVE:
                model.request()
            if origin is Status.NFT_WON:
                model.callback(0)
            model.enable_refunds()
            self.assertEqual(model.refund_liability, 21)
            self.assertEqual(model.redeem_refunds("alice", [1, 2, 3]), 21)
            model.assert_conservation()

    def test_randomized_terminal_drains_under_two_preserved_seeds(self) -> None:
        for seed in (0x524146464C45, 0x20260816):
            rng = random.Random(seed)
            for _ in range(2_000):
                total = rng.randint(1, 100)
                threshold = rng.randint(1, 120)
                model = Model(price=rng.randint(1, 10**12), threshold=threshold)
                remaining = total
                while remaining:
                    quantity = min(remaining, rng.randint(1, 100))
                    model.buy("alice", quantity)
                    remaining -= quantity
                model.request()
                if rng.choice((True, False)):
                    model.callback(rng.getrandbits(256))
                    if model.status is Status.NFT_WON and rng.choice((True, False)):
                        model.enable_refunds()
                    elif model.status in (Status.NFT_WON, Status.CASH_WON):
                        model.redeem_winner("alice")
                else:
                    model.enable_refunds()
                if model.status is Status.REFUNDING:
                    model.redeem_refunds("alice", sorted(model.owners))
                for account in ("sponsor", "treasury"):
                    try:
                        model.claim_quote(account)
                    except ValueError:
                        pass
                model.assert_conservation()
                self.assertEqual(model.accounted, 0)

    def test_exact_modulo_bias_formula(self) -> None:
        for count in (1, 2, 3, 10, 100, 1_000_000, 2**32 - 1):
            result = modulo_bias(count)
            heavy = result["heavy_residues"]
            light = count - heavy
            probability_sum = (
                heavy * result["heavy_probability"]
                + light * result["light_probability"]
            )
            self.assertEqual(probability_sum, 1)
            self.assertGreaterEqual(result["absolute_advantage"], 0)

    def test_selective_reveal_refund_option_has_positive_expected_advantage(self) -> None:
        result = selective_reveal(
            tickets_owned=1,
            total_tickets=10,
            ticket_price=1_000_000,
            award_value=100_000_000,
        )
        self.assertEqual(result["favorable_probability"], Fraction(1, 10))
        self.assertEqual(result["expected_attempts_until_favorable"], 10)
        self.assertEqual(result["expected_advantage"], 900_000)


if __name__ == "__main__":
    unittest.main()
