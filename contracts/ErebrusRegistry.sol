// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PDid.sol";
import "./ErebrusManager/IErebrusManager.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract ErebrusRegistry is Context {
    uint256 private currentWifiNode;
    uint256 private currentVpnNode;

    IEREBRUSMANAGER erebrusRoles;

    // Add Peaq ID
    struct WiFiNode {
        address user;
        string deviceId; ///  convert to string
        string peaqDid;
        string ssid;
        string location;
        uint256 pricePerMinute;
        bool isActive;
    }

    struct VPNNode {
        address user;
        string peaqDid;
        string nodename;
        string ipaddress;
        string ispinfo;
        string region;
        string location;
        uint8 status;
    }

    //@dev Maps device IDs to their respective owners, allowing for easy lookup of the device owner.
    mapping(address => address) public didToUser;

    mapping(uint256 => WiFiNode) public wifiNodeOperators;
    mapping(uint256 => mapping(uint256 => string)) public wifiDeviceCheckpoints;
    mapping(uint256 => uint256) public wifiTotalCheckpoints;

    mapping(uint256 => VPNNode) public vpnNodeOperators;
    mapping(uint256 => mapping(uint256 => string)) public VpnDeviceCheckpoints;
    mapping(uint256 => uint256) public vpnTotalCheckpoints;

    //@notice Modifier to ensure that the sender is an operator
    modifier onlyOperator() {
        require(
            erebrusRoles.isOperator(_msgSender()),
            "Erebrus: Unauthorized!"
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
        address indexed owner,
        string deviceId,
        string ssid,
        string location,
        uint256 pricePerMinute
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

    function registerWifiNode(
        string memory _deviceId,
        string memory _peaqDid, // Owner Wallet Address
        string memory _ssid,
        string memory _location,
        uint256 _pricePermin // Wei
    ) external {
        uint256 nodeID = currentWifiNode++;
        wifiNodeOperators[nodeID] = WiFiNode(
            _msgSender(),
            _deviceId,
            _peaqDid,
            _ssid,
            _location,
            _pricePermin,
            true
        );

        emit WifiNodeOperatorRegistered(
            nodeID,
            _msgSender(),
            _deviceId,
            _ssid,
            _location,
            _pricePermin
        );
    }

    function updateWiFiNode(
        uint256 nodeID,
        string memory ssid,
        string memory location,
        uint256 pricePerMin
    ) external {
        require(
            wifiNodeOperators[nodeID].isActive,
            "ErebrusRegistry: Node is not active"
        );
        require(
            erebrusRoles.isOperator(_msgSender()) ||
                wifiNodeOperators[nodeID].user == _msgSender(),
            "ErebrusRegistry: User is not authorized!"
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

    function wifiDeviceCheckpoint(
        uint256 nodeID,
        string memory dataHash
    ) external {
        require(
            erebrusRoles.isOperator(_msgSender()) ||
                wifiNodeOperators[nodeID].user == _msgSender(),
            "ErebrusRegistry: User is not authorized!"
        );
        wifiTotalCheckpoints[nodeID]++;
        uint256 currentCheckpoint = wifiTotalCheckpoints[nodeID];
        wifiDeviceCheckpoints[nodeID][currentCheckpoint] = dataHash;
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

    function registerVpnNode(VPNNode memory node) public {
        uint256 nodeId = currentVpnNode++;
        vpnNodeOperators[nodeId] = node;

        emit VpnNodeRegistered(
            nodeId,
            node.nodename,
            node.ipaddress,
            node.ispinfo,
            node.region,
            node.location
        );
    }

    function vpnDeviceCheckpoint(
        uint256 nodeID,
        string memory dataHash
    ) external {
        require(
            erebrusRoles.isOperator(_msgSender()) ||
                vpnNodeOperators[nodeID].user == _msgSender(),
            "ErebrusRegistry: User is not authorized!"
        );
        vpnTotalCheckpoints[nodeID]++;
        uint256 currentCheckpoint = vpnTotalCheckpoints[nodeID];
        VpnDeviceCheckpoints[nodeID][currentCheckpoint] = dataHash;
    }

    function updateVPNNode(
        uint256 nodeID,
        uint8 _status,
        string memory _region
    ) public {
        require(
            erebrusRoles.isOperator(_msgSender()) ||
                vpnNodeOperators[nodeID].user == _msgSender(),
            "ErebrusRegistry: User is not authorized!"
        );
        vpnNodeOperators[nodeID].status = _status;
        vpnNodeOperators[nodeID].region = _region;

        emit VPNUpdated(nodeID, _status, _region);
    }

    ///////////////////////////////////////////////

    function getWifiDetails(
        uint256 nodeID
    ) external view returns (uint256 price, address owner) {
        price = wifiNodeOperators[nodeID].pricePerMinute;
        owner = wifiNodeOperators[nodeID].user;
    }
}
