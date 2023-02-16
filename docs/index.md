# Solidity API

## Erebrus

### EREBRUS_ADMIN_ROLE

```solidity
bytes32 EREBRUS_ADMIN_ROLE
```

### EREBRUS_OPERATOR_ROLE

```solidity
bytes32 EREBRUS_OPERATOR_ROLE
```

### EREBRUS_ALLOWLISTED_ROLE

```solidity
bytes32 EREBRUS_ALLOWLISTED_ROLE
```

### maxSupply

```solidity
uint256 maxSupply
```

### collectionRevealed

```solidity
bool collectionRevealed
```

### mintPaused

```solidity
bool mintPaused
```

### allowListMintOpen

```solidity
bool allowListMintOpen
```

### publicSalePrice

```solidity
uint256 publicSalePrice
```

### allowListSalePrice

```solidity
uint256 allowListSalePrice
```

### baseURI

```solidity
string baseURI
```

### platFormFeeBasisPoint

```solidity
uint256 platFormFeeBasisPoint
```

### RentableItems

```solidity
struct RentableItems {
  bool isRentable;
  address user;
  uint64 expires;
  uint256 amountPerMinute;
}
```

### whenNotpaused

```solidity
modifier whenNotpaused()
```

### clientConfig

```solidity
mapping(uint256 => string) clientConfig
```

### rentables

```solidity
mapping(uint256 => struct Erebrus.RentableItems) rentables
```

### nftMints

```solidity
mapping(address => uint256) nftMints
```

### CollectionURIRevealed

```solidity
event CollectionURIRevealed(string revealedURI)
```

### NFTMinted

```solidity
event NFTMinted(uint256 tokenId, address owner)
```

### NFTBurnt

```solidity
event NFTBurnt(uint256 tokenId, address ownerOrApproved)
```

### ClientConfigUpdated

```solidity
event ClientConfigUpdated(uint256 tokenId, string data, string newData)
```

### RentalInfo

```solidity
event RentalInfo(uint256 tokenId, bool isRentable, uint256 price, address Renter)
```

### constructor

```solidity
constructor(string name, string symbol, string initialURI, uint256 _publicSalePrice, uint256 _allowListSalePrice, uint256 _maxSupply, uint256 _platFormFeeBasisPoint) public
```

### updateFee

```solidity
function updateFee(uint256 _platFormFeeBasisPoint) external
```

set the plaformFeeBasisPoint

### setPrice

```solidity
function setPrice(uint256 _publicSalePrice, uint256 _allowlistprice) external
```

set the price of the minting by ADMIN

### pause

```solidity
function pause() public
```

pause or stop the contract from working by ADMIN

### unpause

```solidity
function unpause() public
```

Unpause the contract by ADMIN

### tokenURI

```solidity
function tokenURI(uint256 tokenId) public view returns (string)
```

_See {IERC721Metadata-tokenURI}._

### editMintWindows

```solidity
function editMintWindows(bool _allowListMintOpen) external
```

Modify the mint windows

### mintNFT

```solidity
function mintNFT() external payable
```

to mint NFT's

### burnNFT

```solidity
function burnNFT(uint256 tokenId) public
```

Burns `tokenId`. See {ERC721-_burn}.

Requirements:

- The caller must own `tokenId` or be an approved operator.

### _setBaseURI

```solidity
function _setBaseURI(string _tokenBaseURI) internal
```

### revealCollection

```solidity
function revealCollection(string _revealURI) external
```

Reveals the collection metadata baseURI.

Requirements:

- The caller must have Admin Role.

### withdraw

```solidity
function withdraw() external
```

### writeClientConfig

```solidity
function writeClientConfig(uint256 tokenId, string newData) external
```

### setUser

```solidity
function setUser(uint256 tokenId, address user, uint64 expires) public virtual
```

set the user and expires of an NFT

_This function is used to gift a person by the owner,
The zero address indicates there is no user
Throws if `tokenId` is not valid NFT_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 |  |
| user | address | The new user of the NFT |
| expires | uint64 | UNIX timestamp, The new user could use the NFT before expires |

### setRentInfo

```solidity
function setRentInfo(uint256 tokenId, bool isRentable, uint256 amountPerMinute) public
```

set tht rentable price and status by the owner

### rent

```solidity
function rent(uint256 tokenId, uint256 time) external payable
```

to use for renting an item

_The zero address indicates there is no user
Throws if `tokenId` is not valid NFT,
time cannot be less than 1 hour or more than 6 months_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 |  |
| time | uint256 | is in hours , Ex- 1,2,3 |

### readClientConfig

```solidity
function readClientConfig(uint256 tokenId) external view returns (string)
```

get the clientConfig[Data Token]

### userOf

```solidity
function userOf(uint256 tokenId) public view virtual returns (address)
```

Get the user address of an NFT

_The zero address indicates that there is no user or the user is expired_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The NFT to get the user address for |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The user address for this NFT |

### userExpires

```solidity
function userExpires(uint256 tokenId) public view virtual returns (uint256)
```

Get the user expires of an NFT

_The zero value indicates that there is no user_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The NFT to get the user expires for |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The user expires for this NFT |

### amoutRequire

```solidity
function amoutRequire(uint256 tokenId, uint256 time) public view returns (uint256)
```

to calculate the amount of money required
to rent a item for an certain time

### _baseURI

```solidity
function _baseURI() internal view returns (string)
```

_Base URI for computing {tokenURI}. If set, the resulting URI for each
token will be the concatenation of the `baseURI` and the `tokenId`. Empty
by default, can be overridden in child contracts._

### _beforeTokenTransfer

```solidity
function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256) internal virtual
```

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

## IERC4907

### UpdateUser

```solidity
event UpdateUser(uint256 tokenId, address user, uint64 expires)
```

Emitted when the `user` of an NFT or the `expires` of the `user` is changed
The zero address for user indicates that there is no user address

### setUser

```solidity
function setUser(uint256 tokenId, address user, uint64 expires) external
```

set the user and expires of an NFT

_The zero address indicates there is no user
Throws if `tokenId` is not valid NFT_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 |  |
| user | address | The new user of the NFT |
| expires | uint64 | UNIX timestamp, The new user could use the NFT before expires |

### userOf

```solidity
function userOf(uint256 tokenId) external view returns (address)
```

Get the user address of an NFT

_The zero address indicates that there is no user or the user is expired_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The NFT to get the user address for |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The user address for this NFT |

### userExpires

```solidity
function userExpires(uint256 tokenId) external view returns (uint256)
```

Get the user expires of an NFT

_The zero value indicates that there is no user_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The NFT to get the user expires for |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The user expires for this NFT |

