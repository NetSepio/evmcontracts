require("@nomiclabs/hardhat-waffle")
require("hardhat-gas-reporter")
require("@nomiclabs/hardhat-etherscan")

require("dotenv").config()
require("solidity-coverage")
require("hardhat-deploy")

const fs = require('fs');
require('dotenv').config()

// API_KEY & PRIVATE_KEY
const RINKEBY_RPC_URL = process.env.RINKEBY_RPC_URL || "https://eth-rinkeby.alchemyapi.io/v2/your-api-key"
const MATICMUM_RPC_URL = process.env.MATICMUM_RPC_URL || "https://rpc-mumbai.maticvigil.com"
const MNEMONIC = process.env.MNEMONIC || "mnemonic"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "Etherscan-API-key"
// optional
const PRIVATE_KEY = process.env.PRIVATE_KEY || "wallet private key"
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "COINMARKETCAP_API_KEY";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.17",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            },
            {
                version: "0.6.6"
            }
        ]
    },
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337
            // gasPrice: 130000000000,
        },
        maticmum: {
            url: MATICMUM_RPC_URL,
            //accounts: [`0x${ETH_PRIVATE_KEY}`],
            accounts: {
              mnemonic: MNEMONIC,
            },
        }
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY
        // customChains: [], // uncomment this line if you are getting a TypeError: customChains is not iterable
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    gasReporter: {
        enabled: true,
        currency: "USD",
        outputFile: "gas-report.txt",
        noColors: true
        // coinmarketcap: COINMARKETCAP_API_KEY,
    },
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0 // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
        }
    },
    mocha: {
        timeout: 200000
    }
}
