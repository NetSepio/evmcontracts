// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IERC4907.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Erebrus is
    Context,
    ERC721,
    IERC4907,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC2981
{
    // Set Constants for Interface ID and Roles
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    bytes32 public constant EREBRUS_ADMIN_ROLE =
        keccak256("EREBRUS_ADMIN_ROLE");
    bytes32 public constant EREBRUS_OPERATOR_ROLE =
        keccak256("EREBRUS_OPERATOR_ROLE");
    bytes32 public constant EREBRUS_ALLOWLISTED_ROLE =
        keccak256("EREBRUS_ALLOWLISTED_ROLE");

    uint256 public immutable maxSupply; //set in the constructor

    using Strings for uint256;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    bool public revealed = false;
    bool private allowListMintOpen = false;
    bool private mintPaused = true;
    uint256 public publicSalePrice;
    uint256 public allowListSalePrice;
    string public baseURI;

    struct UserInfo {
        address user; // address of user role
        uint64 expires; // unix timestamp, user expires
    }

    modifier whenNotpaused() {
        require(mintPaused == true, "The minting is paused");
        _;
    }

    mapping(uint256 => string) public clientConfig;
    mapping(uint256 => UserInfo) internal _users; // storing the data of the user who are renting the NFT
    mapping(address => uint) public nftMints;

    event CollectionURIRevealed(string revealedURI);
    event NFTMinted(uint tokenId, address indexed owner);
    event NFTBurnt(uint tokenId, address indexed ownerOrApproved);
    event ClientConfigUpdated(uint tokenId, string data, string newData);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initialURI,
        uint256 _publicSalePrice,
        uint256 _allowListSalePrice,
        uint _maxSupply
    ) ERC721(_name, _symbol) {
        baseURI = _initialURI;
        publicSalePrice = _publicSalePrice;
        allowListSalePrice = _allowListSalePrice;
        maxSupply = _maxSupply;

        _setupRole(EREBRUS_ADMIN_ROLE, _msgSender());

        _setRoleAdmin(EREBRUS_ADMIN_ROLE, EREBRUS_ADMIN_ROLE);
        _setRoleAdmin(EREBRUS_ALLOWLISTED_ROLE, EREBRUS_OPERATOR_ROLE);
        _setRoleAdmin(EREBRUS_OPERATOR_ROLE, EREBRUS_ADMIN_ROLE);

        // Setting default royalty to 5%
        _setDefaultRoyalty(_msgSender(), 500);
    }

    function setPrice(
        uint256 _publicSalePrice,
        uint256 _allowlistprice
    ) external onlyRole(EREBRUS_ADMIN_ROLE) {
        publicSalePrice = _publicSalePrice;
        allowListSalePrice = _allowlistprice;
    }

    function pause() public onlyRole(EREBRUS_ADMIN_ROLE) {
        mintPaused = true;
    }

    function unpause() public onlyRole(EREBRUS_ADMIN_ROLE) {
        mintPaused = false;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        string memory _tokenURI = _baseURI(); //ERC721
        if (revealed) {
            return string(abi.encodePacked(_tokenURI, "/", tokenId.toString()));
        } else {
            return _tokenURI;
        }
    }

    // Modify the mint windows
    function editMintWindows(
        bool _allowListMintOpen
    ) external onlyRole(EREBRUS_ADMIN_ROLE) {
        allowListMintOpen = _allowListMintOpen;
    }

    function mintNFT() external payable whenNotpaused {
        require(
            totalSupply() <= maxSupply,
            "Erebrus: NFT Collection Sold Out!"
        );
        uint mint;
        if (allowListMintOpen) {
            // Allow List Mint
            require(
                hasRole(EREBRUS_ALLOWLISTED_ROLE, _msgSender()),
                "Erebrus: You are not on the allow list"
            );
            require(
                msg.value >= allowListSalePrice,
                "Erebrus: Not Enough Funds"
            );

            // TODO: Check Edge Case for when only 1 token remains
            uint remaining = (maxSupply * 30) / 100 - totalSupply();
            uint requestQty = msg.value / allowListSalePrice;
            require(requestQty <= 2, "Erebrus: Can't mint more than 2");
            require(
                requestQty <= remaining,
                "Ererbrus : Not enough Nft to mint"
            );
            require(
                totalSupply() <= (maxSupply * 30) / 100,
                "Erebrus: Max Supply has exceeded"
            );

            require(nftMints[_msgSender()] < 2, "Erebrus: Can't mint anymore");

            if (nftMints[_msgSender()] == 0) {
                mint = requestQty;
            } else {
                require(requestQty < 2, "Erebrus: Mint Only 2 per wallet");
                mint = requestQty;
            }
            nftMints[_msgSender()] += requestQty;
            for (uint8 i = 0; i < mint; i++) {
                _tokenIdCounter.increment();
                uint256 tokenId = _tokenIdCounter.current();
                _safeMint(_msgSender(), tokenId);
                emit NFTMinted(tokenId, _msgSender());
            }
        } else {
            // Public Mint
            require(msg.value >= publicSalePrice, "Erebrus: Not Enough Funds");
            require(nftMints[_msgSender()] < 1, "Erebrus: Can't mint anymore");
            mint = 1;
            nftMints[_msgSender()] += 1;

            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(_msgSender(), tokenId);
            emit NFTMinted(tokenId, _msgSender());
        }
    }

    /**
     *  Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burnNFT(uint256 tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Erebrus: caller is not token owner or approved"
        );
        _burn(tokenId);
        emit NFTBurnt(tokenId, _msgSender());
        _resetTokenRoyalty(tokenId);
    }

    function _setBaseURI(string memory _tokenBaseURI) internal {
        baseURI = _tokenBaseURI;
    }

    /**
     *  Reveals the collection metadata baseURI.
     *
     * Requirements:
     *
     * - The caller must have Admin Role.
     */
    function revealCollection(
        string memory _revealURI
    ) external onlyRole(EREBRUS_ADMIN_ROLE) {
        if (revealed) {
            _setBaseURI(_revealURI);
            revealed = true;
            emit CollectionURIRevealed(_revealURI);
        }
    }

    // Admin can withdraw the Funds collected
    function withdraw() external onlyRole(EREBRUS_ADMIN_ROLE) {
        // get the balance of the contract
        (bool callSuccess, ) = payable(_msgSender()).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    /*****  Update Client Config *******/

    function writeClientConfig(
        uint256 tokenId,
        string memory newData
    ) external onlyRole(EREBRUS_ADMIN_ROLE) {
        require(_exists(tokenId), "Erebrus: Non-Existent Token");
        clientConfig[tokenId] = newData;
        emit ClientConfigUpdated(tokenId, clientConfig[tokenId], newData);
    }

    /** ERC4907 Functionalities **/

    /// @notice set the user and expires of an NFT
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires

    function setUser(
        uint256 tokenId,
        address user,
        uint64 expires
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Erebrus: Caller is not owner nor approved"
        );
        UserInfo storage info = _users[tokenId];
        info.user = user;
        info.expires = expires;
        emit UpdateUser(tokenId, user, expires);
    }

    /********************************************* */

    /** Getter Functions **/

    /// @notice get the clientConfig[Data Token]
    function readClientConfig(
        uint256 tokenId
    ) external view returns (string memory) {
        require(_exists(tokenId), "Erebrus: Non-Existent Token");
        return clientConfig[tokenId];
    }

    /// @notice Get the user address of an NFT
    /// @dev The zero address indicates that there is no user or the user is expired
    /// @param tokenId The NFT to get the user address for
    /// @return The user address for this NFT
    function userOf(
        uint256 tokenId
    ) public view virtual override returns (address) {
        if (uint256(_users[tokenId].expires) >= block.timestamp) {
            return _users[tokenId].user;
        } else {
            return address(0);
        }
    }

    /// @notice Get the user expires of an NFT
    /// @dev The zero value indicates that there is no user
    /// @param tokenId The NFT to get the user expires for
    /// @return The user expires for this NFT
    function userExpires(
        uint256 tokenId
    ) public view virtual override returns (uint256) {
        return _users[tokenId].expires;
    }

    /************************************* */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 /* batchSize*/
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, 1);

        if (from != to && _users[tokenId].user != address(0)) {
            delete _users[tokenId];
            emit UpdateUser(tokenId, address(0), 0);
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        if (interfaceId == _INTERFACE_ID_ERC2981) return true;
        if (interfaceId == type(IERC4907).interfaceId) return true;
        return super.supportsInterface(interfaceId);
    }
}
