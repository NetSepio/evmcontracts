require("@nomiclabs/hardhat-waffle")
require("hardhat-gas-reporter")
require("@nomiclabs/hardhat-etherscan")
require("solidity-coverage")
require("solidity-docgen")
require("dotenv").config()

// API_KEY & PRIVATE_KEY
const MATICMUM_RPC_URL =
    process.env.MATICMUM_RPC_URL || "https://rpc-mumbai.maticvigil.com"
const ETHEREUM_RPC_URL = process.env.ETHEREUM_RPC_URL || "https://ETH-RPC-URL"
const MNEMONIC = process.env.MNEMONIC || "mnemonic"
const POLYGONSCAN_API_KEY =
    process.env.POLYGONSCAN_API_KEY || "Polygonscan-API-key"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "Etherscan-API-key"
// optional
const PRIVATE_KEY = process.env.PRIVATE_KEY || "wallet private key"
const COINMARKETCAP_API_KEY =
    process.env.COINMARKETCAP_API_KEY || "COINMARKETCAP_API_KEY"

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
            }
        ]
    },
    networks: {
        hardhat: {
            chainId: 31337
        },
        maticmum: {
            chainId: 80001,
            url: MATICMUM_RPC_URL,
            accounts: [PRIVATE_KEY]
            // accounts: {
            //     mnemonic: MNEMONIC
            // }
        },
        ethereum: {
            networkId: 1,
            url: ETHEREUM_RPC_URL,
            accounts: {
                mnemonic: MNEMONIC
            }
        }
    },
    etherscan: {
        apiKey: POLYGONSCAN_API_KEY
    }
}
