const truffleAssert = require("truffle-assertions");
const namehash = require("eth-ens-namehash");

const MockContract = artifacts.require("MockContract");
const MockRegistry = artifacts.require("MockRegistry");
const MockResolver = artifacts.require("MockResolver");

contract("LinkedAddress", function ([...accounts]) {
  const [mainAddress, authAddress, anotherAddress] = accounts;

  describe("LinkedAddress", function () {
    let mockContract;
    let mockRegistry;
    let mockResolver;

    beforeEach(async function () {
      mockContract = await MockContract.new();
      mockRegistry = await MockRegistry.new();
      mockResolver = await MockResolver.new();
    });

    async function setupForwardRecords(registry, resolver, address, ENS) {
      const node = namehash.hash(ENS);
      await registry.setResolver(node, resolver.address);
      await resolver.setAddr(node, address);
    }

    async function setupReverseRecord(registry, resolver, address, ENS) {
      const reverseNode = namehash.hash(
        `${address.toString().substring(2).toLowerCase()}.addr.reverse`
      );
      await registry.setResolver(reverseNode, resolver.address);
      await resolver.setName(reverseNode, ENS);
    }

    async function setupTextRecords(resolver, key, value, ENS) {
      const node = namehash.hash(ENS);
      await resolver.setText(node, key, value);
    }

    async function setupENS(registry, resolver, address, ENS) {
      await setupForwardRecords(registry, resolver, address, ENS);
      await setupReverseRecord(registry, resolver, address, ENS);
    }

    it("test standard functionality", async function () {
      const mainENS = "wilkins.eth";
      const mainENSNodeHash = namehash.hash(mainENS);
      const authENS = "auth.wilkins.eth";
      const authENSNodeHash = namehash.hash(authENS);
      const authKey = "auth1";

      await setupENS(mockRegistry, mockResolver, mainAddress, mainENS);
      await setupTextRecords(
        mockResolver,
        `eip5131:${authKey}`,
        authAddress.toString().toLowerCase(),
        mainENS
      );
      await setupENS(mockRegistry, mockResolver, authAddress, authENS);
      await setupTextRecords(
        mockResolver,
        "eip5131:vault",
        `${authKey}:${mainAddress.toString().toLowerCase()}`,
        authENS
      );

      await mockContract.testValidate(
        mockRegistry.address,
        mainAddress,
        mainENSNodeHash,
        authKey,
        authENSNodeHash,
        { from: authAddress }
      );

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          mainAddress,
          mainENSNodeHash,
          authKey,
          authENSNodeHash,
          { from: anotherAddress }
        ),
        "Invalid auth address"
      );
    });

    it("test breaking the chain via invalidating TEXT", async function () {
      const mainENS = "wilkins.eth";
      const mainENSNodeHash = namehash.hash(mainENS);
      const authENS = "auth.wilkins.eth";
      const authENSNodeHash = namehash.hash(authENS);
      const authKey = "auth1";

      await setupENS(mockRegistry, mockResolver, mainAddress, mainENS);
      await setupTextRecords(
        mockResolver,
        `eip5131:${authKey}`,
        authAddress.toString().toLowerCase(),
        mainENS
      );
      await setupENS(mockRegistry, mockResolver, authAddress, authENS);
      await setupTextRecords(
        mockResolver,
        "eip5131:vault",
        `${authKey}:${mainAddress.toString().toLowerCase()}`,
        authENS
      );

      await mockContract.testValidate(
        mockRegistry.address,
        mainAddress,
        mainENSNodeHash,
        authKey,
        authENSNodeHash,
        { from: authAddress }
      );

      await setupTextRecords(mockResolver, `eip5131:${authKey}`, "", mainENS);

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          mainAddress,
          mainENSNodeHash,
          authKey,
          authENSNodeHash,
          { from: authAddress }
        ),
        "Invalid auth address"
      );
    });

    it("test authENS not set", async function () {
      const mainENS = "wilkins.eth";
      const mainENSNodeHash = namehash.hash(mainENS);
      const authENS = "auth.wilkins.eth";
      const authENSNodeHash = namehash.hash(authENS);
      const authKey = "auth1";

      await setupENS(mockRegistry, mockResolver, mainAddress, mainENS);
      await setupTextRecords(
        mockResolver,
        `eip5131:${authKey}`,
        authAddress.toString().toLowerCase(),
        mainENS
      );
      await setupReverseRecord(mockRegistry, mockResolver, authAddress, authENS);
      await setupTextRecords(
        mockResolver,
        "eip5131:vault",
        `${authKey}:${mainAddress.toString().toLowerCase()}`,
        authENS
      );

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          mainAddress,
          mainENSNodeHash,
          authKey,
          authENSNodeHash,
          { from: authAddress }
        ),
        "Auth ENS not registered"
      );
    });

    it("test hijacker", async function () {
      const mainENS = "wilkins.eth";
      const mainENSNodeHash = namehash.hash(mainENS);
      const authENS = "auth.wilkins.eth";
      const authENSNodeHash = namehash.hash(authENS);
      const mainENSHijacker = "hijacker.eth";
      const mainENSHijackerNodeHash = namehash.hash(mainENSHijacker);
      const authENSHijacker = "auth.hijacker.eth";
      const authENSHijackerNodeHash = namehash.hash(authENSHijacker);
      const authKey = "auth1";

      await setupENS(mockRegistry, mockResolver, mainAddress, mainENS);
      await setupTextRecords(
        mockResolver,
        `eip5131:${authKey}`,
        authAddress.toString().toLowerCase(),
        mainENS
      );
      await setupENS(mockRegistry, mockResolver, authAddress, authENS);
      await setupTextRecords(
        mockResolver,
        "eip5131:vault",
        `${authKey}:${mainAddress.toString().toLowerCase()}`,
        authENS
      );
      await setupForwardRecords(mockRegistry, mockResolver, mainAddress, mainENSHijacker);
      await setupENS(mockRegistry, mockResolver, anotherAddress, authENSHijacker);
      await setupTextRecords(
        mockResolver,
        "eip5131:vault",
        `${authKey}:${mainAddress.toString().toLowerCase()}`,
        authENSHijacker
      );

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          mainAddress,
          mainENSHijackerNodeHash,
          authKey,
          authENSHijackerNodeHash,
          { from: anotherAddress }
        ),
        "Invalid auth address"
      );
    });

    it("test nothing", async function () {
      await mockContract.testNothing();
    });
  });
});
