import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("RaffleFunModule", (m) => {
  const deployer = m.getAccount(0);
  const quoteToken = m.getParameter("quoteToken");
  const entropy = m.getParameter("entropy");
  const protocolTreasury = m.getParameter("protocolTreasury");
  const callbackGasLimit = m.getParameter("callbackGasLimit", 300_000n);
  const finalFactoryOwner = m.getParameter("finalFactoryOwner");

  const raffleFactory = m.contract("RaffleFactory", [
    quoteToken,
    entropy,
    protocolTreasury,
    callbackGasLimit,
    deployer,
  ]);
  const raffleLens = m.contract("RaffleLens", [raffleFactory]);
  m.call(raffleFactory, "transferOwnership", [finalFactoryOwner]);

  return {
    raffleFactory,
    raffleLens,
  };
});
