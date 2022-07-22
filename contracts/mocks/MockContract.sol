// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../LinkedAddress.sol";

contract MockContract {
    function testNothing() external returns (bool) {
        return true;
    }

    function testValidate(
        address ensRegistry,
        address mainAddress,
        bytes32 mainENSNodeHash,
        string calldata authKey,
        bytes32 authENSNodeHash
    ) external returns (bool) {
        return
            LinkedAddress.validateSender(
                ensRegistry,
                mainAddress,
                mainENSNodeHash,
                authKey,
                authENSNodeHash
            );
    }
}
