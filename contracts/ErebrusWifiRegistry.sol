// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PDid.sol";
import "./ErebrusManager/IErebrusManager.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract ErebrusWiFiRegistry is Context {
    uint256 private currentWifiNode;

    IEREBRUSMANAGER erebrusRoles;

    // Add Peaq ID
    struct WiFiNode {
        address user;
        string deviceId; ///  convert to string
        address peaqDid;
        string ssid;
        string location;
        uint256 pricePerMinute;
        uint256 latency;
        bool isActive;
    }

    struct VPNNode {
        uint256 nodeId;
        address peaqDid;
        string nodename;
        string ipaddress;
        string ispinfo;
        string region;
        string location;
        uint8 status;
    }

    mapping(uint256 => WiFiNode) public wifiNodeOperators;
    mapping(bytes32 => mapping(uint256 => string)) public deviceCheckpoints;
    mapping(bytes32 => uint256) public totalCheckpoints;
    mapping(bytes32 => address) public deviceToUser; // change it
    mapping(address => address) public didToUser;

    mapping(address => VPNNode) public walletToVpnNodeInfo;

    //@notice Modifier to ensure that the sender is an operator
    modifier onlyOperator() {
        require(
            erebrusRoles.isOperator(_msgSender()),
            "EternumPass: Unauthorized!"
        );
        _;
    }

    constructor(address erebrusmanagerAddr) {
        erebrusRoles = IEREBRUSMANAGER(erebrusmanagerAddr);
    }

    event VpnNodeRegistered(
        uint256 nodeId,
        string nodename,
        string ipaddress,
        string ispinfo,
        string region,
        string location
    );

    event VPNUpdated(uint256 nodeId, uint8 updatedStatus, string updatedRegion);

    event WifiNodeOperatorRegistered(
        uint256 nodeID,
        address indexed operatorAddress,
        string deviceId,
        string ssid,
        string location,
        uint256 pricePerMinute,
        uint256 latency
    );

    event NodeOperatorUpdated(
        address indexed operatorAddress,
        string ssid,
        string location
    );

    event NodeDeactivated(address indexed operatorAddress);

    event AddAttribute(
        address sender,
        address did_account,
        bytes name,
        bytes value,
        uint32 validity
    );
    event UpdateAttribute(
        address sender,
        address did_account,
        bytes name,
        bytes value,
        uint32 validity
    );
    event RemoveAttribte(address did_account, bytes name);

    ///////////////////////////////////////////
    /************* Wifi **********************/

    /// @dev can only be called by user who is assigned to be operator
    function registerNodeOperator(
        address user,
        string memory _deviceId,
        address _peaqDid,
        string memory _ssid,
        string memory _location,
        uint256 _pricePermin,
        uint256 _latency
    ) external onlyOperator {
        uint256 nodeID = currentWifiNode++;
        wifiNodeOperators[nodeID] = WiFiNode(
            user,
            _deviceId,
            _peaqDid,
            _ssid,
            _location,
            _pricePermin,
            _latency,
            true
        );

        emit WifiNodeOperatorRegistered(
            nodeID,
            _msgSender(),
            _deviceId,
            _ssid,
            _location,
            _pricePermin,
            _latency
        );
    }

    function updateWiFiNode(
        uint256 nodeID,
        string memory ssid,
        string memory location,
        uint256 pricePerMin
    ) external onlyOperator {
        require(
            wifiNodeOperators[nodeID].isActive,
            "DWifi_Registry: User not authorized!"
        );
        WiFiNode storage operator = wifiNodeOperators[nodeID];

        if (bytes(ssid).length != 0) operator.ssid = ssid;
        if (bytes(location).length != 0) operator.location = location;
        if (pricePerMin != 0) operator.pricePerMinute = pricePerMin;

        emit NodeOperatorUpdated(_msgSender(), ssid, location);
    }

    function deactivateNode(uint256 nodeID) external onlyOperator {
        wifiNodeOperators[nodeID].isActive = false;
        emit NodeDeactivated(msg.sender);
    }

    function deviceCheckpoint(
        bytes32 deviceId,
        string memory dataHash
    ) external onlyOperator {
        totalCheckpoints[deviceId]++;
        uint256 currentCheckpoint = totalCheckpoints[deviceId];
        deviceCheckpoints[deviceId][currentCheckpoint] = dataHash;
    }

    function readAttribute(
        address did_account,
        bytes memory name
    ) public view returns (DID.Attribute memory) {
        return DID_CONTRACT.readAttribute(did_account, name);
    }

    function addAttribute(
        address did_account,
        bytes memory name,
        bytes memory value,
        uint32 validity_for
    ) public onlyOperator returns (bool) {
        address user = didToUser[did_account];
        bool success = DID_CONTRACT.addAttribute(
            did_account,
            name,
            value,
            validity_for
        );
        require(success, "Failed to add attribute");
        emit AddAttribute(user, did_account, name, value, validity_for);
        return success;
    }

    function updateAttribute(
        address did_account,
        bytes memory name,
        bytes memory value,
        uint32 validity_for
    ) public returns (bool) {
        address user = didToUser[did_account];
        bool success = DID_CONTRACT.updateAttribute(
            did_account,
            name,
            value,
            validity_for
        );
        require(success, "Failed to update attribute");
        emit UpdateAttribute(user, did_account, name, value, validity_for);
        return success;
    }

    function removeAttribute(
        address did_account,
        bytes memory name
    ) public returns (bool) {
        bool success = DID_CONTRACT.removeAttribute(did_account, name);
        require(success, "Failed to remove attribute");
        emit RemoveAttribte(did_account, name);
        return success;
    }

    ///////////////////////////////////////////
    /************* VPN **********************/

    /// @dev can only be called by user who is assigned to be operator.
    function registerVpnNode(
        address user,
        VPNNode memory node
    ) public onlyOperator {
        walletToVpnNodeInfo[user] = node;

        emit VpnNodeRegistered(
            node.nodeId,
            node.nodename,
            node.ipaddress,
            node.ispinfo,
            node.region,
            node.location
        );
    }

    function updateVPNNode(uint8 _status, string memory _region) public {
        walletToVpnNodeInfo[_msgSender()].status = _status;
        walletToVpnNodeInfo[_msgSender()].region = _region;

        emit VPNUpdated(
            walletToVpnNodeInfo[_msgSender()].nodeId,
            _status,
            _region
        );
    }

    ///////////////////////////////////////////////

    //CHANGE IT
    function getWifiDetails(
        uint256 nodeID
    ) external view returns (uint256 price, address owner) {
        price = wifiNodeOperators[nodeID].pricePerMinute;
        owner = wifiNodeOperators[nodeID].user;
    }
}
