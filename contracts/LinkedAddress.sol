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
}

/**
 * Validate a signing address is associtaed with a linked address
 */
library LinkedAddress {
    /**
     * Validate that the message sender is an authentication address for mainAddress
     * @param ensRegistry    Address of ENS registry
     * @param authENSLabel   The ENS label of the authentication wallet (must be `auth[0-9]*`)
     * @param mainAddress    The main address we want to authenticate for.
     * @param mainENSParts   The array of the main address ENS domain parts (e.g. wilkins.eth == ['wilkins', 'eth']).
     *                       This is used vs. the full ENS a a single string name hash computations are gas efficient.
     */
    function validateSender(
        address ensRegistry,
        bytes calldata authENSLabel,
        address mainAddress,
        string[] calldata mainENSParts
    ) internal view returns (bool) {
        return validate(ensRegistry, msg.sender, authENSLabel, mainAddress, mainENSParts);
    }

    /**
     * Validate that the authAddress is an authentication address for mainAddress
     *
     * @param ensRegistry    Address of ENS registry
     * @param authAddress    The address of the authentication wallet
     * @param authENSLabel   The ENS label of the authentication wallet (must be `auth[0-9]*`)
     * @param mainAddress    The main address we want to authenticate for.
     * @param mainENSParts   The array of the main address ENS domain parts (e.g. wilkins.eth == ['wilkins', 'eth']).
     *                       This is used vs. the full ENS a a single string name hash computations are gas efficient.
     */
    function validate(
        address ensRegistry,
        address authAddress,
        bytes calldata authENSLabel,
        address mainAddress,
        string[] calldata mainENSParts
    ) internal view returns (bool) {
        // Check if the ENS nodes resolve correctly to the provided addresses
        bytes32 mainNameHash = _computeNamehash(mainENSParts);
        address mainResolver = ENS(ensRegistry).resolver(mainNameHash);
        require(mainResolver != address(0), "Main ENS not registered");
        require(mainAddress == Resolver(mainResolver).addr(mainNameHash), "Main address is wrong");

        bytes32 mainReverseHash = _computeReverseNamehash(mainAddress);
        address mainReverseResolver = ENS(ensRegistry).resolver(mainReverseHash);
        require(mainReverseResolver != address(0), "Main ENS reverse lookup not registered");

        // Verify that the reverse lookup for mainAddress matches the mainENSParts
        {
            uint256 len = mainENSParts.length;
            bytes memory ensCheckBuffer = bytes(mainENSParts[0]);
            unchecked {
                for (uint256 idx = 1; idx < len; ++idx) {
                    ensCheckBuffer = abi.encodePacked(ensCheckBuffer, ".", mainENSParts[idx]);
                }
            }
            require(
                keccak256(abi.encodePacked(Resolver(mainReverseResolver).name(mainReverseHash))) ==
                    keccak256(ensCheckBuffer),
                "Main ENS mismatch"
            );
        }

        bytes32 authNameHash = _computeNamehash(mainNameHash, string(authENSLabel));
        address authResolver = ENS(ensRegistry).resolver(authNameHash);
        require(authResolver != address(0), "Auth ENS not registed");
        require(authAddress == Resolver(authResolver).addr(authNameHash), "Not authenticated");

        // Check that the subdomain name has the correct format auth[0-9]*.
        bytes4 authPart = bytes4(authENSLabel[:4]);
        require(authPart == "auth", "Invalid prefix");
        unchecked {
            for (uint256 i = authENSLabel.length; i > 4; i--) {
                bytes1 char = authENSLabel[i];
                require(
                    (char >= 0x30 && char <= 0x39) ||
                    (char >= 0x41 && char <= 0x5A) ||
                    (char >= 0x61 && char <= 0x7A),
                    "Invalid char"
                );
            }
        }

        return true;
    }

    // *********************
    //   Helper Functions
    // *********************

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

    function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
        assembly {
            let lookup := 0x3031323334353637383961626364656600000000000000000000000000000000
            let i := 40
            for {

            } gt(i, 0) {

            } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }
            ret := keccak256(0, 40)
        }
    }
}
