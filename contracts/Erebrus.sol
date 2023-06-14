// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./common/interface/IERC4907.sol";
import "./common/interface/IERC5643.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./common/ERC721A/extensions/ERC721ABurnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
contract Erebrus is
    Context,
    IERC4907,
    IERC5643,
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
    /// @notice UNIX TIME FOR ONE MONTH(30 days)
    uint256 public constant MONTH = 2592000;

    /// @notice UNIX TIME FOR ONE WEEK(Taking 30 days a month)
    uint public constant WEEK = 648000;

    uint256 public immutable maxSupply; // Set in the constructor

    using Strings for uint256;

    bool public collectionRevealed = false;
    bool public mintPaused = true;
    uint256 public publicSalePrice;
    uint256 public platFormFeeBasisPoint;
    uint256 public subscriptionPricePerMonth;
    uint64 public instantTime;
    string public baseURI;

    struct RentableItems {
        bool isRentable; //to check is renting is available
        address user; // address of user role
        uint64 expires; // unix timestamp, user expires
        uint256 hourlyRate; // amountPerHour
    }

    mapping(uint256 => string) public clientConfig;
    mapping(uint256 => RentableItems) internal rentables; // storing the data of the user who are renting the NFT
    /// @notice To store subscription info
    mapping(uint256 => uint64) private _expirations; // subscription
    /// @notice Subscription allocated by contract Creator to a user (in secs)
    mapping(uint256 => uint64) private _operatorRenewal;

    modifier whenNotpaused() {
        require(mintPaused == false, "Erebrus: NFT Minting Paused");
        _;
    }

    modifier onlyWhenTokenExist(uint256 tokenId) {
        require(_exists(tokenId), "Erebrus: Not a valid tokenId");
        _;
    }

    event CollectionURIRevealed(string revealedURI);
    event NFTMinted(
        uint256 startTokenId,
        uint256 lastTokenId,
        address indexed owner
    );
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
        uint256 _platFormFeeBasisPoint,
        uint256 _subscriptionPricePerMonth,
        uint96 royaltyBasisPoint
    ) ERC721A(_name, _symbol) {
        baseURI = _initialURI;
        publicSalePrice = _publicSalePrice;
        maxSupply = _maxSupply;
        platFormFeeBasisPoint = _platFormFeeBasisPoint;
        subscriptionPricePerMonth = _subscriptionPricePerMonth;

        _setupRole(EREBRUS_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(EREBRUS_ADMIN_ROLE, EREBRUS_ADMIN_ROLE);
        _setRoleAdmin(EREBRUS_OPERATOR_ROLE, EREBRUS_ADMIN_ROLE);

        // add Admin to operator
        grantRole(EREBRUS_OPERATOR_ROLE, _msgSender());

        // Setting default royalty
        _setDefaultRoyalty(_msgSender(), royaltyBasisPoint);
    }

    ///SET BASE URI

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

    function setSubscriptionCharges(
        uint256 _subscriptionCharges
    ) public onlyRole(EREBRUS_OPERATOR_ROLE) {
        subscriptionPricePerMonth = _subscriptionCharges;
    }

    function setTime(uint64 _time) public {
        instantTime = _time;
    }

    /// @notice Call to mint NFTs
    function mintNFT(uint256 quantity) external payable whenNotpaused {
        uint256 previousSupply = _totalMinted();
        require(_totalMinted() <= maxSupply, "Erebrus: Collection Sold Out!");
        require(
            publicSalePrice * quantity >= msg.value,
            "Sotreus: Insuffiecient amount!"
        );
        _safeMint(_msgSender(), quantity);

        if (quantity == 1) {
            uint currentTokenId = _totalMinted();
            _expirations[currentTokenId] = uint64(block.timestamp + MONTH);
            _operatorRenewal[currentTokenId] += uint64(MONTH);
        } else {
            for (
                uint i = previousSupply + 1;
                i <= (previousSupply + quantity);
                i++
            ) {
                _expirations[i] = uint64(block.timestamp + MONTH);
                _operatorRenewal[i] += uint64(MONTH);
            }
        }
        emit NFTMinted(_totalMinted(), previousSupply + quantity, _msgSender());
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
    ) external onlyRole(EREBRUS_OPERATOR_ROLE) {
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
    ) public virtual override {
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

    function rent(uint256 _tokenId, uint256 _timeInHours) external payable {
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

    /** SUBSCRIPTION  **/
    /// @notice Renews the subscription to an NFT
    /// Throws if `tokenId` is not a valid NFT
    /// Renewal can be done even if existing subscription is not ended
    /// @param tokenId The NFT to renew the subscription for
    /// @param duration The number of months to extend a subscription for
    /// cannot be more than 12 or less than 1
    function renewSubscription(
        uint256 tokenId,
        uint64 duration
    ) external payable onlyWhenTokenExist(tokenId) {
        require(
            _isApprovedOrOwner(msg.sender, tokenId) ||
                hasRole(EREBRUS_OPERATOR_ROLE, _msgSender()),
            "Erebrus: Caller is owner nor approved or the Operator"
        );
        require(
            duration > 0 && duration <= 12,
            "Erebrus: Duration must be between 1 to 12 months!"
        );
        uint256 _duration = (duration * MONTH);
        if (!hasRole(EREBRUS_OPERATOR_ROLE, _msgSender())) {
            require(
                msg.value >= duration * subscriptionPricePerMonth,
                "Erebrus: Insufficient Payment"
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
                hasRole(EREBRUS_OPERATOR_ROLE, _msgSender()),
            "Erebrus: Caller is owner nor approved or the Operator"
        );
        require(
            !isRenewable(tokenId),
            "Erebrus: The subscription cannot be cancelled!"
        );
        uint256 cancellationRefund = calculateCancellationFee(tokenId);
        _operatorRenewal[tokenId] = 0;
        if (hasRole(EREBRUS_OPERATOR_ROLE, _msgSender())) {
            if (address(this).balance < cancellationRefund) {
                require(
                    msg.value >= cancellationRefund,
                    "Erebrus: Insufficient amount!"
                );
            }
            payable(ownerOf(tokenId)).transfer(cancellationRefund);
        } else {
            require(
                address(this).balance >= cancellationRefund,
                "Erebrus: Insufficient funds, contact support!"
            );
            payable(ownerOf(tokenId)).transfer(cancellationRefund);
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
        if (_expirations[tokenId] <= block.timestamp) {
            return true;
        } else {
            return false;
        }
    }

    /// @notice Calculate the refund for the token
    /// @dev Throws if `tokenId` is not a valid NFT
    /// @param tokenId The NFT to get the expiration date of
    function calculateCancellationFee(
        uint256 tokenId
    )
        public
        view
        onlyWhenTokenExist(tokenId)
        returns (uint256 payoutForTheUser)
    {
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

    function getTime() external view returns (uint64) {
        return instantTime;
    }

    /************************************* */

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override(ERC721A) {
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
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
