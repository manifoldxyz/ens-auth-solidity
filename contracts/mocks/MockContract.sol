// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../LinkedAddress.sol";

contract MockContract {
    function testNothing() external returns (bool) {
        return true;
    }

    function testValidate(
        address ensRegistry,
        bytes calldata authENSLabel,
        address mainAddress,
        string[] calldata mainENSParts
    ) external returns (bool) {
        return LinkedAddress.validateSender(ensRegistry, authENSLabel, mainAddress, mainENSParts);
    }
}
