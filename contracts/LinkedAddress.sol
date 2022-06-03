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
interface Resolver{
    function addr(bytes32 node) external view returns (address);
    function name(bytes32 node) external view returns (string memory);
}

/**
 * Validate a signing address is associtaed with a linked address
 */
abstract contract LinkedAddress {

    /**
     * Validate that the message sender is an authentication address for the mainAddress
     *
     * @param ensRegistry    Address of ENS registry
     * @param senderENS      Sender ENS. Pass this in for cheaper checking against main address ENS
     * @param mainAddress    The main address we are checking against
     * @param mainENSParts   The array of the main address ENS domain parts (e.g. wilkins.eth == ['wilkins', 'eth'])
     */
    function validate(address ensRegistry, bytes calldata senderENS, address mainAddress, string[] memory mainENSParts) internal view returns(bool) {
        bytes32 mainNameHash = computeNamehash(mainENSParts);
        address mainResolver = ENS(ensRegistry).resolver(mainNameHash);
        require(mainResolver != address(0), "Invalid");
        require(mainAddress == Resolver(mainResolver).addr(mainNameHash), "Invalid");
        bytes32 senderReverseNameHash = computeReverseNamehash();
        address senderResolver = ENS(ensRegistry).resolver(senderReverseNameHash);
        require(senderResolver != address(0), "Invalid");
        string memory senderENSLookup = Resolver(senderResolver).name(senderReverseNameHash);
        require(keccak256(senderENS) == keccak256(bytes(senderENSLookup)), "Invalid");

        // Quick substring comparison
        // Get the total theoretical length of mainENS
        bytes memory ensCheckBuffer;
        for (uint i = mainENSParts.length; i > 0;) {
            ensCheckBuffer = abi.encodePacked('.', mainENSParts[i-1], ensCheckBuffer);
            unchecked {
              i--;
            }
        }
        bytes32 ensCheck = keccak256(ensCheckBuffer);
        
        // Length of senderENS must be >= ensCheckBuffer.length+4 (since it needs to be of format auth[0-9]*.mainENS)
        require(senderENS.length >= ensCheckBuffer.length+4, "Invalid");
        // Check ending substring of the senderENS matches
        require(ensCheck == keccak256(senderENS[senderENS.length-ensCheckBuffer.length:]), "Invalid");
        // Check prefix matches auth[0-9]*.
        require(keccak256(abi.encodePacked('auth')) == keccak256(senderENS[:4]), "Invalid");
        for (uint i = senderENS.length-ensCheckBuffer.length; i > 4;) {
          require(senderENS[0] >= 0x30 && senderENS[i] <= 0x39, "Invalid");
          unchecked {
            i--;
          }
        }
        return true;
    }

    function addressToStringLowercase(address x) private pure returns (bytes memory s) {
        s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);            
        }
    }

    function char(bytes1 b) private pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function computeNamehash(string[] memory _nameParts) private pure returns (bytes32 namehash) {
        namehash = 0x0000000000000000000000000000000000000000000000000000000000000000;
        for (uint i = _nameParts.length; i > 0;) {
            namehash = keccak256(
              abi.encodePacked(namehash, keccak256(abi.encodePacked(_nameParts[i-1])))
            );
            unchecked {
              i--;
            }
        }
    }

    function computeReverseNamehash() private view returns (bytes32 namehash) {
        namehash = 0x0000000000000000000000000000000000000000000000000000000000000000;
        namehash = keccak256(
          abi.encodePacked(namehash, keccak256(abi.encodePacked('reverse')))
        );
        namehash = keccak256(
          abi.encodePacked(namehash, keccak256(abi.encodePacked('addr')))
        );
        namehash = keccak256(
          abi.encodePacked(namehash, keccak256(addressToStringLowercase(msg.sender)))
        );
    }

}