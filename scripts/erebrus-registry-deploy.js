// imports
const { ethers, run, network } = require("hardhat")
// async main
async function main() {
    const accounts = await ethers.getSigners()
    const deplpoyer = accounts[0].address
    let pPrice = ethers.utils.parseEther("0.1")
    let sPrice = ethers.utils.parseEther("4")
    const ErebrusNftFactory = await ethers.getContractFactory("Erebrus")
    console.log("Deploying contract...")
    const Erebrus = await ErebrusNftFactory.deploy(
        "EREBRUS",
        "ERBS",
        "ipfs://bafkreib7oqdtji6xhcsf3usbzt4mzefds7bs3ye2t3aedg2ssy6nyn36gq",
        pPrice,
        100,
        30,
        sPrice,
        500
    )
    await Erebrus.deployed()
    console.log(`Deployed contract to: ${Erebrus.address}`)
    if (
        (network.config.chainId === 5 && process.env.ETHERSCAN_API_KEY) ||
        (network.config.chainId == 80001 && process.env.POLYGONSCAN_API_KEY)
    ) {
        console.log("Waiting for block confirmations...")
        await Erebrus.deployTransaction.wait(6)
        await verify(Erebrus.address, [
            "EREBRUS",
            "ERBS",
            "ipfs://bafkreib7oqdtji6xhcsf3usbzt4mzefds7bs3ye2t3aedg2ssy6nyn36gq",
            pPrice,
            100,
            30,
            sPrice,
            500,
        ])
    }
}

// async function verify(contractAddress, args) {
const verify = async (contractAddress, args) => {
    console.log("Verifying contract...")
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
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
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
