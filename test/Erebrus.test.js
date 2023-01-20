const { expect } = require("chai")
const { ethers, run, network, assert, artifacts } = require("hardhat")
describe("Erebrus ", function() {
    let pPrice = ethers.utils.parseEther("1")
    let aPrice = ethers.utils.parseEther("0.01")
    let accounts, Erebrus, sendValue

    before(async function() {
        erebrusNftFactory = await ethers.getContractFactory("Erebrus")
        const URI = "www.example.com"
        Erebrus = await erebrusNftFactory.deploy(
            "Erebrus",
            "ERB",
            URI,
            pPrice,
            aPrice,
            100
        )
        accounts = await ethers.getSigners()
    })
    describe("Constructor", function() {
        it("To check if the Constructor is working ", async () => {
            let bURI = await Erebrus.tokenURI(1)
            let allowlistingPrice = await Erebrus.allowListSalePrice()
            let publicMintingPrice = await Erebrus.publicSalePrice()
            assert(bURI.toString() == "www.example.com")
            assert(publicMintingPrice.toString() == pPrice.toString())
            assert(allowlistingPrice.toString() == aPrice.toString())
        })

        it("Initializes the NFT Correctly.", async () => {
            const name = await Erebrus.name()
            const symbol = await Erebrus.symbol()
            assert.equal(name, "Erebrus")
            assert.equal(symbol, "ERB")
        })
    })

    describe("Mint", () => {
        it("Public minting  & editMintWindows ", async function() {
            const User1 = accounts[1]
            Erebrus.editMintWindows(false)
            await Erebrus.connect(User1).mintNFT({ value: pPrice })
            const _BalanceOf = await Erebrus.balanceOf(User1.address)
            assert.equal(_BalanceOf, 1)
        })
        it("UpdateAllowlist  and setPrice Functions ", async () => {
            const User1 = accounts[1]
            sendValue = ethers.utils.parseEther("0.02")
            await Erebrus.editMintWindows(true)
            await Erebrus.setPrice(pPrice, sendValue)
            await Erebrus.UpdateAllowList(User1.address)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            const tokenId = await ErebrusConnectedContract.mintNFT({
                value: sendValue
            })

            const _tokenOwner = await Erebrus.ownerOf(1)
            assert.equal(_tokenOwner, User1.address)
        })
        it("SetAllowlist", async () => {
            await Erebrus.editMintWindows(true)
            await Erebrus.setPrice(pPrice, aPrice)
            const users = [accounts[1].address, accounts[2].address]
            await Erebrus.setAllowList(users)
            for (let i = 1; i <= 2; i++) {
                let ErebrusConnected = await Erebrus.connect(accounts[i])
                await ErebrusConnected.mintNFT({ value: aPrice })
            }
            const TOKEN_OWNER1 = await Erebrus.ownerOf(1)
            const TOKEN_OWNER2 = await Erebrus.ownerOf(2)
            assert(TOKEN_OWNER1, accounts[1].address)
            assert(TOKEN_OWNER2, accounts[2].address)
        })
        it("only the allowlist users can mint", async () => {
            Erebrus.editMintWindows(true)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            expect(
                ErebrusConnectedContract.mintNFT({ value: aPrice })
            ).to.be.revertedWith("You are not on the allow list")
            Erebrus.UpdateAllowList(accounts[1].address, true)
        })
    })
    describe("Withdraw", () => {
        it("withdraws ETH from a single funder", async () => {
            await Erebrus.editMintWindows(false)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            await ErebrusConnectedContract.mintNFT({ value: pPrice })

            // Arrange
            deployer = accounts[0].address
            // Assert
            const startingNftBalance = await Erebrus.provider.getBalance(
                Erebrus.address
            )
            const startingDeployerBalance = await Erebrus.provider.getBalance(
                deployer
            )

            // Act
            const transactionResponse = await Erebrus.withdraw()
            const transactionReceipt = await transactionResponse.wait()
            const { gasUsed, effectiveGasPrice } = transactionReceipt
            const gasCost = gasUsed.mul(effectiveGasPrice)

            const endingNftBalance = await Erebrus.provider.getBalance(
                Erebrus.address
            )
            const endingDeployerBalance = await Erebrus.provider.getBalance(
                deployer
            )

            assert.equal(endingNftBalance, 0)
            assert.equal(
                startingNftBalance.add(startingDeployerBalance).toString(),
                endingDeployerBalance.add(gasCost).toString()
            )
        })
        it("Only allows the owner to withdraw", async function() {
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            await expect(ErebrusConnectedContract.withdraw()).to.be.reverted
        })
    })
    describe("set metadata and  Reveal TokenUri", () => {
        it("Setting the The password and revealing", async () => {
            await Erebrus.setReveal("www.xyz.com", "key")
            expect(await Erebrus.tokenURI(1)).to.be.equal("www.example.com")
            await Erebrus.revealCollection()
            await Erebrus.Give_Password("key")
            bURI = await Erebrus.tokenURI(1)
            expect(await Erebrus.tokenURI(1)).to.be.equal("www.xyz.com/1")
        })
    })
    describe("Client Config", () => {
        it("Reading & writing the Client Config ", async () => {
            await Erebrus.editMintWindows(false)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            await ErebrusConnectedContract.mintNFT({ value: pPrice })
            await ErebrusConnectedContract.writeClientConfig(1, "Hello")
            expect(await Erebrus.readClientconfig(1)).to.be.equal("Hello")
        })
    })
    describe("Rental ", () => {
        let ErebrusUser1
        beforeEach(async () => {
            await Erebrus.editMintWindows(false)
            ErebrusUser1 = await Erebrus.connect(accounts[1])
            await ErebrusUser1.mintNFT({ value: pPrice })
        })
        it("setting Up the User", async () => {
            const time = Date.now()
            await ErebrusUser1.setUser(1, accounts[2].address, time + 600)
            expect(await Erebrus.userOf(1)).to.be.equal(accounts[2].address)
            expect(await Erebrus.userExpires(1)).to.be.equal(time + 600)
        })
        // it("Transfering the token without expiration of  Rent", async () => {
        //     const time = Date.now()
        //     await ErebrusUser1.setUser(1, accounts[2].address, time + 600)
        //     expect(
        //         await ErebrusUser1.safeTransferFrom(
        //             accounts[1].address,
        //             accounts[0].address,
        //             1,
        //             ""
        //         )
        //     ).to.be.revertedWith("Token expiration is not yet completed")
        // })
    })
})
