// imports
const { ethers, run, network } = require("hardhat")
// async main
async function main() {
    const ErebrusNftFactory = await ethers.getContractFactory("ErebrusRegistry")
    console.log("Deploying contract...")

    const Erebrus = await ErebrusNftFactory.deploy(
        "0x771C15e87272d6A57900f009Cd833b38dd7869e5"
    )
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
