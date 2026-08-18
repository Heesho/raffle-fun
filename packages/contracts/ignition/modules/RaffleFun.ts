import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("RaffleFunModule", (m) => {
  const deployer = m.getAccount(0);
  const quoteToken = m.getParameter("quoteToken");
  const vrfWrapper = m.getParameter("vrfWrapper");
  const protocolTreasury = m.getParameter("protocolTreasury");
  const finalFactoryOwner = m.getParameter("finalFactoryOwner");

  const raffleFactory = m.contract("RaffleFactory", [
    quoteToken,
    vrfWrapper,
    protocolTreasury,
    deployer,
  ]);
  m.call(raffleFactory, "transferOwnership", [finalFactoryOwner]);

  return { raffleFactory };
});
