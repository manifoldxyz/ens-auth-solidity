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
     * @param mainAddress    The main address we want to authenticate for.
     * @param mainENSParts   The array of the main address ENS domain parts (e.g. wilkins.eth == ['wilkins', 'eth']).
     *                       This is used vs. the full ENS a a single string name hash computations are gas efficient.
     * @param ensRegistry    Address of ENS registry
     * @param authKey        The TEXT record of the authKey we are using for validation
     * @param authENSParts   The array of the auth address ENS domain parts (e.g. auth.wilkins.eth == ['auth', 'wilkins', 'eth']).
     *                       This is used vs. the full ENS a a single string name hash computations are gas efficient.
     */
    function validateSender(
        address ensRegistry,
        address mainAddress,
        string[] calldata mainENSParts,
        string calldata authKey,
        string[] calldata authENSParts
    ) internal view returns (bool) {
        return validate(ensRegistry, mainAddress, mainENSParts, authKey, msg.sender, authENSParts);
    }

    /**
     * Validate that the authAddress is an authentication address for mainAddress
     *
     * @param ensRegistry    Address of ENS registry
     [0-9A-Za-z]*`)
     * @param mainAddress    The main address we want to authenticate for.
     * @param mainENSParts   The array of the main address ENS domain parts (e.g. wilkins.eth == ['wilkins', 'eth']).
     *                       This is used vs. the full ENS a a single string name hash computations are gas efficient.
     * @param authKey        The TEXT record of the authKey we are using for validation
     * @param authAddress    The address of the authentication wallet
     * @param authENSParts   The array of the auth address ENS domain parts (e.g. auth.wilkins.eth == ['auth', 'wilkins', 'eth']).
     *                       This is used vs. the full ENS a a single string name hash 
     */
    function validate(
        address ensRegistry,
        address mainAddress,
        string[] calldata mainENSParts,
        string calldata authKey,
        address authAddress,
        string[] calldata authENSParts
    ) internal view returns (bool) {
        _verifyMainENS(ensRegistry, mainAddress, mainENSParts, authKey, authAddress);
        _verifyAuthENS(ensRegistry, mainAddress, authKey, authAddress, authENSParts);

        return true;
    }

    // *********************
    //   Helper Functions
    // *********************
    function _verifyMainENS(
        address ensRegistry,
        address mainAddress,
        string[] calldata mainENSParts,
        string calldata authKey,
        address authAddress
    ) private view {
        // Check if the ENS nodes resolve correctly to the provided addresses
        bytes32 mainNameHash = _computeNamehash(mainENSParts);
        address mainResolver = ENS(ensRegistry).resolver(mainNameHash);
        require(mainResolver != address(0), "Main ENS not registered");
        require(mainAddress == Resolver(mainResolver).addr(mainNameHash), "Main address is wrong");

        // Verify the authKey TEXT record is set to authAddress by mainENS
        string memory authText = Resolver(mainResolver).text(mainNameHash, authKey);
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
        string[] calldata authENSParts
    ) private view {
        // Check if the ENS nodes resolve correctly to the provided addresses
        bytes32 authNameHash = _computeNamehash(authENSParts);
        address authResolver = ENS(ensRegistry).resolver(authNameHash);
        require(authResolver != address(0), "Auth ENS not registed");
        require(authAddress == Resolver(authResolver).addr(authNameHash), "Auth address is wrong");

        // Verify the TEXT record is appropriately set by authENS
        string memory vaultText = Resolver(authResolver).text(authNameHash, "vault");
        require(
            keccak256(abi.encodePacked("eip5131:", authKey, ":", _addressToString(mainAddress))) ==
                keccak256(bytes(vaultText)),
            "Invalid auth text record"
        );
    }

    function _computeNamehash(string[] calldata _nameParts)
        private
        pure
        returns (bytes32 namehash)
    {
        namehash = 0x0000000000000000000000000000000000000000000000000000000000000000;
        unchecked {
            for (uint256 i = _nameParts.length; i > 0; --i) {
                namehash = _computeNamehash(namehash, _nameParts[i - 1]);
            }
        }
    }

    function _computeNamehash(bytes32 parentNamehash, string calldata name)
        private
        pure
        returns (bytes32 namehash)
    {
        namehash = keccak256(abi.encodePacked(parentNamehash, keccak256(bytes(name))));
    }

    // _computeNamehash('addr.reverse')
    bytes32 constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    function _computeReverseNamehash(address _address) private pure returns (bytes32 namehash) {
        namehash = keccak256(abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(_address)));
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
