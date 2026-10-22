#!/bin/bash
# Generated scratch helper: Step 5 manual-review pattern searches over ORIGINAL production sources (+ reachable VRF deps).
cd "$1/packages/contracts" || exit 1
G=/usr/bin/grep
SRC="src/Raffle.sol src/RaffleFactory.sol src/interfaces/IRaffle.sol src/interfaces/IRaffleFactory.sol src/libraries/RaffleConstants.sol"
VRF="node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol"
echo "# Step 5 manual-review searches (generated $(date -u +%FT%TZ)); files: $SRC"
s() { local title="$1" pat="$2"; shift 2; echo; echo "## [$title] $G -nE '$pat' $*"; $G -nE "$pat" "$@" || echo "(no matches)"; }
echo; echo "### 1. PRIVACY"
s privacy-secrets 'secret|password|seed|salt|commit|reveal|hidden|confidential' $SRC
s privacy-private-state 'private|internal' src/Raffle.sol src/RaffleFactory.sol
s privacy-hashing 'keccak256|sha256|ripemd160|abi\.encodePacked' $SRC
echo; echo "### 2. FRONT-RUNNING / ORDERING / MEV"
s fr-timestamp 'block\.timestamp|block\.number' $SRC
s fr-slippage-guards 'slippage|minOut|maxPrice|amountOutMin|maxTotal|expected[A-Z]|deadline' $SRC
s fr-status-gates-in-transfer-hook 'function _update|_isProtocolDestination\(to|Status\.Drawing' src/Raffle.sol
s fr-permissionless-entrypoints 'function (buyEntries|requestDraw|enableRefunds|settleWinningTicket|redeemWinningTicket|refundTickets|releaseSponsorProceeds|releaseProtocolFees|releaseSponsorPrize|createRaffle)' $SRC
s fr-reserve-outcome 'reserveEntries' src/Raffle.sol
s fr-msg-value 'msg\.value' src/Raffle.sol
echo; echo "### 3. CRYPTOGRAPHY / RANDOMNESS"
s crypto-signatures 'ecrecover|ECDSA|signature|permit\(|nonces|EIP712|isValidSignature' $SRC
s crypto-weak-randomness 'blockhash|block\.prevrandao|block\.difficulty|block\.coinbase|random' $SRC
s crypto-vrf-usage 'randomWords|requestConfirmations|callbackGasLimit|requestRandomness|fulfillRandomWords|nativePayment' src/Raffle.sol src/libraries/RaffleConstants.sol
s crypto-modulo-on-randomness '%' src/Raffle.sol
s crypto-create-address-predictability 'Clones\.clone|cloneDeterministic|create2' src/RaffleFactory.sol
s crypto-vrf-deps 'transferAndCall|lastRequestId|EXTRA_ARGS_V1_TAG|OnlyVRFWrapperCanFulfill' $VRF
echo; echo "### 4. DeFi INTERACTIONS (oracles, flash loans, external protocol assumptions)"
s defi-oracles 'oracle|latestRoundData|AggregatorV3|priceFeed|linkNativeFeed|TWAP|getReserves|observe\(' $SRC $VRF
s defi-flash 'flash|swap|uniswap|curve|balancer|aave|liquidity|borrow' $SRC
s defi-balance-dependence 'balanceOf\(address\(this\)\)|address\(this\)\.balance|totalSupply\(' src/Raffle.sol src/RaffleFactory.sol
s defi-token-assumptions 'safeTransfer|safeTransferFrom|transferFrom\(|decimals\(|QUOTE_TOKEN_DECIMALS|ENTRY_PRICE' $SRC
s defi-native-eth 'receive\(\)|payable|call\(gas\(\)' src/Raffle.sol src/RaffleFactory.sol
s defi-vrf-pricing 'calculateRequestPriceNative|estimateRequestPriceNative|requestRandomWordsInNative' src/Raffle.sol $VRF
echo; echo "### 5. TRUST / DESTINATION SCREENING (supports manual findings)"
s trust-prize-calls 'prizeToken\.|prize\.' src/Raffle.sol src/RaffleFactory.sol
s trust-registry 'isRaffle|raffleImplementation\(\)' src/Raffle.sol src/RaffleFactory.sol
s trust-code-length 'code\.length' src/Raffle.sol src/RaffleFactory.sol
