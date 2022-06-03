// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../LinkedAddress.sol";

contract MockContract {
    function testValidate(
        address ensRegistry,
        address authAddress,
        bytes calldata authENSLabel,
        address mainAddress,
        string[] calldata mainENSParts
    ) external returns (bool) {
        return
            LinkedAddress.validate(
                ensRegistry,
                authAddress,
                authENSLabel,
                mainAddress,
                mainENSParts
            );
    }
}
