// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./common/IERC4907.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./common/extensions/ERC721ABurnable.sol";

contract Erebrus is
    Context,
    IERC4907,
    AccessControlEnumerable,
    ERC721ABurnable,
    ERC2981
{
    // Set Constants for Interface ID and Roles
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    bytes32 public constant EREBRUS_ADMIN_ROLE =
        keccak256("EREBRUS_ADMIN_ROLE");
    bytes32 public constant EREBRUS_OPERATOR_ROLE =
        keccak256("EREBRUS_OPERATOR_ROLE");

    uint256 public immutable maxSupply; // Set in the constructor

    using Strings for uint256;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    bool public collectionRevealed = false;
    bool public mintPaused = true;
    uint256 public publicSalePrice;
    string public baseURI;
    uint256 public platFormFeeBasisPoint;

    struct RentableItems {
        bool isRentable; //to check is renting is available
        address user; // address of user role
        uint64 expires; // unix timestamp, user expires
        uint256 hourlyRate; // amountPerHour
    }

    modifier whenNotpaused() {
        require(mintPaused == false, "Erebrus: NFT Minting Paused");
        _;
    }

    mapping(uint256 => string) public clientConfig;
    mapping(uint256 => RentableItems) internal rentables; // storing the data of the user who are renting the NFT
    mapping(address => uint256) public nftMints;

    event CollectionURIRevealed(string revealedURI);
    event NFTMinted(uint256 tokenId, address indexed owner);
    event NFTBurnt(uint256 tokenId, address indexed ownerOrApproved);
    event ClientConfig(uint256 tokenId, string clientConfig);
    event RentalInfo(
        uint256 tokenId,
        bool isRentable,
        uint256 price,
        address indexed renter
    );

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initialURI,
        uint256 _publicSalePrice,
        uint256 _maxSupply,
        uint256 _platFormFeeBasisPoint
    ) ERC721A(_name, _symbol) {
        baseURI = _initialURI;
        publicSalePrice = _publicSalePrice;
        maxSupply = _maxSupply;
        platFormFeeBasisPoint = _platFormFeeBasisPoint;

        _setupRole(EREBRUS_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(EREBRUS_ADMIN_ROLE, EREBRUS_ADMIN_ROLE);
        _setRoleAdmin(EREBRUS_OPERATOR_ROLE, EREBRUS_ADMIN_ROLE);

        // add Admin to operator
        grantRole(EREBRUS_OPERATOR_ROLE, _msgSender());

        // Setting default royalty to 5%
        _setDefaultRoyalty(_msgSender(), 500);
    }

    ///@notice Function to update the plateformFeeBasisPoint
    function updateFee(
        uint256 _platFormFeeBasisPoint
    ) external onlyRole(EREBRUS_OPERATOR_ROLE) {
        platFormFeeBasisPoint = _platFormFeeBasisPoint;
    }

    /// @notice Admin Role can set the mint price
    function setPrice(
        uint256 _publicSalePrice
    ) external onlyRole(EREBRUS_ADMIN_ROLE) {
        publicSalePrice = _publicSalePrice;
    }

    /// @notice pause or stop the contract from working by ADMIN
    function pause() public onlyRole(EREBRUS_OPERATOR_ROLE) {
        mintPaused = true;
    }

    /// @notice Unpause the contract by ADMIN
    function unpause() public onlyRole(EREBRUS_OPERATOR_ROLE) {
        mintPaused = false;
    }

    /// @notice Call to mint NFTs
    function mintNFT(uint256 quantity) external payable whenNotpaused {
        require(totalSupply() <= maxSupply, "Erebrus: Collection Sold Out!");
        require(
            publicSalePrice * quantity >= msg.value,
            "Sotreus: Insuffiecient amount!"
        );
        _safeMint(_msgSender(), quantity);
    }

    /**
     * @notice Burns `tokenId`. See {ERC721-_burn}.
     *
     * @dev Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burnNFT(uint256 _tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "Erebrus: Not Owner Or Approved"
        );
        _burn(_tokenId);
        emit NFTBurnt(_tokenId, _msgSender());
        _resetTokenRoyalty(_tokenId);
    }

    function _setBaseURI(string memory _tokenBaseURI) internal {
        baseURI = _tokenBaseURI;
    }

    /**
     *  @notice Reveals the collection metadata baseURI.
     *
     * @dev Requirements:
     *
     * - The caller must have Admin Role.
     */
    function revealCollection(
        string memory _revealURI
    ) external onlyRole(EREBRUS_ADMIN_ROLE) {
        require(
            collectionRevealed == false,
            "Erebrus: Collection Already Revealed"
        );
        _setBaseURI(_revealURI);
        collectionRevealed = true;
        emit CollectionURIRevealed(_revealURI);
    }

    /// @notice Admin can withdraw the funds collected
    function withdraw() external onlyRole(EREBRUS_ADMIN_ROLE) {
        // get the balance of the contract
        (bool callSuccess, ) = payable(_msgSender()).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Erebrus: Withdrawal failed");
    }

    /*****  Update Client Config *******/

    /// @notice  set the clientConfig [Data token]
    function writeClientConfig(
        uint256 _tokenId,
        string memory _clientConfig
    ) external onlyRole(EREBRUS_OPERATOR_ROLE) whenNotpaused {
        require(_exists(_tokenId), "Erebrus: Non-Existent Token");
        clientConfig[_tokenId] = _clientConfig;
        emit ClientConfig(_tokenId, _clientConfig);
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
    ) public virtual override whenNotpaused {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Erebrus: Not token owner Or approved"
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

    /// @notice Owner can set the NFT's rental price and status
    function setRentInfo(
        uint256 tokenId,
        bool isRentable,
        uint256 pricePerHour
    ) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Erebrus: Caller is not token owner or approved"
        );
        rentables[tokenId].isRentable = isRentable;
        rentables[tokenId].hourlyRate = pricePerHour;

        emit RentalInfo(tokenId, isRentable, pricePerHour, _msgSender());
    }

    /// @notice to use for renting an item
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT,
    /// time cannot be less than 1 hour or more than 6 months
    /// @param _timeInHours  is in hours , Ex- 1,2,3

    function rent(
        uint256 _tokenId,
        uint256 _timeInHours
    ) external payable whenNotpaused {
        require(
            rentables[_tokenId].isRentable,
            "Erebrus: Not available for rent"
        );
        require(
            userOf(_tokenId) == address(0),
            "Erebrus: NFT Already Subscribed"
        );
        require(_timeInHours > 0, "Erebrus: Time can't be less than 1 hour");
        require(
            _timeInHours <= 4320,
            "Erebrus: Time can't be more than 6 months"
        );

        uint256 amount = amountRequired(_tokenId, _timeInHours);

        require(msg.value >= amount, "Erebrus: Insufficient Funds");

        uint256 payoutForCreator = (msg.value * platFormFeeBasisPoint) / 1000;
        payable(ownerOf(_tokenId)).transfer(payoutForCreator);

        RentableItems storage info = rentables[_tokenId];
        info.user = _msgSender();
        info.expires = uint64(block.timestamp + (_timeInHours * 3600));
        emit UpdateUser(_tokenId, _msgSender(), info.expires);
    }

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
    /// to rent an item for a certain time
    function amountRequired(
        uint256 tokenId,
        uint256 time
    ) public view returns (uint256) {
        uint256 amount = rentables[tokenId].hourlyRate * time;
        return amount;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721A, IERC721A) returns (string memory) {
        string memory _tokenURI = _baseURI(); //ERC721
        if (collectionRevealed) {
            return string(abi.encodePacked(_tokenURI, "/", tokenId.toString()));
        } else {
            return _tokenURI;
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _isApprovedOrOwner(
        address user,
        uint256 tokenId
    ) private view returns (bool) {
        return (isApprovedForAll(ownerOf(tokenId), user) ||
            ownerOf(tokenId) == user);
    }

    /************************************* */

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override(ERC721A) {
        if (from != to && rentables[startTokenId].user != address(0)) {
            delete rentables[startTokenId];
            emit UpdateUser(startTokenId, address(0), 0);
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721A, IERC721A, ERC2981)
        returns (bool)
    {
        if (interfaceId == _INTERFACE_ID_ERC2981) return true;
        if (interfaceId == type(IERC4907).interfaceId) return true;
        return super.supportsInterface(interfaceId);
    }
}
