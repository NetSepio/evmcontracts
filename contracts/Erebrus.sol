// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./Reveal.sol";
import "hardhat/console.sol";

import "./@rarible/royalties/contracts/RoyaltiesV2.sol";
import "./@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "./@rarible/royalties/contracts/IERC2981.sol";
import "./@rarible/royalties/contracts/LibRoyaltiesV2.sol";
import "./@rarible/royalties/contracts/LibPart.sol";

contract Erebrus is Reveal, RoyaltiesV2Impl {
    event TokenURIRevealed(string revealedURI);
    mapping(address => bool) public allowList;

    using Counters for Counters.Counter;

    uint256 public immutable i_maxSupply = 2000; //2000

    uint256 private totalSupply = 0;

    uint balance;
    bool private allowListMintOpen = false;
    bool private pause = true;
    uint256 public publicprice;
    uint256 public allowListprice;

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
        uint256 _tokenId
    ) public view override returns (string memory) {
        string memory batchUri = _getBaseURI(); //ERC721
        if (revealed) {
            return string(abi.encodePacked(batchUri, "/"));
        } else {
            return batchUri;
        }
    }

    function reveal(
        bytes memory _key
    ) public onlyOwner returns (string memory revealedURI) {
        console.log("The function started");
        require(_canReveal(), "Not authorized");
        revealedURI = getRevealURI(batchId, _key);
        _setBaseURI(revealedURI);

        emit TokenURIRevealed(revealedURI);
    }

    function set_Password(
        string memory _Pass
    ) external returns (string memory) {
        require(revealed, "It is still not activated");
        bytes memory code = abi.encodePacked(_Pass);
        string memory _URI = reveal(code);
        return _URI;
    }

    function _setBaseURI(string memory _URI) private onlyOwner {
        baseURI = _URI;
    }

    function UpdateAllowList(address _user, bool _flag) external onlyOwner {
        allowList[_user] = _flag;
    }

    // Modify the mint windows
    function editMintWindows(bool _allowListMintOpen) external onlyOwner {
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
    function publicMint() public payable whenNotpause returns (address) {
        require(!allowListMintOpen, "Still the minting can't be started");
        require(msg.value >= publicprice, "Not Enough Funds");
        internalMint();
        return msg.sender;
    }

    function internalMint() internal {
        require(totalSupply < i_maxSupply, "We Sold Out!");
        uint256 tokenId = _tokenIdCounter.current();
        totalSupply++;
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    // Populate the Allow List
    function setAllowList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            allowList[addresses[i]] = true;
        }
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

    function withdraw() external onlyOwner whenNotpause {
        // get the balance of the contract
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    /**Getter Functions **/

    function _getBaseURI() internal view returns (string memory) {
        return baseURI;
    }

    function TotalMinted() external view onlyOwner returns (uint) {
        return totalSupply;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        if (interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) return true;
        if (interfaceId == _INTERFACE_ID_ERC2981) return true;
        return super.supportsInterface(interfaceId);
    }
}
