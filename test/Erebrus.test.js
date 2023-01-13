const { ethers, run, network } = require("hardhat")
const { expect, assert, use } = require("chai")

describe("Nft ", function () {
    let NftFactory, sendValue, Nft
    let pPrice = ethers.utils.parseEther("1")
    let aPrice = ethers.utils.parseEther("0.01")

    beforeEach(async function () {
        NftFactory = await ethers.getContractFactory("Erebrus")
        Nft = await NftFactory.deploy("www.notreveal.com", pPrice, aPrice)
        accounts = await ethers.getSigners()
        sendValue = await ethers.utils.parseEther("1")
    })
    it("To check if the Constructor is working ", async () => {
        let URI = await Nft.baseURI()
        let allowlistingPrice = await Nft.allowListprice()
        let publicMintingPrice = await Nft.publicprice()
        let price1 = ethers.utils.parseEther("1")
        let price2 = ethers.utils.parseEther("0.01")
        y
        assert(URI.toString() == "www.notreveal.com")
        assert(publicMintingPrice.toString() == price1.toString())
    })

    it("to check the set Price property", async () => {
        const Publicprice = ethers.utils.parseEther("2")
        const AllowPrice = ethers.utils.parseEther("0.02")
        Nft.setPrice(Publicprice, AllowPrice)
        let allowlistingPrice = await Nft.allowListprice()
        let publicMintingPrice = await Nft.publicprice()
        assert(allowlistingPrice, AllowPrice)
        assert(publicMintingPrice, Publicprice)
    })

    it("To check if the reveal , public minting  & editMintWindows is working or not", async function () {
        Nft.editMintWindows(true, false)
        for (let i = 0; i < 2; i++) {
            await Nft.publicMint({ value: sendValue })
        }
        const Uri = "www.example.xyz"
        await Nft.reveal()
        await Nft.setRevealUri(Uri)
        const Reveal_URI = await Nft.tokenURI(1)

        assert.equal(Reveal_URI.toString(), Uri)
    })

    it("to  check allowlist mint is working or not and minting in specific amount or not", async () => {
        Nft.editMintWindows(false, true)
        const accounts = await ethers.getSigners()
        const userAddress = accounts[0].address
        Nft.UpdateAllowList(userAddress, true)
        // const list = await Nft.allowList(userAddress)
        for (let i = 0; i < 6; i++) {
            Nft.allowListMint({ value: ethers.utils.parseEther("0.01") })
            Total = await Nft.TotalMinted()
        }
    })

    describe("withdraw", function () {
        let accounts, deployer
        beforeEach(async () => {
            Nft.editMintWindows(true, false)
            sendValue = ethers.utils.parseEther("1")
            accounts = await ethers.getSigners()
            for (let i = 1; i < 4; i++) {
                const NftConnectedContract = await Nft.connect(
                    accounts[i].address
                )
                NftConnectedContract.publicMint({ value: sendValue })
            }
        })
        it("withdraws ETH from a single funder", async () => {
            // Arrange
            deployer = accounts[0].address
            // Assert
            const startingNftBalance = await Nft.provider.getBalance(
                Nft.address
            )
            const startingDeployerBalance = await Nft.provider.getBalance(
                deployer
            )

            // Act
            const transactionResponse = await Nft.withdraw()
            const transactionReceipt = await transactionResponse.wait()
            const { gasUsed, effectiveGasPrice } = transactionReceipt
            const gasCost = gasUsed.mul(effectiveGasPrice)

            const endingNftBalance = await Nft.provider.getBalance(Nft.address)
            const endingDeployerBalance = await Nft.provider.getBalance(
                deployer
            )

            assert.equal(endingNftBalance, 0)
            assert.equal(
                startingNftBalance.add(startingDeployerBalance).toString(),
                endingDeployerBalance.add(gasCost).toString()
            )
        })
        it("Only allows the owner to withdraw", async function () {
            const accounts = await ethers.getSigners()
            const NftConnectedContract = await Nft.connect(accounts[1])
            await expect(NftConnectedContract.withdraw()).to.be.revertedWith(
                "Ownable: caller is not the owner"
            )
        })
    })
    // describe("Rental contract", () => {
    //     let timeNow
    //     let time
    //     let User
    //     beforeEach(async function () {
    //         Nft.editMintWindows(true, false)
    //         for (let i = 1; i < 4; i++) {
    //             const NftConnectedContract = await Nft.connect(
    //                 accounts[i].address
    //             )
    //             NftConnectedContract.publicMint({ value: sendValue })
    //         }
    //         User = "0x617F2E2fD72FD9D5503197092aC168c91465E7f2"
    //         timeNow = Date.now()
    //         time = time + 3600

    //         console.log(`Time is ${time}`)
    //         Nft.setUser(3, User, time)
    //     })
    //     it("check setUser,Userof ,UserExpires", async () => {
    //         console.log(`The address is ${User}`)
    //         Renter = await Nft.userOf(3)
    //         console.log(`The Renter address is ${Renter}`)
    //         Expirydate = await Nft.userExpires(3)
    //         //assert.equal(Renter, User)
    //         assert.equal(Expirydate, time)
    //     })
    // })
})
