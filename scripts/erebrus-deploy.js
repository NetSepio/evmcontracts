// imports
const { ethers, run, network } = require("hardhat")
// async main
async function main() {
    let pPrice = ethers.utils.parseEther("0.001")
    let sPrice = ethers.utils.parseEther("0.0004")
    const ErebrusNftFactory = await ethers.getContractFactory("ErebrusV2")
    console.log("Deploying contract...")
    const Erebrus = await ErebrusNftFactory.deploy(
        "EREBRUS",
        "ERB",
        "www.xyz.com",
        pPrice,
        sPrice,
        30,
        "0x771C15e87272d6A57900f009Cd833b38dd7869e5",
        "0x8C53DeA7aE3F5feDCa8E50414816b0B878a65026"
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
