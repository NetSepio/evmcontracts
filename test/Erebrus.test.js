const { expect, assert } = require("chai")
const { ethers } = require("hardhat")
describe("Erebrus ", function () {
    let pPrice = ethers.utils.parseEther("1")
    let sPrice = ethers.utils.parseEther("4")
    let accounts, Erebrus, sendValue, ErebrusInstance

    before(async function () {
        erebrusNftFactory = await ethers.getContractFactory("Erebrus")
        const URI = "http://localhost:9080/artwork"
        ErebrusInstance = await erebrusNftFactory.deploy(
            "Erebrus",
            "ERB",
            URI,
            pPrice,
            500,
            30,
            sPrice,
            500
        )
        Erebrus = await ErebrusInstance.deployed()
        accounts = await ethers.getSigners()

        //unpausing the contract
        await Erebrus.unpause()

        // Doing  Public Mint
        await Erebrus.mintNFT(1, {
            value: pPrice,
        })
    })

    // Constructor
    describe("Constructor", function () {
        it("To check if the Constructor is working ", async () => {
            let bURI = await Erebrus.tokenURI(1)
            let publicMintingPrice = await Erebrus.publicSalePrice()
            expect(bURI.toString()).to.be.equal("http://localhost:9080/artwork")
            expect(publicMintingPrice).to.be.equal(pPrice)
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
        it("Minting", async () => {
            await Erebrus.setPrice(pPrice)
            for (let i = 1; i <= 2; i++) {
                const ErebrusUser = await Erebrus.connect(accounts[i])
                await ErebrusUser.mintNFT(1, {
                    value: pPrice,
                })
            }
            const TOKEN_OWNER1 = await Erebrus.ownerOf(1)
            const TOKEN_OWNER2 = await Erebrus.ownerOf(2)
            assert(TOKEN_OWNER1, accounts[1].address)
            assert(TOKEN_OWNER2, accounts[2].address)
        })
        // Enable Public Mint
        it("Public minting", async function () {
            const _BalanceOf = await Erebrus.balanceOf(accounts[0].address)
            assert.equal(_BalanceOf, 1)
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
        it("Only allows the owner to withdraw", async function () {
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            await expect(ErebrusConnectedContract.withdraw()).to.be.reverted
        })
    })

    /// update
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

            await Erebrus.setRentInfo(1, true, val)

            sendValue = val.mul(2)

            //to check time can't be less than 1 hour
            expect(
                Erebrus.connect(accounts[4]).rent(1, 0, { value: sendValue })
            ).to.be.revertedWith("Erebrus: Time cannot be less than 1 hour")

            //to check time can't be more than 6 months
            expect(
                Erebrus.connect(accounts[4]).rent(1, 4384, { value: sendValue })
            ).to.be.revertedWith("Erebrus: Time cannot be less than 1 hour")

            await Erebrus.connect(accounts[4]).rent(1, 2, {
                value: sendValue,
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
            const ErebrusConnected4 = await Erebrus.connect(accounts[4])
            // const ErebrusConnected2 = await Erebrus.connect(accounts[2])

            await ErebrusConnected4.mintNFT(1, {
                value: pPrice,
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
    describe("Reveal", () => {
        it("To check the Reveal", async () => {
            let URL = "www.ABC.com"
            await Erebrus.revealCollection(URL)
            URL = URL + "/1"
            expect(await Erebrus.tokenURI(1)).to.be.equal(URL)
        })
    })

    describe("Other Functions", () => {
        it("Pause and Unpause", async () => {
            let User = accounts[7]

            await Erebrus.pause()
            expect(Erebrus.mintNFT(1, { value: ethers.utils.parseEther("1") }))
                .to.be.reverted
            await Erebrus.unpause()
            await Erebrus.connect(User).mintNFT(1, {
                value: ethers.utils.parseEther("1"),
            })
            expect(await Erebrus.balanceOf(User.address)).to.be.equal(1)
        })
        it("Set the User by the Token Owner ", async () => {
            const block = await Erebrus.provider.getBlock("latest")
            const timestamp = block.timestamp
            await Erebrus.connect(accounts[2]).setUser(
                3,
                accounts[0].address,
                timestamp + 60
            )
            expect(await Erebrus.userOf(3)).to.be.equal(accounts[0].address)
            //to check the user cannot change the User while already subscribed
            expect(
                Erebrus.connect(accounts[2]).setUser(
                    3,
                    accounts[1].address,
                    timestamp + 100
                )
            ).to.be.revertedWith("Erebrus: Item is already subscribed")
        })
        it("update Fee ", async () => {
            await Erebrus.updateFee(500)
            expect(await Erebrus.platFormFeeBasisPoint()).to.be.equal(500)
        })

        it("To transfer properly", async () => {
            expect(await Erebrus.ownerOf(3)).to.be.equal(accounts[2].address)
            await Erebrus.connect(accounts[2]).transferFrom(
                accounts[2].address,
                accounts[0].address,
                3
            )
            expect(await Erebrus.ownerOf(3)).to.be.equal(accounts[0].address)
        })
        it("Batch minting", async () => {
            let amount = pPrice.mul(3)
            await Erebrus.connect(accounts[5]).mintNFT(3, {
                value: amount,
            })
            expect(await Erebrus.balanceOf(accounts[5].address)).to.be.equal(3)
        })
        it("The token should be burned", async () => {
            expect(await Erebrus.burnNFT(3)).to.emit(Erebrus, "NFTBurnt")
            expect(Erebrus.ownerOf(3)).to.be.reverted
        })
    })
    describe("Subscription", () => {
        it("If the user can extend the existing Subscription", async () => {
            const Month = await Erebrus.MONTH()
            const creator = accounts[2]
            await Erebrus.connect(creator).mintNFT(1)
            const block = await Erebrus.provider.getBlock("latest")
            const freeSubscriptionPeriod = await Erebrus.expiresAt(9)
            expect(freeSubscriptionPeriod - block.timestamp).to.be.equal(Month)
        })
        it("to check if the renewal can be done by both Owner or Operator", async () => {
            const creator = accounts[2]
            const Month = await Erebrus.MONTH()
            // 0 Months
            expect(Erebrus.connect(creator).renewSubscription(9, 0)).to.be
                .reverted
            // 13 Months
            expect(Erebrus.connect(creator).renewSubscription(9, 13)).to.be
                .reverted
            // OTHER THAN OWNER OR OPERATOR
            expect(
                Erebrus.connect(accounts[3]).renewSubscription(9, 9)
            ).to.be.revertedWith(
                "Erebrus: Caller is owner nor approved or the Operator"
            )

            //OPERATOR RENEWAL SUBSCRIPTION
            let previousSubscriptionPeriod = await Erebrus.expiresAt(9)
            await Erebrus.renewSubscription(9, 1)
            let newSubscriptionPeriod = await Erebrus.expiresAt(9)
            expect(
                newSubscriptionPeriod.sub(previousSubscriptionPeriod)
            ).to.be.equal(Month)
            // OWNER RENEWAL SUBSCRIPTION
            expect(
                Erebrus.connect(creator).renewSubscription(9, 2)
            ).to.be.revertedWith("Erebrus: Insufficient Payment")

            let prevTime = await Erebrus.expiresAt(9)
            await Erebrus.connect(creator).renewSubscription(9, 1, {
                value: sPrice,
            })
            newTime = await Erebrus.expiresAt(9)
            expect(newTime.sub(prevTime)).to.be.equal(Month)
        })
        it("If the user gets the refund after cancellation", async () => {
            const creator = accounts[2]
            const Month = await Erebrus.MONTH()
            //OWNER
            const startingDeployerBalance = await Erebrus.provider.getBalance(
                creator.address
            )
            expect(Erebrus.connect(accounts[3]).cancelSubscription(9)).to.be
                .reverted
            //await Erebrus.connect(creator).cancelSubscription(9)
            let cancellationFees = await Erebrus.calculateCancellationFee(9)
            await Erebrus.cancelSubscription(9)

            const endingDeployerBalance = await Erebrus.provider.getBalance(
                creator.address
            )
            expect(
                endingDeployerBalance.sub(startingDeployerBalance).toString()
            ).to.be.equal(cancellationFees.toString())
        })
    })
})
