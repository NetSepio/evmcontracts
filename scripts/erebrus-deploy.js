// imports
const { ethers, run, network } = require("hardhat")
// async main
async function main() {
    const accounts = await ethers.getSigners()
    const deplpoyer = accounts[0].address
    let pPrice = ethers.utils.parseEther("1")
    let aPrice = ethers.utils.parseEther("0.01")
    const ErebrusNftFactory = await ethers.getContractFactory("Erebrus")
    console.log("Deploying contract...")
    const Erebrus_Nft = await ErebrusNftFactory.deploy(
        "EREBRUS",
        "ERBS",
        "http://localhost:9080/artwork/",
        pPrice,
        aPrice,
        100
    )
    await Erebrus_Nft.deployed()
    console.log(`Deployed contract to: ${Erebrus_Nft.address}`)
    if (
        (network.config.chainId === 5 && process.env.ETHERSCAN_API_KEY) ||
        (network.config.chainId == 80001 && process.env.POLYGONSCAN_API_KEY)
    ) {
        console.log("Waiting for block confirmations...")
        await Erebrus_Nft.deployTransaction.wait(6)
        await verify(Erebrus_Nft.address, [
            "EREBRUS",
            "ERBS",
            "http://localhost:9080/artwork/",
            pPrice,
            aPrice,
            100
        ])
    }
}

// async function verify(contractAddress, args) {
const verify = async (contractAddress, args) => {
    console.log("Verifying contract...")
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: args
        })
    } catch (e) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Already Verified!")
        } else {
            console.log(e)
        }
    }
}

// main
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
