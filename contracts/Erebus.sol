// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Subscription.sol";
import "hardhat/console.sol";

import "./@rarible/royalties/contracts/RoyaltiesV2.sol";
import "./@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "./@rarible/royalties/contracts/IERC2981.sol";
import "./@rarible/royalties/contracts/LibRoyaltiesV2.sol";
import "./@rarible/royalties/contracts/LibPart.sol";

contract Erebus is Subscription, Ownable, RoyaltiesV2Impl {
    mapping(address => bool) public allowList;

    using Counters for Counters.Counter;

    uint256 public immutable i_maxSupply = 2000; //2000

    string private revealURI;
    uint256 private totalSupply = 0;

    uint balance;

    bool private publicMintOpen = false;
    bool private allowListMintOpen = false;
    bool private pause = true;
    uint256 public publicprice;
    uint256 public allowListprice;
    bool public revealed = false;
    string public baseURI;
    Counters.Counter private _tokenIdCounter;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    modifier whenNotpause() {
        require(pause == true, "The minting is stopped");
        _;
    }

    constructor(
        string memory BaseURI,
        uint256 _publicprice,
        uint256 _allowListprice
    ) {
        baseURI = BaseURI;
        publicprice = _publicprice;
        allowListprice = _allowListprice;
    }

    function setRevealUri(string memory _uri) external onlyOwner {
        revealURI = _uri;
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    function Pause(bool _pause) external onlyOwner {
        pause = _pause;
    }

    function setPrice(
        uint256 _publicprice,
        uint256 _allowlistprice
    ) external onlyOwner {
        publicprice = _publicprice;
        allowListprice = _allowlistprice;
    }

    //reveal the token URI by overriding the function
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(tokenId <= totalSupply, "non existent token");
        if (revealed != true) {
            return super.tokenURI(tokenId);
        } else {
            return revealURI;
        }
    }

    function UpdateAllowList(address _user, bool _flag) external onlyOwner {
        allowList[_user] = _flag;
    }

    // Modify the mint windows
    function editMintWindows(
        bool _publicMintOpen,
        bool _allowListMintOpen
    ) external onlyOwner {
        publicMintOpen = _publicMintOpen;
        allowListMintOpen = _allowListMintOpen;
    }

    // require only the allowList people to mint
    // Add publicMint and allowListMintOpen Variables
    function allowListMint() public payable whenNotpause {
        require(allowListMintOpen, "Allowlist Mint Closed");
        require(allowList[msg.sender], "You are not on the allow list");
        require(msg.value == allowListprice, "Not Enough Funds");
        require(totalSupply < (i_maxSupply * 30) / 100, "Supply is exceeded");

        internalMint();
    }

    // Add Payment
    // Add limiting of supply
    function publicMint() public payable whenNotpause {
        require(publicMintOpen, "Public Mint Closed");
        require(!allowListMintOpen, "Still the minting can't be started");
        require(msg.value == publicprice, "Not Enough Funds");
        internalMint();
    }

    function internalMint() internal {
        require(totalSupply < i_maxSupply, "We Sold Out!");
        uint256 tokenId = _tokenIdCounter.current();
        totalSupply++;
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    function withdraw() external onlyOwner whenNotpause {
        // get the balance of the contract
        uint256 balalnce = address(this).balance;
        payable(msg.sender).transfer(balalnce);
    }

    // Populate the Allow List
    function setAllowList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            allowList[addresses[i]] = true;
        }
    }

    /**Getter Functions **/

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function TotalMinted() external view onlyOwner returns (uint) {
        return totalSupply;
    }

    function payout() public view onlyOwner returns (uint) {
        return address(msg.sender).balance;
    }

    /** ROYALTIES **/
    function setRoyalties(
        uint _tokenId,
        address payable _royaltiesReceipientAddress,
        uint96 _percentageBasisPoints
    ) public onlyOwner {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        if (interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) return true;
        if (interfaceId == _INTERFACE_ID_ERC2981) return true;
        return super.supportsInterface(interfaceId);
    }
}
