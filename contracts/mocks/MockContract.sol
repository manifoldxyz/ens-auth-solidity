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
        string[] calldata mainENSParts,
        string calldata authKey,
        string[] calldata authENSParts
    ) external returns (bool) {
        return
            LinkedAddress.validateSender(
                ensRegistry,
                mainAddress,
                mainENSParts,
                authKey,
                authENSParts
            );
    }
}
