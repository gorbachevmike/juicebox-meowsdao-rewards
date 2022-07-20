import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import 'hardhat-contract-sizer';
import "solidity-coverage";
import 'solidity-docgen';

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

// const defaultNetwork = 'localhost';
const defaultNetwork = 'hardhat';

const config: HardhatUserConfig = {
  solidity: "0.8.6",
  defaultNetwork,
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      chainId: 31337,
      blockGasLimit: 1_000_000_000
    },
    rinkeby: {
      url: `${process.env.RINKEBY_URL}/${process.env.ALCHEMY_RINKEBY_KEY}`,
      accounts: [ `${process.env.PRIVATE_KEY}` ]
    },
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: false,
    only: ['Token', 'ProceResolver$', 'Util$', 'UriResolver$'],
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: 'USD',
    gasPrice: 30,
    showTimeSpent: true,
    coinmarketcap: `${process.env.COINMARKETCAP_KEY}`
  },
  etherscan: {
    apiKey: `${process.env.ETHERSCAN_KEY}`,
  },
  mocha: {
    timeout: 30 * 60 * 1000
  },
  docgen: { }
};

export default config;
