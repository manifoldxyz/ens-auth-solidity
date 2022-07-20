// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

/**
 * ENS Registry Interface
 */
interface ENS {
    function resolver(bytes32 node) external view returns (address);
}

/**
 * ENS Resolver Interface
 */
interface Resolver {
    function addr(bytes32 node) external view returns (address);

    function name(bytes32 node) external view returns (string memory);

    function text(bytes32 node, string calldata key) external view returns (string memory);
}

/**
 * Validate a signing address is associtaed with a linked address
 */
library LinkedAddress {
    /**
     * Validate that the message sender is an authentication address for mainAddress
     *
     * @param ensRegistry    Address of ENS registry
     * @param mainAddress     The main address we want to authenticate for.
     * @param mainENSNodeHash The main ENS Node Hash
     * @param authKey         The TEXT record of the authKey we are using for validation
     * @param authENSNodeHash The auth ENS Node Hash
     */
    function validateSender(
        address ensRegistry,
        address mainAddress,
        bytes32 mainENSNodeHash,
        string calldata authKey,
        bytes32 authENSNodeHash
    ) internal view returns (bool) {
        return validate(ensRegistry, mainAddress, mainENSNodeHash, authKey, msg.sender, authENSNodeHash);
    }

    /**
     * Validate that the authAddress is an authentication address for mainAddress
     *
     * @param ensRegistry     Address of ENS registry
     * @param mainAddress     The main address we want to authenticate for.
     * @param mainENSNodeHash The main ENS Node Hash
     * @param authAddress     The address of the authentication wallet
     * @param authENSNodeHash The auth ENS Node Hash
     */
    function validate(
        address ensRegistry,
        address mainAddress,
        bytes32 mainENSNodeHash,
        string calldata authKey,
        address authAddress,
        bytes32 authENSNodeHash
    ) internal view returns (bool) {
        _verifyMainENS(ensRegistry, mainAddress, mainENSNodeHash, authKey, authAddress);
        _verifyAuthENS(ensRegistry, mainAddress, authKey, authAddress, authENSNodeHash);

        return true;
    }

    // *********************
    //   Helper Functions
    // *********************
    function _verifyMainENS(
        address ensRegistry,
        address mainAddress,
        bytes32 mainENSNodeHash,
        string calldata authKey,
        address authAddress
    ) private view {
        // Check if the ENS nodes resolve correctly to the provided addresses
        address mainResolver = ENS(ensRegistry).resolver(mainENSNodeHash);
        require(mainResolver != address(0), "Main ENS not registered");
        require(mainAddress == Resolver(mainResolver).addr(mainENSNodeHash), "Main address is wrong");

        // Verify the authKey TEXT record is set to authAddress by mainENS
        string memory authText = Resolver(mainResolver).text(mainENSNodeHash, authKey);
        require(
            keccak256(bytes(authText)) == keccak256(bytes(_addressToString(authAddress))),
            "Invalid auth address"
        );
    }

    function _verifyAuthENS(
        address ensRegistry,
        address mainAddress,
        string memory authKey,
        address authAddress,
        bytes32 authENSNodeHash
    ) private view {
        // Check if the ENS nodes resolve correctly to the provided addresses
        address authResolver = ENS(ensRegistry).resolver(authENSNodeHash);
        require(authResolver != address(0), "Auth ENS not registed");
        require(authAddress == Resolver(authResolver).addr(authENSNodeHash), "Auth address is wrong");

        // Verify the TEXT record is appropriately set by authENS
        string memory vaultText = Resolver(authResolver).text(authENSNodeHash, "vault");
        require(
            keccak256(abi.encodePacked("eip5131:", authKey, ":", _addressToString(mainAddress))) ==
                keccak256(bytes(vaultText)),
            "Invalid auth text record"
        );
    }

    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
        uint256 value = uint256(uint160(addr));
        bytes memory buffer = new bytes(40);
        for (uint256 i = 39; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        return keccak256(buffer);
    }

    function _addressToString(address addr) private pure returns (string memory ret) {
        uint256 value = uint256(uint160(addr));
        bytes memory buffer = new bytes(42);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 41; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }
}
