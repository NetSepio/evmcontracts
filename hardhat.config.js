require("@nomiclabs/hardhat-waffle")
require("hardhat-gas-reporter")
require("@nomiclabs/hardhat-etherscan")
require("@nomiclabs/hardhat-truffle5")
require("solidity-coverage")
require("dotenv").config()

// API_KEY & PRIVATE_KEY
const MATICMUM_RPC_URL = process.env.MATICMUM_RPC_URL
const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY

const PRIVATE_KEY = process.env.PRIVATE_KEY
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY

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
    networks: {
        hardhat: {
            chainId: 31337
        },
        goerli: {
            url: GOERLI_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: 5
        },
        maticmum: {
            url: MATICMUM_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: 80001
        }
    },
    etherscan: {
        apiKey: {
            goerli: ETHERSCAN_API_KEY,
            polygonMumbai: POLYGONSCAN_API_KEY
        }
    }
}
