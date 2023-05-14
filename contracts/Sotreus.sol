// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./common/extensions/ERC721ABurnable.sol";
import "hardhat/console.sol";

contract Sotreus is Context, AccessControlEnumerable, ERC721ABurnable, ERC2981 {
    // Set Constants for Interface ID and Roles
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    bytes32 public constant SOTREUS_ADMIN_ROLE =
        keccak256("SORTREUS_ADMIN_ROLE");
    bytes32 public constant SOTREUS_OPERATOR_ROLE =
        keccak256("SORTREUS_OPERATOR_ROLE");

    uint256 public immutable maxSupply; // Set in the constructor

    using Strings for uint256;

    bool public collectionRevealed = false;
    bool public mintPaused = true;
    uint256 public publicSalePrice;
    string public baseURI;
    uint256 public platFormFeeBasisPoint;

    mapping(uint256 => address[]) public managers;

    mapping(uint256 => string) public clientConfig;

    mapping(address => uint256) public nftMints;

    event CollectionURIRevealed(string revealedURI);
    event NFTMinted(uint256 tokenId, address indexed owner);
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

        //SETUP ROLE
        _setupRole(SOTREUS_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(SOTREUS_ADMIN_ROLE, SOTREUS_ADMIN_ROLE);
        _setRoleAdmin(SOTREUS_OPERATOR_ROLE, SOTREUS_ADMIN_ROLE);

        // add Admin to operator
        grantRole(SOTREUS_OPERATOR_ROLE, _msgSender());

        // Setting default royalty to 5%
        _setDefaultRoyalty(_msgSender(), 500);
    }

    ///@notice Function to update the plateformFeeBasisPoint
    function updateFee(
        uint256 _platFormFeeBasisPoint
    ) external onlyRole(SOTREUS_OPERATOR_ROLE) {
        platFormFeeBasisPoint = _platFormFeeBasisPoint;
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
            "Sotreus : user not authorized"
        );
        require(_exists(_tokenId), "Sotreus: Non-Existent Token");
        clientConfig[_tokenId] = _clientConfig;
        emit ClientConfig(_tokenId, _clientConfig);
    }

    /* ******************************* */

    function addManager(
        uint256 tokenId,
        address user
    ) public whenNotpaused onlyOwnerOrApproved(tokenId) {
        managers[tokenId].push(user);
        emit TokenManagerAdded(tokenId, user);
    }

    function removeManager(
        uint256 tokenId,
        address user
    ) external onlyOwnerOrApproved(tokenId) {
        uint256 arrLen = managers[tokenId].length;

        for (uint i = 0; i < arrLen; i++) {
            if (managers[tokenId][i] == user) {
                delete managers[tokenId][i];
                emit TokenManagerRemoved(tokenId, user);
            }
        }
    }

    /** Getter Functions **/

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

    function getUser(uint256 tokenId) public view returns (address[] memory) {
        return managers[tokenId];
    }

    function isUserManager(uint256 tokenId) external view returns (bool) {
        uint256 arrLen = managers[tokenId].length;
        for (uint i = 0; i < arrLen; i++) {
            if (managers[tokenId][i] == _msgSender()) {
                return true;
            }
        }
        return false;
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
