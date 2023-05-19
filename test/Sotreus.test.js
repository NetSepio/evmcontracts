const { expect, assert } = require("chai")
const { ethers } = require("hardhat")
describe("Sotreus ", function() {
    let pPrice = ethers.utils.parseEther("1")
    let accounts, Sotreus, sendValue, SotreusInstance

    before(async function() {
        SotreusNftFactory = await ethers.getContractFactory("Sotreus")
        const URI = "http://localhost:9080/artwork"
        SotreusInstance = await SotreusNftFactory.deploy(
            "Sotreus",
            "ERB",
            URI,
            pPrice,
            500,
            300
        )
        Sotreus = await SotreusInstance.deployed()
        accounts = await ethers.getSigners()

        //unpausing the contract
        await Sotreus.unpause()

        // Doing  Public Mint
        await Sotreus.mintNFT(1, {
            value: pPrice
        })
    })

    // Constructor
    describe("Constructor", function() {
        it("To check if the Constructor is working ", async () => {
            let bURI = await Sotreus.tokenURI(1)
            let publicMintingPrice = await Sotreus.publicSalePrice()
            expect(bURI.toString()).to.be.equal("http://localhost:9080/artwork")
            expect(publicMintingPrice).to.be.equal(pPrice)
        })
    })

    // Mint
    describe("Mint", () => {
        // Start AllowList Mint
        it("Minting", async () => {
            await Sotreus.setPrice(pPrice)
            for (let i = 1; i <= 2; i++) {
                const SotreusUser = await Sotreus.connect(accounts[i])
                await SotreusUser.mintNFT(1, {
                    value: pPrice
                })
            }
            const TOKEN_OWNER1 = await Sotreus.ownerOf(1)
            const TOKEN_OWNER2 = await Sotreus.ownerOf(2)
            assert(TOKEN_OWNER1, accounts[1].address)
            assert(TOKEN_OWNER2, accounts[2].address)
        })
        // Enable Public Mint
        it("Public minting", async function() {
            const _BalanceOf = await Sotreus.balanceOf(accounts[0].address)
            assert.equal(_BalanceOf, 1)
        })
    })
    describe("Withdraw", () => {
        it("withdraws ETH from the contract", async () => {
            // Arrange
            deployer = accounts[0].address
            // Assert
            const startingNftBalance = await Sotreus.provider.getBalance(
                Sotreus.address
            )
            const startingDeployerBalance = await Sotreus.provider.getBalance(
                deployer
            )

            // Act
            const transactionResponse = await Sotreus.withdraw()
            const transactionReceipt = await transactionResponse.wait()
            const { gasUsed, effectiveGasPrice } = transactionReceipt
            const gasCost = gasUsed.mul(effectiveGasPrice)

            const endingNftBalance = await Sotreus.provider.getBalance(
                Sotreus.address
            )
            const endingDeployerBalance = await Sotreus.provider.getBalance(
                deployer
            )

            assert.equal(endingNftBalance, 0)
            assert.equal(
                startingNftBalance.add(startingDeployerBalance).toString(),
                endingDeployerBalance.add(gasCost).toString()
            )
        })
        it("Only allows the owner to withdraw", async function() {
            const SotreusConnectedContract = await Sotreus.connect(accounts[1])
            await expect(SotreusConnectedContract.withdraw()).to.be.reverted
        })
    })

    /// update
    describe("Client Config", () => {
        it("Reading & writing the Client Config ", async () => {
            /// TO check if the token owner can change it
            await Sotreus.connect(accounts[2]).writeClientConfig(3, "Hello")
            expect(await Sotreus.readClientConfig(3)).to.be.equal("Hello")
            /// TO check if the operator can change it
            await Sotreus.writeClientConfig(3, "Hello1")
            expect(await Sotreus.readClientConfig(3)).to.be.equal("Hello1")
            /// TO check if no one other than operator or token  can change it
            expect(Sotreus.connect(accounts[1]).writeClientConfig(3, "Hello2"))
                .to.be.reverted
        })
    })
    describe("ERC2981", () => {
        it("should support the ERC721 and ERC2198 standards", async () => {
            const ERC721InterfaceId = "0x80ac58cd"
            const ERC2981InterfaceId = "0x2a55205a"
            var isERC721 = await Sotreus.supportsInterface(ERC721InterfaceId)
            var isER2981 = await Sotreus.supportsInterface(ERC2981InterfaceId)
            assert.equal(isERC721, true, "Sotreus is not an ERC721")
            assert.equal(isER2981, true, "Sotreus is not an ERC2981")
        })
        it("should return the correct royalty info when specified and burned", async () => {
            const SotreusConnected4 = await Sotreus.connect(accounts[4])
            // const SotreusConnected2 = await Sotreus.connect(accounts[2])

            await SotreusConnected4.mintNFT(1, {
                value: pPrice
            })
            // Royalty info should be set back to default when NFT is burned
            const SotreusUser = await Sotreus.connect(accounts[1])
            await SotreusUser.burnNFT(2)
            tokenRoyaltyInfo = await Sotreus.royaltyInfo(2, 1000)
            assert.equal(
                tokenRoyaltyInfo[0],
                accounts[0].address,
                "Royalty receiver has not been set back to default"
            )
            assert.notEqual(
                tokenRoyaltyInfo[1].toNumber(),
                10,
                "Royalty has not been set back to default"
            )
        })
    })
    describe("Reveal", () => {
        it("To check the Reveal", async () => {
            let URL = "www.ABC.com"
            await Sotreus.revealCollection(URL)
            URL = URL + "/1"
            expect(await Sotreus.tokenURI(1)).to.be.equal(URL)
        })
    })

    describe("Client Manager", () => {
        it("Add an manager ", async () => {
            expect(
                await Sotreus.connect(accounts[2]).addManager(
                    accounts[5].address,
                    3
                )
            )
                .to.emit(Sotreus, "TokenManagerAdded")
                .withArgs(3, accounts[5].address)

            expect(await Sotreus.connect(accounts[5]).isManager(3)).to.be.true
        })
        it("remove manager", async () => {
            expect(
                await Sotreus.connect(accounts[2]).removeManager(
                    accounts[5].address,
                    3
                )
            )
                .to.emit(Sotreus, "TokenManagerRemoved")
                .withArgs(3, accounts[5].address)
            expect(await Sotreus.connect(accounts[5]).isManager(3)).to.be.false
        })
    })

    describe("Other Functions", () => {
        it("Pause and Unpause", async () => {
            let User = accounts[7]

            await Sotreus.pause()
            expect(Sotreus.mintNFT(1, { value: ethers.utils.parseEther("1") }))
                .to.be.reverted
            await Sotreus.unpause()
            await Sotreus.connect(User).mintNFT(1, {
                value: ethers.utils.parseEther("1")
            })
            expect(await Sotreus.balanceOf(User.address)).to.be.equal(1)
        })
        it("To transfer properly", async () => {
            expect(await Sotreus.ownerOf(3)).to.be.equal(accounts[2].address)
            await Sotreus.connect(accounts[2]).transferFrom(
                accounts[2].address,
                accounts[0].address,
                3
            )
            expect(await Sotreus.ownerOf(3)).to.be.equal(accounts[0].address)
        })
        it("Batch minting", async () => {
            let amount = pPrice.mul(3)
            await Sotreus.connect(accounts[5]).mintNFT(3, {
                value: amount
            })
            expect(await Sotreus.balanceOf(accounts[5].address)).to.be.equal(3)
        })

        it("The token should be burned", async () => {
            expect(await Sotreus.burnNFT(3)).to.emit(Sotreus, "NFTBurnt")
            expect(Sotreus.ownerOf(3)).to.be.reverted
        })
    })
})
