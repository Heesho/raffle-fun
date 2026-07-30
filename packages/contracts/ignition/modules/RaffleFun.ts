import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("RaffleFunModule", (m) => {
  const deployer = m.getAccount(0);
  const verifiedQuoteTokens = m.getParameter("verifiedQuoteTokens");
  const entropy = m.getParameter("entropy");
  const protocolTreasury = m.getParameter("protocolTreasury");
  const callbackGasLimit = m.getParameter("callbackGasLimit", 300_000n);
  const finalFactoryOwner = m.getParameter("finalFactoryOwner");

  const raffleImplementation = m.contract("Raffle");
  const raffleFactory = m.contract("RaffleFactory", [
    raffleImplementation,
    verifiedQuoteTokens,
    entropy,
    protocolTreasury,
    callbackGasLimit,
    deployer,
  ]);
  const raffleLens = m.contract("RaffleLens", [raffleFactory]);
  m.call(raffleFactory, "transferOwnership", [finalFactoryOwner]);

  return {
    raffleImplementation,
    raffleFactory,
    raffleLens,
  };
});
