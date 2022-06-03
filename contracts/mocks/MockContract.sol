// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../LinkedAddress.sol";

contract MockContract is LinkedAddress {
    function testValidate(address ensRegistry, bytes calldata senderENS, address mainAddress, string[] calldata mainENSParts) external returns(bool) {
        return validate(ensRegistry, senderENS, mainAddress, mainENSParts);
    }
}