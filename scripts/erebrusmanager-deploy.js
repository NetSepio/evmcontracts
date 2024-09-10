// imports
const { ethers, run, network } = require("hardhat")
// async main
async function main() {
    const ErebrusNftFactory = await ethers.getContractFactory("ErebrusManager")
    console.log("Deploying contract...")
    
    const Erebrus = await ErebrusNftFactory.deploy()
    await Erebrus.deployed()
    console.log(`Deployed contract to: ${Erebrus.address}`)
}

// main
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
