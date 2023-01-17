const { expect } = require("chai");
const { ethers, run, network, assert, artifacts } = require("hardhat");
const { BN, constants, expectEvent, expectRevert, makeInterfaceId } = require('@openzeppelin/test-helpers');

const Erebrus = artifacts.require("Erebrus");

let accounts;
let erebrus;
let admin;
let operator;
let whitelisted;
let stranger;

const INTERFACES = {
	ERC165: [
	  'supportsInterface(bytes4)',
	],
	AccessControl: [
	  'hasRole(bytes32,address)',
	  'getRoleAdmin(bytes32)',
	  'grantRole(bytes32,address)',
	  'revokeRole(bytes32,address)',
	  'renounceRole(bytes32,address)'
	],
	AccessControlEnumerable: [
	  'getRoleMember(bytes32,uint256)',
	  'getRoleMemberCount(bytes32)'
	],
	ERC721: [
	  'balanceOf(address)',
	  'ownerOf(uint256)',
	  'approve(address,uint256)',
	  'getApproved(uint256)',
	  'setApprovalForAll(address,bool)',
	  'isApprovedForAll(address,address)',
	  'transferFrom(address,address,uint256)',
	  'safeTransferFrom(address,address,uint256)',
	  'safeTransferFrom(address,address,uint256,bytes)',
	],
	ERC721Enumerable: [
	  'totalSupply()',
	  'tokenOfOwnerByIndex(address,uint256)',
	  'tokenByIndex(uint256)',
	],
	ERC721Metadata: [
	  'name()',
	  'symbol()',
	  'tokenURI(uint256)',
	]
};

const EREBRUS_ADMIN_ROLE = ethers.utils.keccak256(Buffer.from('EREBRUS_ADMIN_ROLE'));
const EREBRUS_OPERATOR_ROLE = ethers.utils.keccak256(Buffer.from('EREBRUS_OPERATOR_ROLE'));
const EREBRUS_WHITELISTED_ROLE = ethers.utils.keccak256(Buffer.from('EREBRUS_WHITELISTED_ROLE'));

describe("Erebrus ", function() {
    let pPrice = ethers.utils.parseEther("1")
    let aPrice = ethers.utils.parseEther("0.01")

    before(async function () {
		accounts = await ethers.getSigners();
		admin = accounts[0];
		moderator = accounts[1];
		voter = accounts[2];
		stranger = accounts[3];
		erebrus = await Erebrus.new("EREBRUS", "ERBS", "http://localhost:9080/artwork/", pPrice, aPrice, 10);
	});

    // beforeEach(async () => {
    //     accounts = await ethers.getSigners()
    //     deployer = (await getNamedAccounts()).deployer
    //     await deployments.fixture(["all"])
    //     Erebrus = await ethers.getContract("Erebrus", deployer)
    // })

    describe("Constructor", function() {
        it("To check if the Constructor is working ", async () => {
            let URI = await Erebrus.baseURI()
            let allowlistingPrice = await Erebrus.allowListprice()
            let publicMintingPrice = await Erebrus.publicprice()
            assert(URI.toString() == "http://localhost:9080/artwork/")
            assert(publicMintingPrice.toString() == pPrice.toString())
            assert(allowlistingPrice.toString() == aPrice.toString())
        })

        it("Initializes the NFT Correctly.", async () => {
            const name = await Erebrus.name()
            const symbol = await Erebrus.symbol()
            assert.equal(name, "NFT")
            assert.equal(symbol, "NFT")
        })
    })

    describe("Mint", () => {
        it("Public minting  & editMintWindows ", async function() {
            Erebrus.editMintWindows(false)
            await Erebrus.publicMint({ value: pPrice })
            const _BalanceOf = await Erebrus.balanceOf(deployer)
            const Total = await Erebrus.TotalMinted()
            assert.equal(_BalanceOf, 1)
            assert.equal(Total, 1)
        })
        it("Allowlist", async () => {
            let accounts = await ethers.getSigners()
            Erebrus.editMintWindows(true)
            Erebrus.UpdateAllowList(accounts[1].address, true)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            await ErebrusConnectedContract.allowListMint({ value: aPrice })
            const _BalanceOf = await Erebrus.balanceOf(accounts[1].address)
            assert.equal(_BalanceOf.toString(), "1")
        })
        it("only the allowlist users can mint", async () => {
            // const accounts = await ethers.getSigners()
            Erebrus.editMintWindows(true)
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            expect(
                ErebrusConnectedContract.allowListMint({ value: aPrice })
            ).to.be.revertedWith("You are not on the allow list")
            Erebrus.UpdateAllowList(accounts[1].address, true)
        })
    })
    describe("Withdraw", () => {
        beforeEach(async () => {
            // const accounts = await ethers.getSigners()
            Erebrus.editMintWindows(true)

            for (let i = 1; i < 2; i++) {
                const ErebrusConnectedContract = await Erebrus.connect(
                    accounts[i]
                )
                ErebrusConnectedContract.publicMint({ value: pPrice })
            }
        })
        it("withdraws ETH from a single funder", async () => {
            // const accounts = await ethers.getSigners()
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
            // const accounts = await ethers.getSigners()
            const ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            await expect(
                ErebrusConnectedContract.withdraw()
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })
    describe("Rental", () => {
        let ErebrusConnectedContract
        beforeEach(async () => {
            Erebrus.editMintWindows(true)
            //ErebrusConnectedContract = await Erebrus.connect(accounts[1])
            //ErebrusConnectedContract.publicMint({ value: pPrice })
            Erebrus.publicMint({ value: pPrice })
        })
        it("setting the user  & checking the ongoing user and expiry", async () => {
            const User2 = accounts[2]
            const timestamp = Date.now()
            const expiry = timestamp + 600
            Erebrus.setUser(1, User2.address, expiry)
            const _UserOf = await Erebrus.userOf(1)
            const _UserExpires = await Erebrus.userExpires(1)
            // assert.equal(_UserOf, User2.address)
            //assert.equal(_UserExpires.toString(), expiry)
        })
    })
    describe("Reveal", () => {
        it("checking Reveal", async () => {
            let URI = await Erebrus.tokenURI(1)
            assert.equal(URI.toString(), "https://github.com/")
            Erebrus.setReveal("www.xyz.com", "key")
            await Erebrus.revealActivated()
            const Reveal = await Erebrus.RevealStatus()
            const RevealedURI = await Erebrus.set_Password("key")
            URI = await Erebrus.tokenURI(1)
            console.log(`the uri is ${URI}`)
            assert.equal(URI, "www.xyz.com/")
        })
    })
})