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
     * Validate that the message sender is an authentication address for the mainAddress
     *
     * @param ensRegistry    Address of ENS registry
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
            bytes memory ensCheckBuffer;
            uint256 i = mainENSParts.length;
            for (; i > 1; ) {
                ensCheckBuffer = abi.encodePacked(".", mainENSParts[i - 1], ensCheckBuffer);
                unchecked {
                    i--;
                }
            }
            ensCheckBuffer = abi.encodePacked(mainENSParts[i - 1], ensCheckBuffer);
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
                require(authENSLabel[i] >= 0x30 && authENSLabel[i] <= 0x39, "Invalid char");
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

    function _computeReverseNamehash(address _address) private view returns (bytes32 namehash) {
        namehash = 0x0000000000000000000000000000000000000000000000000000000000000000;
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("reverse"))));
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("addr"))));
        namehash = keccak256(
            abi.encodePacked(namehash, keccak256(_addressToStringLowercase(_address)))
        );
    }

    function _addressToStringLowercase(address _address)
        private
        pure
        returns (bytes memory addressString)
    {
        addressString = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(_address)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            addressString[2 * i] = _bytes1ToChar(hi);
            addressString[2 * i + 1] = _bytes1ToChar(lo);
        }
    }

    function _bytes1ToChar(bytes1 b) private pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}
