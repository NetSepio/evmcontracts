const { expect, assert } = require("chai")
const { ethers } = require("hardhat")
describe("Erebrus ", function() {
    let pPrice = ethers.utils.parseEther("1")
    let aPrice = ethers.utils.parseEther("0.01")
    let accounts, Erebrus, sendValue, ErebrusInstance

    before(async function() {
        erebrusNftFactory = await ethers.getContractFactory("Erebrus")
        const URI = "http://localhost:9080/artwork"
        ErebrusInstance = await erebrusNftFactory.deploy(
            "Erebrus",
            "ERB",
            URI,
            pPrice,
            aPrice,
            500
        )
        Erebrus = await ErebrusInstance.deployed()
        accounts = await ethers.getSigners()

        //unpausing the contract
        await Erebrus.unpause()

        // Doing  Public Mint
        await Erebrus.mintNFT({
            value: pPrice
        })

        //setting up role
        const admin = await Erebrus.EREBRUS_OPERATOR_ROLE()
        await Erebrus.grantRole(admin, accounts[0].address)
    })

    // Constructor
    describe("Constructor", function() {
        it("To check if the Constructor is working ", async () => {
            let bURI = await Erebrus.tokenURI(1)
            let allowlistingPrice = await Erebrus.allowListSalePrice()
            let publicMintingPrice = await Erebrus.publicSalePrice()
            expect(bURI.toString()).to.be.equal("http://localhost:9080/artwork")
            expect(publicMintingPrice).to.be.equal(pPrice)
            expect(allowlistingPrice).to.be.equal(aPrice)
        })

        it("Initializes the NFT Correctly.", async () => {
            const name = await Erebrus.name()
            const symbol = await Erebrus.symbol()
            expect(name).to.be.equal("Erebrus")
            assert.equal(symbol, "ERB")
        })
    })

    // Mint
    describe("Mint", () => {
        // Start AllowList Mint
        it("Set ALLOWlist ", async () => {
            await Erebrus.editMintWindows(true)
            await Erebrus.setPrice(pPrice, pPrice)
            const ALLOWLister = await Erebrus.EREBRUS_ALLOWLISTED_ROLE()

            for (let i = 1; i <= 3; i++) {
                await Erebrus.grantRole(ALLOWLister, accounts[i].address)
            }
            for (let i = 1; i <= 2; i++) {
                const ErebrusUser = await Erebrus.connect(accounts[i])
                await ErebrusUser.mintNFT({
                    value: pPrice
                })
            }

            const TOKEN_OWNER1 = await Erebrus.ownerOf(1)
            const TOKEN_OWNER2 = await Erebrus.ownerOf(2)
            assert(TOKEN_OWNER1, accounts[1].address)
            assert(TOKEN_OWNER2, accounts[2].address)
            await Erebrus.setPrice(pPrice, aPrice)
        })

        // Sale of NFTs to AllowList role
        it("only the allowlist users can mint", async () => {
            Erebrus.editMintWindows(true)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            expect(
                ErebrusConnectedContract.mintNFT({
                    value: aPrice
                })
            ).to.be.revertedWith("You are not on the allow list")
        })

        // Enable Public Mint
        it("Public minting", async function() {
            const _BalanceOf = await Erebrus.balanceOf(accounts[0].address)
            assert.equal(_BalanceOf, 1)
        })

        describe("Different Use cases for ALLOWList Mint", () => {
            beforeEach(async () => {
                await Erebrus.editMintWindows(true)
                const ALLOWLister = await Erebrus.EREBRUS_ALLOWLISTED_ROLE()
                for (let i = 0; i <= 3; i++) {
                    await Erebrus.grantRole(ALLOWLister, accounts[i].address)
                }
            })
            it("To check if they can't mint more than two ", async () => {
                const ErebrusUser1 = await Erebrus.connect(accounts[1])
                const triple = ethers.utils.parseEther("0.03")
                expect(
                    ErebrusUser1.mintNFT({
                        value: triple
                    })
                ).to.be.revertedWith("Erebrus: Can't mint more than 2")

                // To check if the user can't mint more than 2 if he already done
                for (let i = 0; i < 2; i++) {
                    ErebrusUser1.mintNFT({
                        value: aPrice
                    })
                }
                expect(
                    ErebrusUser1.mintNFT({
                        value: aPrice
                    })
                ).to.be.revertedWith("Erebrus: Can't mint anymore")
            })

            it("To check if they can't mint more than 1 if already minted previously", async () => {
                const ErebrusUser2 = await Erebrus.connect(accounts[2])
                await ErebrusUser2.mintNFT({
                    value: aPrice
                })
                expect(
                    ErebrusUser2.mintNFT({
                        value: ethers.utils.parseEther("0.02")
                    })
                ).to.be.revertedWith("Erebrus: Mint Only 2 per wallet")
            })
            it("to check if the ALLOWlister can mint 2 nft's", async () => {
                const ErebrusUser3 = await Erebrus.connect(accounts[3])
                const double = ethers.utils.parseEther("0.02")
                await ErebrusUser3.mintNFT({
                    value: double
                })
                const balance = await Erebrus.balanceOf(accounts[3].address)
                assert(balance, 2)
            })
        })
    })
    describe("Withdraw", () => {
        it("withdraws ETH from the contract", async () => {
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
    describe("Client Config", () => {
        it("Reading & writing the Client Config ", async () => {
            await Erebrus.writeClientConfig(1, "Hello")
            expect(await Erebrus.readClientConfig(1)).to.be.equal("Hello")
        })
    })
    describe("Rental ", () => {
        it("setting Up the User", async () => {
            val = ethers.utils.parseUnits("1", "gwei")
            //to check you cannot do renting if status is false
            expect(
                Erebrus.connect(accounts[4]).rent(1, 0, { value: sendValue })
            ).to.be.revertedWith("Erebrus: Not available for Renting")

            await Erebrus.setRentables(1, true, val)

            sendValue = val.mul(120)

            //to check time can't be less than 1 hour
            expect(
                Erebrus.connect(accounts[4]).rent(1, 0, { value: sendValue })
            ).to.be.revertedWith("Erebrus: Time cannot be less than 1 hour")

            //to check time can't be more than 6 months
            expect(
                Erebrus.connect(accounts[4]).rent(1, 4384, { value: sendValue })
            ).to.be.revertedWith("Erebrus: Time cannot be less than 1 hour")

            await Erebrus.connect(accounts[4]).rent(1, 2, {
                value: sendValue
            })
            const block = await Erebrus.provider.getBlock("latest")
            expect(await Erebrus.userOf(1)).to.be.equal(accounts[4].address)
            expect(await Erebrus.userExpires(1)).to.be.equal(
                block.timestamp + 7200
            )

            //if already rented cannot be rented again
            expect(
                Erebrus.connect(accounts[5]).rent(1, 1, { value: sendValue })
            ).to.be.revertedWith("Erbrus: Item renting time is not expired")
        })
    })
    describe("ERC2981", () => {
        it("should support the ERC721 and ERC2198 standards", async () => {
            const ERC721InterfaceId = "0x80ac58cd"
            const ERC2981InterfaceId = "0x2a55205a"
            var isERC721 = await Erebrus.supportsInterface(ERC721InterfaceId)
            var isER2981 = await Erebrus.supportsInterface(ERC2981InterfaceId)
            assert.equal(isERC721, true, "Erebrus is not an ERC721")
            assert.equal(isER2981, true, "Erebrus is not an ERC2981")
        })
        it("should return the correct royalty info when specified and burned", async () => {
            await Erebrus.editMintWindows(false)
            const ErebrusConnected4 = await Erebrus.connect(accounts[4])
            // const ErebrusConnected2 = await Erebrus.connect(accounts[2])

            await ErebrusConnected4.mintNFT({
                value: pPrice
            })
            // Royalty info should be set back to default when NFT is burned
            const ErebrusUser = await Erebrus.connect(accounts[1])
            await ErebrusUser.burnNFT(2)
            tokenRoyaltyInfo = await Erebrus.royaltyInfo(2, 1000)
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
})
