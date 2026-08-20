import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("RaffleFunModule", (m) => {
  const quoteToken = m.getParameter("quoteToken");
  const vrfWrapper = m.getParameter("vrfWrapper");
  const protocolTreasury = m.getParameter("protocolTreasury");

  const raffleFactory = m.contract("RaffleFactory", [
    quoteToken,
    vrfWrapper,
    protocolTreasury,
  ]);

  return { raffleFactory };
});
