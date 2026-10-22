LEAD | contract: Raffle | function: requestDraw | bug_class: timestamp-downcast-deadline-rollover | group_key: Raffle | requestDraw | timestamp-downcast-deadline-rollover
file: target/packages/contracts/src/Raffle.sol
seam: three-way
code_smells: `requestDraw` casts `block.timestamp` to `uint64`, so `callbackDeadline` trusts a wrapped timestamp after the `uint64` limit.
proof: With `endTime = 2^64-1`, a valid request at `2^64` stores zero; `callbackDeadline()` returns zero, so `enableRefunds()` succeeds immediately.
description: An attacker can cancel a funded raffle at `2^64` seconds, but current deployments are about 584 billion years from that timestamp.