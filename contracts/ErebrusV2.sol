// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ErebrusManager/IErebrusManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

interface IEREBRUSREGISTRY {
    function getWifiDetails(
        uint256 nodeID
    ) external view returns (uint256, address);
}

contract ErebrusV2 is Context, ERC721Enumerable, ERC2981 {
    /// CONSTANTS
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    using Strings for uint256;

    uint256 public publicSalePrice;
    uint256 public subscriptionPerMonth;
    uint256 private _nextTokenId;

    string public baseUri;
    bool public mintPaused = true;

    struct WifiRequest {
        bool accepted;
        bool settled;
        uint256 nodeID;
    }

    mapping(address => uint256) public stakingInfo;
    mapping(uint256 => string) public tokenURIs;
    mapping(address => uint256) public userFunds;
    mapping(address => WifiRequest) public wifiRequests;

    IEREBRUSMANAGER erebrusRoles;

    IEREBRUSREGISTRY registry;

    modifier whenNotpaused() {
        require(mintPaused == false, "Erebrus: NFT Minting Paused");
        _;
    }

    ///@notice Modifier to ensure that the sender is an operator
    modifier onlyOperator() {
        require(
            erebrusRoles.isOperator(_msgSender()),
            "Erebrus: Unauthorized!"
        );
        _;
    }

    ///@notice Modifier to ensure that the sender is an operator
    modifier onlyAdmin() {
        require(erebrusRoles.isAdmin(_msgSender()), "Erebrus: Unauthorized!");
        _;
    }

    event NFTMinted(
        uint256 tokendId,
        address indexed owner,
        string metadataUri
    );
    event NFTBurnt(uint256 tokenId, address indexed ownerOrApproved);
    event StakeForAccess(address indexed user, uint256 amount);
    event WithdrawStake(address indexed user, uint256 stakeAmount);
    event WifiRequestCreated(address indexed requester, uint256 deviceId);
    event WifiRequestManaged(address requester, bool accepted);

    event WifiPaymentSettled(
        address indexed user,
        uint256 amount,
        uint256 deviceId
    );
    event FundsAdded(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event VpnValidityExtended(address indexed user, uint256 duration);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initialURI,
        uint256 _publicSalePrice,
        uint256 _subscriptionRate,
        uint96 royaltyBasisPoint,
        address erebrusManagerContract,
        address _registryAddr
    ) ERC721(_name, _symbol) {
        baseUri = _initialURI;
        publicSalePrice = _publicSalePrice;
        subscriptionPerMonth = _subscriptionRate;
        _setDefaultRoyalty(_msgSender(), uint96(royaltyBasisPoint));
        erebrusRoles = IEREBRUSMANAGER(erebrusManagerContract);
        registry = IEREBRUSREGISTRY(_registryAddr);
    }

    function updateMetadata(
        uint256 tokenId,
        string memory metadataUri
    ) external onlyOperator {
        require(
            _requireOwned(tokenId) == _msgSender(),
            "Erebrus: Non-Existent Token"
        );
        require(
            ownerOf(tokenId) == _msgSender(),
            "Erebrus: User is not token owner"
        );
        tokenURIs[tokenId] = metadataUri;
    }

    function setPublicSalePrice(uint256 _publicSalePrice) external {
        publicSalePrice = _publicSalePrice;
    }

    function setRegistryContract(address registryContract) public onlyAdmin {
        registry = IEREBRUSREGISTRY(registryContract);
    }

    function _setBaseURI(string memory _tokenBaseURI) public onlyAdmin {
        baseUri = _tokenBaseURI;
    }

    /// @notice Call to mint NFTs
    function mint(string memory metadataURI) external payable {
        require(publicSalePrice >= msg.value, "Erebrus: Insuffiecient amount!");
        uint256 tokenId = _nextTokenId++;
        _safeMint(_msgSender(), tokenId);
        address payoutAddress = erebrusRoles.getPayoutAddress();
        payable(payoutAddress).transfer(msg.value);

        emit NFTMinted(tokenId, _msgSender(), metadataURI);
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
            _isAuthorized(_ownerOf(_tokenId), _msgSender(), _tokenId),
            "Erebrus: Not Owner Or Approved"
        );
        _burn(_tokenId);
        emit NFTBurnt(_tokenId, _msgSender());
        _resetTokenRoyalty(_tokenId);
    }

    // Wifi and VPN Functions
    function requestWifiConnection(uint256 nodeID) external {
        require(balanceOf(_msgSender()) > 0, "Erebrus: User not authorized");
        wifiRequests[_msgSender()] = WifiRequest(false, false, nodeID);
        emit WifiRequestCreated(_msgSender(), nodeID);
    }

    function manageWifiRequest(
        address intentRequester,
        bool status
    ) external onlyOperator {
        wifiRequests[intentRequester].accepted = status;
        emit WifiRequestManaged(intentRequester, status);
    }

    function settleWifiPayment(uint256 duration) external payable {
        require(
            wifiRequests[_msgSender()].accepted,
            "Erebrus: Connection is not accepted"
        );

        (, address deviceOwner) = registry.getWifiDetails(
            wifiRequests[_msgSender()].nodeID
        );

        wifiRequests[_msgSender()].accepted = false;

        require(
            msg.value >=
                calculateDeviceRate(
                    duration,
                    wifiRequests[_msgSender()].nodeID
                ),
            "Erebrus: Not enough funds!"
        );

        payable(deviceOwner).transfer(msg.value);
        emit WifiPaymentSettled(
            _msgSender(),
            msg.value,
            wifiRequests[_msgSender()].nodeID
        );
    }

    function addFunds() external payable {
        require(msg.value > 0, "Erebrus: Amount must be greater than zero");
        userFunds[_msgSender()] += msg.value;
        emit FundsAdded(_msgSender(), msg.value);
    }

    function extendVpnValidity(
        uint256 duration,
        bool fundUse
    ) external payable {
        require(duration <= 12, "Erebrus: More than 12 months not allowed");
        if (erebrusRoles.isOperator(_msgSender()) == false) {
            if (fundUse) {
                require(
                    userFunds[_msgSender()] >= msg.value,
                    "Erebrus: Insufficient funds"
                );
                userFunds[_msgSender()] -= msg.value;
            } else {
                require(
                    msg.value >= (duration * subscriptionPerMonth) &&
                        balanceOf(_msgSender()) > 0,
                    "Erebrus: Insufficient funds"
                );
            }
        }

        emit VpnValidityExtended(_msgSender(), duration);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            _requireOwned(tokenId) == _msgSender(),
            "Erebrus: Non-Existent Token"
        );
        string memory baseURI = baseUri;

        return bytes(baseURI).length != 0 ? tokenURIs[tokenId] : baseURI;
    }

    function calculateDeviceRate(
        uint256 duration,
        uint256 nodeID
    ) public view returns (uint256) {
        (uint256 pricePerMin, ) = registry.getWifiDetails(nodeID);
        return duration * pricePerMin;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        if (interfaceId == _INTERFACE_ID_ERC2981) return true;
        return super.supportsInterface(interfaceId);
    }
}
