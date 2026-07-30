import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin],
  paths: {
    sources: "./src",
    tests: {
      nodejs: "./test/hardhat",
    },
    cache: "./cache/hardhat",
    artifacts: "./artifacts",
  },
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1_000,
          },
          evmVersion: "cancun",
        },
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1_000,
          },
          evmVersion: "cancun",
        },
      },
    },
  },
  networks: {
    hardhatBase: {
      type: "edr-simulated",
      chainType: "op",
      chainId: 31_337,
    },
    baseSepolia: {
      type: "http",
      chainType: "op",
      chainId: 84_532,
      url: configVariable("BASE_SEPOLIA_RPC_URL"),
      accounts: [configVariable("DEPLOYER_PRIVATE_KEY")],
    },
    base: {
      type: "http",
      chainType: "op",
      chainId: 8_453,
      url: configVariable("BASE_RPC_URL"),
      accounts: [configVariable("DEPLOYER_PRIVATE_KEY")],
    },
  },
});
