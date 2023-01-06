// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.7;
import "./ERC4907.sol";

contract Subscription is ERC4907 {
    uint256 public immutable maxInterval = 15768000; //six months
    uint256 public immutable minInterval = 10800; //three hours

    struct SubscriptionStatus {
        address accountOperator;
        uint256 rateAmount;
        uint256 renewalFee;
        uint256 subscriptionTime;
        //string credentials;
        bool Valid;
    }

    mapping(uint256 => SubscriptionStatus) private n_attributes;

    function createSubscription(
        uint256 tokenId,
        uint256 _rateAmount,
        uint256 _renewalFee
    ) external {
        require(ownerOf(tokenId) == msg.sender, "not owner");
        n_attributes[tokenId] = SubscriptionStatus({
            accountOperator: msg.sender,
            rateAmount: _rateAmount,
            renewalFee: _renewalFee,
            //credentials: "0x",
            subscriptionTime: block.timestamp,
            Valid: true
        });
    }

    function topUp(uint256 _tokenID) external payable {
        require(n_attributes[_tokenID].Valid == true, "NFT not active");
        require(
            msg.value >= n_attributes[_tokenID].rateAmount * 3,
            "too little payment"
        );

        uint256 newTime = calculateSubscriptionTime(msg.value, _tokenID);

        if (newTime >= minInterval && newTime <= maxInterval) {
            n_attributes[_tokenID].subscriptionTime = block.timestamp + newTime;
            address receiver = n_attributes[_tokenID].accountOperator;
            (bool success, ) = receiver.call{value: msg.value}("");
            require(success, "Transfer failed");
        }
        n_attributes[_tokenID].Valid = false;
    }

    function calculateSubscriptionTime(
        uint256 _amount,
        uint256 _tokenID
    ) internal view returns (uint256) {
        uint256 hour = _amount / n_attributes[_tokenID].rateAmount; //10/ 100
        uint256 newTime = ((hour * 60) * 60) / (10 ** 18);

        return newTime;
    }

    function renew(uint256 _tokenID) external payable {
        require(
            n_attributes[_tokenID].subscriptionTime <= block.timestamp,
            "still time left for subscription"
        );
        require(ownerOf(_tokenID) == msg.sender, "not owner");
        require(
            msg.value >= n_attributes[_tokenID].renewalFee,
            "not enough for fee"
        );

        address receiver = n_attributes[_tokenID].accountOperator;
        (bool success, ) = receiver.call{value: msg.value}("");
        require(success, "Transfer failed");
        n_attributes[_tokenID].Valid = true;
        n_attributes[_tokenID].subscriptionTime = block.timestamp + 10800;
    }

    function toActive(uint _tokenID, bool _status) external {
        require(
            n_attributes[_tokenID].accountOperator == msg.sender,
            "Not the authorised person"
        );
        n_attributes[_tokenID].Valid = _status;
    }
}
