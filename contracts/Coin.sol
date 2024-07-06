// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyToken is ERC721 {
    constructor() ERC721("MyToken", "MTK") {}

    uint256 public nextTokenId;

    function safeMint(address to) public {
        nextTokenId++;
        uint256 tokenId = nextTokenId;
        _safeMint(to, tokenId);
    }
}
