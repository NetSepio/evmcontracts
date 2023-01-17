// const { network, ethers } = require("hardhat")
// const { networkConfig, developmentChains } = require("../helper-hardhat-config")
// const { verify } = require("../utils/verify")
// require("dotenv").config()

// module.exports = async ({ getNamedAccounts, deployments }) => {
//     const { deploy, log } = deployments;
//     const { deployer } = await getNamedAccounts();
//     const publicSalePrice = ethers.utils.parseEther(".1");
//     const allowListSalePrice = ethers.utils.parseEther("0.05");
//     log("----------------------------------------------------")
//     log("Deploying Erebrus and waiting for confirmations...")
//     const Erebrus = await deploy("Erebrus", {
//         from: deployer,
//         args: [
//             "EREBRUS",
//             "ERBS",
//             "http://localhost:9080/artwork/",
//             publicSalePrice,
//             allowListSalePrice,
//             10
//         ],
//         log: true,
//         waitConfirmations: network.config.blockConfirmations || 1
//     })
//     log(`Erebrus NFT Collection deployed at ${Erebrus.address}`)

//     if (
//         !developmentChains.includes(network.name) &&
//         process.env.ETHERSCAN_API_KEY
//     ) {
//         await verify(Erebrus.address, ["EREBRUS", "ERBS", "http://localhost:9080/artwork/", publicSalePrice, allowListSalePrice, 10])
//     }
// }

// module.exports.tags = ["all"]

// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
	// Hardhat always runs the compile task when running scripts with its command
	// line interface.
	//
	// If this script is run directly using `node` you may want to call compile
	// manually to make sure everything is compiled
	// await hre.run('compile');

	// We get the contract to deploy
	const Erebrus = await hre.ethers.getContractFactory("Erebrus");
    const publicSalePrice = hre.ethers.utils.parseEther(".1");
    const allowListSalePrice = hre.ethers.utils.parseEther("0.05");
	const erebrus = await Erebrus.deploy("EREBRUS", "ERBS", "http://localhost:9080/artwork/", publicSalePrice, allowListSalePrice, 10);
	console.log("Erebrus deployed to:", erebrus.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});