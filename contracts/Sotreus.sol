// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "./common/interface/IERC5643.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./common/ERC721A/extensions/ERC721ABurnable.sol";

contract Sotreus is
    Context,
    AccessControlEnumerable,
    ERC721ABurnable,
    ERC2981,
    IERC5643
{
    // Set Constants for Interface ID and Roles
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    bytes32 public constant SOTREUS_ADMIN_ROLE =
        keccak256("SORTREUS_ADMIN_ROLE");
    bytes32 public constant SOTREUS_OPERATOR_ROLE =
        keccak256("SORTREUS_OPERATOR_ROLE");

    //UNIX TIME FOR ONE MONTH
    uint256 constant MONTH = 2592000;
    uint public constant WEEK = 648000;

    uint256 public immutable maxSupply; // Set in the constructor

    using Strings for uint256;

    bool public collectionRevealed = false;
    bool public mintPaused = true;
    uint256 public publicSalePrice;
    uint256 public platFormFeeBasisPoint;
    uint256 public subscriptionPricePerMonth;
    string public baseURI;

    mapping(address => mapping(uint256 => bool)) public managers;
    mapping(uint256 => string) public clientConfig;
    /// @notice To store subscription info
    mapping(uint256 => uint64) private _expirations;
    /// @notice Subscription allocated by contract Creator to a user
    mapping(uint256 => uint64) private _operatorRenewal;

    event CollectionURIRevealed(string revealedURI);
    event NFTMinted(
        uint256 startTokenId,
        uint256 lastTokenId,
        address indexed owner
    );
    event NFTBurnt(uint256 tokenId, address indexed ownerOrApproved);
    event ClientConfig(uint256 tokenId, string clientConfig);

    event TokenManagerAdded(uint256 tokenId, address user);
    event TokenManagerRemoved(uint256 tokenId, address user);

    modifier whenNotpaused() {
        require(mintPaused == false, "Sotreus: NFT Minting Paused");
        _;
    }
    modifier onlyOwnerOrApproved(uint tokenId) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Sotreus: Not Owner Or Approved"
        );
        _;
    }

    modifier onlyWhenTokenExist(uint256 tokenId) {
        require(_exists(tokenId), "Sotreus: Not a valid tokenId");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initialURI,
        uint256 _publicSalePrice,
        uint256 _maxSupply,
        uint96 _royaltyFeeBasisPoint // for default royalty
    ) ERC721A(_name, _symbol) {
        baseURI = _initialURI;
        publicSalePrice = _publicSalePrice;
        maxSupply = _maxSupply;
        // platFormFeeBasisPoint = _royaltyFeeBasisPoint;

        //SETUP ROLE
        _setupRole(SOTREUS_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(SOTREUS_ADMIN_ROLE, SOTREUS_ADMIN_ROLE);
        _setRoleAdmin(SOTREUS_OPERATOR_ROLE, SOTREUS_ADMIN_ROLE);

        // add Admin to operator
        grantRole(SOTREUS_OPERATOR_ROLE, _msgSender());

        // Setting default royalty to 5%
        _setDefaultRoyalty(_msgSender(), _royaltyFeeBasisPoint);
    }

    /// @notice Admin Role can set the mint price
    function setPrice(
        uint256 _publicSalePrice
    ) external onlyRole(SOTREUS_ADMIN_ROLE) {
        publicSalePrice = _publicSalePrice;
    }

    /// @notice pause or stop the contract from working by ADMIN
    function pause() public onlyRole(SOTREUS_ADMIN_ROLE) {
        mintPaused = true;
    }

    /// @notice Unpause the contract by ADMIN
    function unpause() public onlyRole(SOTREUS_ADMIN_ROLE) {
        mintPaused = false;
    }


    function tokenURI(
        uint256 tokenId
    ) public view override(IERC721A, ERC721A) returns (string memory) {
        string memory _tokenURI = _baseURI(); //ERC721
        if (collectionRevealed) {
            return string(abi.encodePacked(_tokenURI, "/", tokenId.toString()));
        } else {
            return _tokenURI;
        }
    }

    /// @notice Call to mint NFTs
    function mintNFT(uint quantity) external payable whenNotpaused {
        require(totalSupply() <= maxSupply, "Sotreus: Collection Sold Out!");
        require(
            publicSalePrice * quantity >= msg.value,
            "Sotreus: Insuffiecient amount!"
        );
        _safeMint(_msgSender(), quantity);
        emit NFTMinted(totalSupply(), totalSupply() + quantity, _msgSender());
    }

    /**
     * @notice Burns `tokenId`. See {ERC721-_burn}.
     *
     * @dev Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burnNFT(uint256 _tokenId) public onlyOwnerOrApproved(_tokenId) {
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
    ) external onlyRole(SOTREUS_ADMIN_ROLE) {
        require(
            collectionRevealed == false,
            "Sotreus: Collection Already Revealed"
        );
        _setBaseURI(_revealURI);
        collectionRevealed = true;
        emit CollectionURIRevealed(_revealURI);
    }

    /// @notice Admin can withdraw the funds collected
    function withdraw() external onlyRole(SOTREUS_ADMIN_ROLE) {
        // get the balance of the contract
        (bool callSuccess, ) = payable(_msgSender()).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Sotreus: Withdrawal failed");
    }

    /*****  Update Client Config *******/

    /// @notice  set the clientConfig [Data token]
    function writeClientConfig(
        uint256 _tokenId,
        string memory _clientConfig
    ) external {
        require(
            hasRole(SOTREUS_OPERATOR_ROLE, _msgSender()) ||
                _isApprovedOrOwner(_msgSender(), _tokenId),
            "Sotreus: user not authorized"
        );
        require(_exists(_tokenId), "Sotreus: Non-Existent Token");
        clientConfig[_tokenId] = _clientConfig;
        emit ClientConfig(_tokenId, _clientConfig);
    }

    /* ******************************* */

    function addManager(
        address user,
        uint256 tokenId
    ) public onlyOwnerOrApproved(tokenId) {
        managers[user][tokenId] = true;
        emit TokenManagerAdded(tokenId, user);
    }

    function removeManager(
        address user,
        uint256 tokenId
    ) external onlyOwnerOrApproved(tokenId) {
        managers[user][tokenId] = false;
        emit TokenManagerRemoved(tokenId, user);
    }

    /** SUBSCRIPTION  **/
    /// @notice Renews the subscription to an NFT
    /// Throws if `tokenId` is not a valid NFT
    /// @param tokenId The NFT to renew the subscription for
    /// @param duration The number of months to extend a subscription for
    /// cannot be more than 12 or less than 1
    function renewSubscription(
        uint256 tokenId,
        uint64 duration
    ) external payable {
        require(
            _isApprovedOrOwner(msg.sender, tokenId) ||
                hasRole(SOTREUS_OPERATOR_ROLE, _msgSender()),
            "Sortreus: Caller is owner nor approved or the Operator"
        );
        require(
            duration > 0 && duration <= 12,
            "Sortreus: Duration must be between 1 to 12 months!"
        );
        uint256 _duration = (duration * MONTH);
        if (!hasRole(SOTREUS_OPERATOR_ROLE, _msgSender())) {
            require(
                msg.value >= duration * subscriptionPricePerMonth,
                "Sotreus Insufficient Payment!"
            );
        } else {
            _operatorRenewal[tokenId] += uint64(_duration);
        }
        uint64 newExpiration;

        if (isRenewable(tokenId) == true) {
            newExpiration = uint64(block.timestamp + _duration);
            _expirations[tokenId] = newExpiration;
        } else {
            newExpiration = uint64(_expirations[tokenId] + _duration);
            _expirations[tokenId] = newExpiration;
        }
        emit SubscriptionUpdate(tokenId, newExpiration);
    }

    /// @notice Cancels the subscription of an NFT
    /// @dev Throws if `tokenId` is not a valid NFT
    /// only deduct a week as a penalty when refunding the money.
    /// @param tokenId The NFT to cancel the subscription for
    function cancelSubscription(
        uint256 tokenId
    ) external payable onlyWhenTokenExist(tokenId) {
        require(
            _isApprovedOrOwner(msg.sender, tokenId) ||
                hasRole(SOTREUS_OPERATOR_ROLE, _msgSender()),
            "Sortreus: Caller is owner nor approved or the Operator"
        );
        require(
            !isRenewable(tokenId),
            "Sortreus: the subscription cannot be cancelled!"
        );
        uint256 cancellationCharges = calculateCancellationFee(tokenId);
        _operatorRenewal[tokenId] = 0;
        if (hasRole(SOTREUS_OPERATOR_ROLE, _msgSender())) {
            if (address(this).balance < cancellationCharges) {
                require(
                    msg.value >= cancellationCharges,
                    "Sotreus: Insufficient amount!"
                );
            }
            payable(ownerOf(tokenId)).transfer(cancellationCharges);
        } else {
            require(
                address(this).balance >= cancellationCharges,
                "Sortreus: Insufficient amount ,please contact the contract handler or creator!"
            );
            payable(ownerOf(tokenId)).transfer(cancellationCharges);
        }

        _expirations[tokenId] = uint64(block.timestamp);
        emit SubscriptionUpdate(tokenId, uint64(block.timestamp));
    }

    /** Getter Functions **/
    ////// SUBSCRIPTION ///////////////
    /// @notice Gets the expiration date of a subscription
    /// @param tokenId The NFT to get the expiration date of
    /// @return The expiration date of the subscription
    function expiresAt(uint256 tokenId) external view returns (uint64) {
        return _expirations[tokenId];
    }

    /// @notice Determines whether a subscription can be renewed
    /// @param tokenId The NFT to get the expiration date of
    /// @return The renewability of a the subscription
    function isRenewable(uint256 tokenId) public view returns (bool) {
        if (_expirations[tokenId] > block.timestamp) {
            return true;
        } else {
            return false;
        }
    }

    /// @notice Calculate the refund for the token
    /// @param tokenId The NFT to get the expiration date of
    function calculateCancellationFee(
        uint256 tokenId
    ) public view returns (uint256 payoutForTheUser) {
        uint64 time = _expirations[tokenId] -
            uint64(block.timestamp) -
            _operatorRenewal[tokenId];
        uint256 weeksLeft = uint256(time) / WEEK;
        uint256 cancellationCharges = (subscriptionPricePerMonth * 25) / 100;
        payoutForTheUser = (weeksLeft - 1) * cancellationCharges;
    }

    ////////////////////////////////

    /// @notice get the clientConfig[Data Token]
    function readClientConfig(
        uint256 tokenId
    ) external view returns (string memory) {
        require(_exists(tokenId), "SORTREUS: Non-Existent Token");
        return clientConfig[tokenId];
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    
    /// @notice To check if tokenId is manager or not
    /// @param tokenId The NFT to get the user expires for
    /// @return the user is manager or not
    function isManager(uint256 tokenId) external view returns (bool) {
        return managers[_msgSender()][tokenId];
    }

    function _isApprovedOrOwner(
        address user,
        uint256 tokenId
    ) private view returns (bool) {
        return (isApprovedForAll(ownerOf(tokenId), user) ||
            ownerOf(tokenId) == user);
    }

    /************************************* */

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
        return super.supportsInterface(interfaceId);
    }
}
