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

    bool public collectionRevealed = false;
    bool public mintPaused = true;
    bool public allowListMintOpen = false;
    uint256 public publicSalePrice;
    uint256 public allowListSalePrice;
    string public baseURI;
    uint256 public platFormFeeBasisPoint;

    //function to update the plateformfeebasispoint

    struct RentableItems {
        bool isRentable; //to check is renting is available
        address user; // address of user role
        uint64 expires; // unix timestamp, user expires
        uint256 amountPerMinute;
    }

    modifier whenNotpaused() {
        require(mintPaused == false, "Erebrus: NFT Minting Paused");
        _;
    }

    mapping(uint256 => string) public clientConfig;
    mapping(uint256 => RentableItems) internal rentables; // storing the data of the user who are renting the NFT
    mapping(address => uint) public nftMints;

    event CollectionURIRevealed(string revealedURI);
    event NFTMinted(uint tokenId, address indexed owner);
    event NFTBurnt(uint tokenId, address indexed ownerOrApproved);
    event ClientConfigUpdated(uint tokenId, string data, string newData);
    event RentalInfo(
        uint256 tokenId,
        bool isRentable,
        uint256 price,
        address indexed Renter
    );

    constructor(
        string memory name,
        string memory symbol,
        string memory initialURI,
        uint256 _publicSalePrice,
        uint256 _allowListSalePrice,
        uint _maxSupply,
        uint256 _platFormFeeBasisPoint
    ) ERC721(name, symbol) {
        baseURI = initialURI;
        publicSalePrice = _publicSalePrice;
        allowListSalePrice = _allowListSalePrice;
        maxSupply = _maxSupply;
        platFormFeeBasisPoint = _platFormFeeBasisPoint;

        _setupRole(EREBRUS_ADMIN_ROLE, _msgSender());

        _setRoleAdmin(EREBRUS_ADMIN_ROLE, EREBRUS_ADMIN_ROLE);
        _setRoleAdmin(EREBRUS_ALLOWLISTED_ROLE, EREBRUS_OPERATOR_ROLE);
        _setRoleAdmin(EREBRUS_OPERATOR_ROLE, EREBRUS_ADMIN_ROLE);

        // Setting default royalty to 5%
        _setDefaultRoyalty(_msgSender(), 500);
    }

    ///@notice set the plaformFeeBasisPoint
    function updateFee(
        uint256 _platFormFeeBasisPoint
    ) external onlyRole(EREBRUS_OPERATOR_ROLE) {
        platFormFeeBasisPoint = _platFormFeeBasisPoint;
    }

    /// @notice set the price of the minting by ADMIN
    function setPrice(
        uint256 _publicSalePrice,
        uint256 _allowlistprice
    ) external onlyRole(EREBRUS_ADMIN_ROLE) {
        publicSalePrice = _publicSalePrice;
        allowListSalePrice = _allowlistprice;
    }

    /// @notice pause or stop the contract from working by ADMIN
    function pause() public onlyRole(EREBRUS_ADMIN_ROLE) {
        mintPaused = true;
    }

    /// @notice Unpause the contract by ADMIN
    function unpause() public onlyRole(EREBRUS_ADMIN_ROLE) {
        mintPaused = false;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        string memory _tokenURI = _baseURI(); //ERC721
        if (collectionRevealed) {
            return string(abi.encodePacked(_tokenURI, "/", tokenId.toString()));
        } else {
            return _tokenURI;
        }
    }

    /// @notice Modify the mint windows
    function editMintWindows(
        bool _allowListMintOpen
    ) external onlyRole(EREBRUS_ADMIN_ROLE) {
        allowListMintOpen = _allowListMintOpen;
    }

    /// @notice to mint NFT's
    function mintNFT() external payable whenNotpaused {
        require(totalSupply() <= maxSupply, "Erebrus: Collection Sold Out!");
        uint mint;
        if (allowListMintOpen) {
            // Allow List Mint
            require(
                hasRole(EREBRUS_ALLOWLISTED_ROLE, _msgSender()),
                "Erebrus: Only For Allowlisted"
            );
            require(
                msg.value >= allowListSalePrice,
                "Erebrus: Not Enough Funds"
            );
            // Check Edge Case for when only 1 token remains
            uint availability = (maxSupply * 30) / 100 - totalSupply();
            uint requestQty = msg.value / allowListSalePrice;

            require(
                totalSupply() <= (maxSupply * 30) / 100,
                "Erebrus: Max Supply Exceeded"
            );
            require(requestQty <= 2, "Erebrus: Can't Mint More Than 2");
            require(
                requestQty <= availability,
                "Ererbrus : NFT Qty Unavailable"
            );
            require(nftMints[_msgSender()] < 2, "Erebrus: Can't Mint Anymore");

            if (nftMints[_msgSender()] == 0) {
                mint = requestQty;
            } else {
                require(requestQty < 2, "Erebrus: Mint Only 2 Per Wallet");
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
            require(msg.value >= publicSalePrice, "Erebrus: Not enough funds");
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
            "Erebrus: Not Owner Or Approved"
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
        if (collectionRevealed) {
            _setBaseURI(_revealURI);
            collectionRevealed = true;
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
    /// @dev This function is used to gift a person by the owner,
    /// The zero address indicates there is no user
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
            "Erebrus: Caller is not  token owner Or approved"
        );
        require(
            userOf(tokenId) == address(0),
            "Erebrus: Item is already subscribed"
        );
        RentableItems storage info = rentables[tokenId];
        info.user = user;
        info.expires = expires;
        emit UpdateUser(tokenId, user, expires);
    }

    /// @notice set tht rentable price and status by the owner
    function setRentInfo(
        uint256 tokenId,
        bool isRentable,
        uint256 amountPerMinute
    ) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Erebrus: Caller is not  token owner Or approved"
        );
        rentables[tokenId].isRentable = isRentable;
        rentables[tokenId].amountPerMinute = amountPerMinute;

        emit RentalInfo(tokenId, isRentable, amountPerMinute, _msgSender());
    }

    /// @notice to use for renting an item
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT,
    /// time cannot be less than 1 hour or more than 6 months
    /// @param time  is in hours , Ex- 1,2,3

    function rent(uint tokenId, uint256 time) external payable {
        require(
            rentables[tokenId].isRentable,
            "Erebrus: Item is not open for renting"
        );
        require(
            userOf(tokenId) == address(0),
            "Erebrus: Item is already subscribed"
        );
        require(time > 0, "Erebrus: Time cannot be less than 1 hour");
        require(time <= 4320, "Erebrus: Time cannot be more than 6 months");

        uint amount = amoutRequire(tokenId, time);

        require(msg.value >= amount, "Erebrus: Insufficient Funds");

        uint256 payoutForCreator = (msg.value * platFormFeeBasisPoint) / 1000;
        payable(ownerOf(tokenId)).transfer(payoutForCreator);

        RentableItems storage info = rentables[tokenId];
        info.user = _msgSender();
        info.expires = uint64(block.timestamp + (time * 3600));
        emit UpdateUser(tokenId, _msgSender(), info.expires);
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
        if (uint256(rentables[tokenId].expires) >= block.timestamp) {
            return rentables[tokenId].user;
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
        return rentables[tokenId].expires;
    }

    /// @notice to calculate the amount of money required
    /// to rent a item for an certain time
    function amoutRequire(
        uint256 tokenId,
        uint256 time
    ) public view returns (uint256) {
        uint256 amount = rentables[tokenId].amountPerMinute * (time * 60);
        return amount;
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

        if (from != to && rentables[tokenId].user != address(0)) {
            delete rentables[tokenId];
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
