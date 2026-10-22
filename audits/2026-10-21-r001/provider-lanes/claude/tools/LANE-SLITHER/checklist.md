Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
'forge clean' running (wd: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude/validation/snapshot/packages/contracts)
'forge config --json' running
'forge build --build-info --deny never --skip ./test/foundry/** ./script/** --force' running (wd: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude/validation/snapshot/packages/contracts)
**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [events-maths](#events-maths) (1 results) (Low)
 - [calls-loop](#calls-loop) (2 results) (Low)
 - [reentrancy-benign](#reentrancy-benign) (1 results) (Low)
 - [timestamp](#timestamp) (6 results) (Low)
 - [assembly](#assembly) (1 results) (Informational)
 - [naming-convention](#naming-convention) (1 results) (Informational)
## events-maths
Impact: Low
Confidence: Medium
 - [ ] ID-0
[Raffle.initialize(IRaffle.RaffleInitParams)](src/Raffle.sol#L176-L206) should emit an event for: 
	- [prizeTokenId = params.prizeTokenId](src/Raffle.sol#L201) 
	- [reserveEntries = params.reserveEntries](src/Raffle.sol#L203) 
	- [endTime = params.endTime](src/Raffle.sol#L204) 

src/Raffle.sol#L176-L206


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-1
[Raffle._isProtocolDestination(address,address)](src/Raffle.sol#L593-L605) has external calls inside a loop: [unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken) || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_ || destination == canonicalFactory.raffleImplementation()](src/Raffle.sol#L599-L601)
	Calls stack containing the loop:
		Raffle.refundTickets(uint256[])
		ERC721._burn(uint256)
		Raffle._update(address,uint256,address)

src/Raffle.sol#L593-L605


 - [ ] ID-2
[Raffle._isProtocolDestination(address,address)](src/Raffle.sol#L593-L605) has external calls inside a loop: [unsafeDestination = canonicalFactory.isRaffle(destination)](src/Raffle.sol#L603)
	Calls stack containing the loop:
		Raffle.refundTickets(uint256[])
		ERC721._burn(uint256)
		Raffle._update(address,uint256,address)

src/Raffle.sol#L593-L605


## reentrancy-benign
Impact: Low
Confidence: Medium
 - [ ] ID-3
Reentrancy in [RaffleFactory.createRaffle(IRaffleFactory.CreateRaffleParams)](src/RaffleFactory.sol#L97-L148):
	External calls:
	- [IRaffle(raffle).initialize(IRaffle.RaffleInitParams({sponsor:msg.sender,sponsorRecipient:params.sponsorRecipient,protocolTreasury:protocolTreasury,prizeToken:params.prizeToken,prizeTokenId:params.prizeTokenId,raffleId:raffleId,reserveEntries:params.reserveEntries,endTime:params.endTime}))](src/RaffleFactory.sol#L109-L121)
	State variables written after the call(s):
	- [idByRaffle[raffle] = raffleId](src/RaffleFactory.sol#L124)
	- [raffleById[raffleId] = raffle](src/RaffleFactory.sol#L123)

src/RaffleFactory.sol#L97-L148


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-4
[Raffle.enableRefunds()](src/Raffle.sol#L276-L301) uses timestamp for comparisons
	Dangerous comparisons:
	- [msg.sender != sponsor && block.timestamp < deadline](src/Raffle.sol#L282)
	- [block.timestamp < deadline](src/Raffle.sol#L287)
	- [block.timestamp < deadline](src/Raffle.sol#L291)

src/Raffle.sol#L276-L301


 - [ ] ID-5
[RaffleFactory.createRaffle(IRaffleFactory.CreateRaffleParams)](src/RaffleFactory.sol#L97-L148) uses timestamp for comparisons
	Dangerous comparisons:
	- [params.endTime <= currentTime](src/RaffleFactory.sol#L100)
	- [saleDuration > RaffleConstants.MAX_SALE_DURATION](src/RaffleFactory.sol#L102)

src/RaffleFactory.sol#L97-L148


 - [ ] ID-6
[Raffle.fulfillRandomWords(uint256,uint256[])](src/Raffle.sol#L509-L524) uses timestamp for comparisons
	Dangerous comparisons:
	- [_requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1 || block.timestamp >= callbackDeadline()](src/Raffle.sol#L511-L512)

src/Raffle.sol#L509-L524


 - [ ] ID-7
[Raffle.buyEntries(address,uint128)](src/Raffle.sol#L209-L237) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp >= endTime](src/Raffle.sol#L216)

src/Raffle.sol#L209-L237


 - [ ] ID-8
[Raffle.callbackDeadline()](src/Raffle.sol#L463-L465) uses timestamp for comparisons
	Dangerous comparisons:
	- [drawRequestedAt != 0](src/Raffle.sol#L464)

src/Raffle.sol#L463-L465


 - [ ] ID-9
[Raffle.requestDraw()](src/Raffle.sol#L240-L273) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp < endTime](src/Raffle.sol#L242)
	- [block.timestamp >= requestDeadline](src/Raffle.sol#L245)

src/Raffle.sol#L240-L273


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-10
[Raffle.requestDraw()](src/Raffle.sol#L240-L273) uses assembly
	- [INLINE ASM](src/Raffle.sol#L266-L268)

src/Raffle.sol#L240-L273


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-11
Function [IRaffle.ENTRY_PRICE()](src/interfaces/IRaffle.sol#L396) is not in mixedCase

src/interfaces/IRaffle.sol#L396


