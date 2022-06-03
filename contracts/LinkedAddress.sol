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
abstract contract LinkedAddress {
    bytes32 private constant AUTH_PREFIX_KECCAK256 = keccak256(abi.encodePacked("auth"));

    /**
     * Validate that the message sender is an authentication address for the mainAddress
     *
     * @param ensRegistry    Address of ENS registry
     * @param senderENS      Sender ENS. This is passed in for gas efficient checking against main address ENS
     * @param mainAddress    The main address we are checking against
     * @param mainENSParts   The array of the main address ENS domain parts (e.g. wilkins.eth == ['wilkins', 'eth']).
     *                       This is used vs. the full ENS a a single string name hash computations are gas efficient.
     */
    function validate(
        address ensRegistry,
        bytes calldata senderENS,
        address mainAddress,
        string[] memory mainENSParts
    ) internal view returns (bool) {
        bytes32 mainNameHash = _computeNamehash(mainENSParts);
        address mainResolver = ENS(ensRegistry).resolver(mainNameHash);
        require(mainResolver != address(0), "Invalid");
        require(mainAddress == Resolver(mainResolver).addr(mainNameHash), "Invalid");

        bytes32 senderReverseNameHash = _computeReverseNamehash();
        address senderResolver = ENS(ensRegistry).resolver(senderReverseNameHash);
        require(senderResolver != address(0), "Invalid");
        string memory senderENSLookup = Resolver(senderResolver).name(senderReverseNameHash);
        require(keccak256(senderENS) == keccak256(bytes(senderENSLookup)), "Invalid");

        // Check main domain matches, and the format is auth[0-9]*.<main domain>
        bytes memory ensCheckBuffer;
        {
            for (uint256 i = mainENSParts.length; i > 0; ) {
                ensCheckBuffer = abi.encodePacked(".", mainENSParts[i - 1], ensCheckBuffer);
                unchecked {
                    i--;
                }
            }
            bytes32 ensCheck = keccak256(ensCheckBuffer);

            // Length of senderENS must be >= ensCheckBuffer.length+4 (since it needs to be of format auth[0-9]*.mainENS)
            require(senderENS.length >= ensCheckBuffer.length + 4, "Invalid");
            // Check ending substring of the senderENS matches
            require(
                ensCheck == keccak256(senderENS[senderENS.length - ensCheckBuffer.length:]),
                "Invalid"
            );
            // Check prefix matches auth[0-9]*.
            require(AUTH_PREFIX_KECCAK256 == keccak256(senderENS[:4]), "Invalid");
            for (uint256 i = senderENS.length - ensCheckBuffer.length; i > 4; ) {
                require(senderENS[0] >= 0x30 && senderENS[i] <= 0x39, "Invalid");
                unchecked {
                    i--;
                }
            }
        }

        // Check auth subdomain forward record
        {
            uint256 subdomainLength = senderENS.length - ensCheckBuffer.length;
            bytes32 authNameHash = keccak256(
                abi.encodePacked(mainNameHash, keccak256(senderENS[:subdomainLength]))
            );
            address authResolver = ENS(ensRegistry).resolver(authNameHash);
            require(authResolver != address(0), "Invalid");
            require(msg.sender == Resolver(authResolver).addr(authNameHash), "Invalid");
        }
        return true;
    }

    // *********************
    //   Helper Functions
    // *********************

    function _computeNamehash(string[] memory _nameParts) private pure returns (bytes32 namehash) {
        namehash = 0x0000000000000000000000000000000000000000000000000000000000000000;
        for (uint256 i = _nameParts.length; i > 0; ) {
            namehash = keccak256(
                abi.encodePacked(namehash, keccak256(abi.encodePacked(_nameParts[i - 1])))
            );
            unchecked {
                i--;
            }
        }
    }

    function _computeReverseNamehash() private view returns (bytes32 namehash) {
        namehash = 0x0000000000000000000000000000000000000000000000000000000000000000;
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("reverse"))));
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("addr"))));
        namehash = keccak256(
            abi.encodePacked(namehash, keccak256(_addressToStringLowercase(msg.sender)))
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
