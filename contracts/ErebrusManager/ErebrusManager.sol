// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

/**
 * @dev This Contract Module helps to deploy the
 * base Roles for the other flow contracts .
 * Every other Flow contract will retrieve the roles of the
 * ADMIN, OPERATOR , etc. from this.
 */

contract ErebrusManager is AccessControlEnumerable {
    string public name = "ErebrusManager";
    string public symbol = "EA";
    uint8 public constant version = 1;

    address private payoutAddress;

    bytes32 public constant EREBRUS_ADMIN_ROLE =
        keccak256("EREBRUS_ADMIN_ROLE");
    bytes32 public constant EREBRUS_OPERATOR_ROLE =
        keccak256("EREBRUS_OPERATOR_ROLE");

    constructor() {
        _setRoleAdmin(EREBRUS_ADMIN_ROLE, EREBRUS_ADMIN_ROLE);
        _setRoleAdmin(EREBRUS_OPERATOR_ROLE, EREBRUS_ADMIN_ROLE);
        _grantRole(EREBRUS_ADMIN_ROLE, _msgSender());
        _grantRole(EREBRUS_OPERATOR_ROLE, _msgSender());
    }

    /// @dev to check if the address {User} is the ADMIN
    function isAdmin(address user) external view returns (bool) {
        return hasRole(EREBRUS_ADMIN_ROLE, user);
    }

    /// @dev to check if the address {User} is the OPERATOR
    function isOperator(address user) external view returns (bool) {
        return hasRole(EREBRUS_OPERATOR_ROLE, user);
    }

    /// @dev Sets the payout address.
    /// @param _payoutAddress The new address to receive funds from multiple contracts.
    /// @notice Only the admin can set the payout address.
    function setPayoutAddress(address _payoutAddress) external {
        require(
            hasRole(EREBRUS_ADMIN_ROLE, _msgSender()),
            "ErebrusManager: User is not authorized"
        );
        payoutAddress = _payoutAddress;
    }

    /**
     * @notice Retrieves the payout address defined by the admin.
     * @return The payout address for receiving funds.
     */
    function getPayoutAddress() external view returns (address) {
        return payoutAddress;
    }
}
