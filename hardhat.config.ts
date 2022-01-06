import "dotenv/config"
import "@nomiclabs/hardhat-etherscan"
//import "@nomiclabs/hardhat-solhint"
//import "@tenderly/hardhat-tenderly"
import "@nomiclabs/hardhat-waffle"
import "hardhat-abi-exporter"
import '@nomiclabs/hardhat-ethers';
import "hardhat-deploy"
//import "hardhat-deploy-ethers"
import "hardhat-gas-reporter"
//import "hardhat-spdx-license-identifier"

//import "hardhat-typechain"
//import "hardhat-watcher"
import "solidity-coverage"
//import "./tasks"


//import * as dotenv from 'dotenv';


import { HardhatUserConfig } from "hardhat/types"


/* This loads the variables in your .env file to `process.env` */


const accounts = {
  mnemonic: process.env.MNEMONIC || "test test test test test test test test test test test junk",
  // accountsBalance: "990000000000000000000",
}


/*
require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
*/

/*
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
*/

const config: HardhatUserConfig = {
  abiExporter: {
    path: "./abi",
    clear: false,
    flat: true,
    // only: [],
    // except: []
  },
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      chainId: 1,
      accounts,
      gasPrice: 100 * 1000000000,
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
      chainId: 42,
      accounts,
    },
    hardhat: {
    },
    fuse: {
      url: "https://rpc.fuse.io",
      accounts,
      chainId: 122,
      gasPrice: 1000000000,
      live: true,
      saveDeployments: true,
    },
    spark: {
      url: "https://rpc.fusespark.io/",
      accounts,
      chainId: 123,
      gasPrice: 1000000000,
    },
  },
  paths: {
    artifacts: "artifacts",
    cache: "cache",
    deploy: "deploy",
    deployments: "deployments",
    imports: "imports",
    sources: "contracts",
    tests: "test",
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  mocha: {
    timeout: 20000,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    dev: {
      // Default to 1
      default: 1,
      // dev address mainnet
      // 1: "",
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
