// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
import "./DelayedReveal.sol";
import "./Subscription.sol";
import "hardhat/console.sol";

contract Reveal is DelayedReveal, Subscription {
    uint public immutable batchId = 1;
    bool public revealed = false;

    function revealActivated() external onlyOwner {
        revealed = true;
    }

    function RevealStatus() external view returns (bool) {
        return revealed;
    }

    function setReveal(
        string memory _URI,
        string memory _key
    ) public onlyOwner {
        bytes memory hashURI = abi.encodePacked(_URI);
        bytes memory hashkey = abi.encodePacked(_key);

        bytes memory encryptedURI = encryptDecrypt(hashURI, hashkey);
        _setEncryptedData(batchId, encryptedURI);
    }

    /// @dev Checks whether NFTs can be revealed in the given execution context.
    function _canReveal() internal view virtual returns (bool) {
        return msg.sender == owner();
    }
}
