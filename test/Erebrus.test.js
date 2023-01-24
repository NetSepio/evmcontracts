const { expect, assert } = require("chai")
const { ethers } = require("hardhat")
describe("Erebrus ", function() {
    let pPrice = ethers.utils.parseEther("1")
    let aPrice = ethers.utils.parseEther("0.01")
    let accounts, Erebrus, sendValue, ErebrusInstance

    before(async function() {
        erebrusNftFactory = await ethers.getContractFactory("Erebrus")
        const URI = "www.example.com"
        ErebrusInstance = await erebrusNftFactory.deploy(
            "Erebrus",
            "ERB",
            URI,
            pPrice,
            aPrice,
            100
        )
        Erebrus = await ErebrusInstance.deployed()
        accounts = await ethers.getSigners()
    })
    describe("Constructor", function() {
        it("To check if the Constructor is working ", async () => {
            let bURI = await Erebrus.tokenURI(1)
            let allowlistingPrice = await Erebrus.allowListSalePrice()
            let publicMintingPrice = await Erebrus.publicSalePrice()
            expect(bURI.toString()).to.be.equal("www.example.com")
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

    describe("Mint", () => {
        it("Public minting  & editMintWindows ", async function() {
            const User1 = accounts[1]
            await Erebrus.editMintWindows(false)
            await Erebrus.connect(User1).mintNFT(accounts[0].address, 1000, {
                value: pPrice
            })
            const _BalanceOf = await Erebrus.balanceOf(User1.address)
            assert.equal(_BalanceOf, 1)
        })

        it("SetAllowlist", async () => {
            await Erebrus.editMintWindows(true)
            await Erebrus.setPrice(pPrice, pPrice)
            const users = [accounts[1].address, accounts[2].address]
            await Erebrus.setAllowList(users)
            for (let i = 1; i <= 2; i++) {
                let ErebrusConnected = await Erebrus.connect(accounts[i])
                await ErebrusConnected.mintNFT(accounts[0].address, 1000, {
                    value: pPrice
                })
            }
            const TOKEN_OWNER1 = await Erebrus.ownerOf(1)
            const TOKEN_OWNER2 = await Erebrus.ownerOf(2)
            assert(TOKEN_OWNER1, accounts[1].address)
            assert(TOKEN_OWNER2, accounts[2].address)
        })
        it("Update the Allowlist & check how nft's can be minted", async () => {
            await Erebrus.setPrice(pPrice, aPrice)
            const User1 = accounts[1]
            const operator = await Erebrus.EREBRUS_OPERATOR_ROLE()
            await Erebrus.grantRole(operator, accounts[0].address)
            await Erebrus.editMintWindows(true)
            await Erebrus.UpdateAllowList(User1.address)
            const ErebrusConnectedContract = await Erebrus.connect(User1)
            await ErebrusConnectedContract.mintNFT(accounts[0].address, 1000, {
                value: aPrice
            })

            const _tokenOwner = await Erebrus.ownerOf(1)
            assert.equal(_tokenOwner, User1.address)
        })
        it("only the allowlist users can mint", async () => {
            Erebrus.editMintWindows(true)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            expect(
                ErebrusConnectedContract.mintNFT(accounts[0].address, 1000, {
                    value: aPrice
                })
            ).to.be.revertedWith("You are not on the allow list")
            Erebrus.UpdateAllowList(accounts[1].address, true)
        })
        // describe("Different Use cases for WhiteList Mint", () => {
        //     let ErebrusConnected
        //     beforeEach(async () => {
        //         await Erebrus.editMintWindows(true)
        //         const users = [
        //             accounts[1].address,
        //             accounts[2].address,
        //             accounts[3].address
        //         ]
        //         await Erebrus.setAllowList(users)
        //     })
        //     it("First", async () => {
        //         ErebrusConnected = await Erebrus.connect(accounts[1])
        //         const double = ethers.utils.parseEther("0.02")
        //         await ErebrusConnected.mintNFT({ value: double })
        //         expect(
        //             ErebrusConnected.mintNFT({ value: aPrice })
        //         ).to.be.reverted()
        //     })
        // })
    })
    describe("Withdraw", () => {
        it("withdraws ETH from a single funder", async () => {
            await Erebrus.editMintWindows(false)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            await ErebrusConnectedContract.mintNFT(accounts[0].address, 1000, {
                value: pPrice
            })

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
            const operator = await Erebrus.EREBRUS_OPERATOR_ROLE()
            await Erebrus.grantRole(operator, accounts[0].address)
            await Erebrus.editMintWindows(false)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            await ErebrusConnectedContract.mintNFT(accounts[0].address, 1000, {
                value: pPrice
            })
            await Erebrus.writeClientConfig(1, "Hello")
            expect(await Erebrus.readClientconfig(1)).to.be.equal("Hello")
        })
    })
    describe("Rental ", () => {
        let ErebrusUser1
        beforeEach(async () => {
            await Erebrus.editMintWindows(false)
            ErebrusUser1 = await Erebrus.connect(accounts[1])
            await ErebrusUser1.mintNFT(accounts[0].address, 1000, {
                value: pPrice
            })
        })
        it("setting Up the User", async () => {
            const time = Date.now()
            await ErebrusUser1.setUser(1, accounts[2].address, time + 600)
            expect(await Erebrus.userOf(1)).to.be.equal(accounts[2].address)
            expect(await Erebrus.userExpires(1)).to.be.equal(time + 600)
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
            await Erebrus.mintNFT(accounts[1].address, 1000, {
                value: pPrice
            })
            // Override royalty for this token to be 10% and paid to a different account
            await Erebrus.mintNFT(accounts[2].address, 1000, {
                value: pPrice
            })

            const defaultRoyaltyInfo = await Erebrus.royaltyInfo(1, 1000)
            var tokenRoyaltyInfo = await Erebrus.royaltyInfo(2, 1000)
            expect(defaultRoyaltyInfo[0]).to.be.equal(accounts[0].address)
            assert.notEqual(
                defaultRoyaltyInfo[0],
                accounts[1],
                "Default receiver is not the owner"
            )
            // Default royalty percentage taken should be 1%.
            assert.notEqual(
                defaultRoyaltyInfo[1].toNumber(),
                10,
                "Royalty fee is not 10"
            )
            assert.notEqual(
                tokenRoyaltyInfo[0],
                accounts[1],
                "Royalty receiver is not a different account"
            )
            //Default royalty percentage taken should be 10%.
            assert.equal(
                tokenRoyaltyInfo[1].toNumber(),
                100,
                "Royalty fee is not 100"
            )

            // Royalty info should be set back to default when NFT is burned
            await Erebrus.burnNFT(2)
            tokenRoyaltyInfo = await Erebrus.royaltyInfo(2, 1000)
            assert.equal(
                tokenRoyaltyInfo[0],
                accounts[0].address,
                "Royalty receiver has not been set back to default"
            )
            assert.equal(
                tokenRoyaltyInfo[1].toNumber(),
                10,
                "Royalty has not been set back to default"
            )
        })
    })
})
