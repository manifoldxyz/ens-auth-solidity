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

    async function setupENS(registry, resolver, address, ENS) {
      await setupForwardRecords(registry, resolver, address, ENS);
      await setupReverseRecord(registry, resolver, address, ENS);
    }

    it("test standard functionality", async function () {
      const mainENS = "wilkins.eth";
      const authENS = "auth.wilkins.eth";

      await setupENS(mockRegistry, mockResolver, mainAddress, mainENS);
      await setupENS(mockRegistry, mockResolver, authAddress, authENS);

      await mockContract.testValidate(
        mockRegistry.address,
        web3.utils.encodePacked({ value: authENS.split(".")[0], type: "string" }),
        mainAddress,
        mainENS.split("."),
        { from: authAddress }
      );

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          web3.utils.encodePacked({ value: authENS.split(".")[0], type: "string" }),
          mainAddress,
          mainENS.split("."),
          { from: anotherAddress }
        ),
        "Not authenticated"
      );
    });

    it("test auth.main not set", async function () {
      const mainENS = "wilkins.eth";
      const authENS = "auth.wilkins.eth";

      await setupENS(mockRegistry, mockResolver, mainAddress, mainENS);
      await setupReverseRecord(mockRegistry, mockResolver, authAddress, authENS);

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          web3.utils.encodePacked({ value: authENS.split(".")[0], type: "string" }),
          mainAddress,
          mainENS.split("."),
          { from: authAddress }
        ),
        "Auth ENS not registed"
      );
    });

    it("test wrong prefix", async function () {
      const mainENS = "wilkins.eth";
      const authENS = "foobar.wilkins.eth";

      await setupENS(mockRegistry, mockResolver, mainAddress, mainENS);
      await setupENS(mockRegistry, mockResolver, authAddress, authENS);

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          web3.utils.encodePacked({ value: authENS.split(".")[0], type: "string" }),
          mainAddress,
          mainENS.split("."),
          { from: authAddress }
        ),
        "Invalid prefix"
      );
    });

    it("test wrong domain", async function () {
      const mainENS = "random.eth";
      const authENS = "auth.wilkins.eth";

      await setupENS(mockRegistry, mockResolver, mainAddress, mainENS);
      await setupENS(mockRegistry, mockResolver, authAddress, authENS);

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          web3.utils.encodePacked({ value: authENS.split(".")[0], type: "string" }),
          mainAddress,
          mainENS.split("."),
          { from: authAddress }
        ),
        "Auth ENS not registed"
      );
    });

    it("test hijacker", async function () {
      const mainENS = "wilkins.eth";
      const authENS = "auth.wilkins.eth";
      const mainENSHijacker = "hijacker.eth";
      const authENSHijacker = "auth.hijacker.eth";

      await setupENS(mockRegistry, mockResolver, mainAddress, mainENS);
      await setupENS(mockRegistry, mockResolver, authAddress, authENS);
      await setupForwardRecords(mockRegistry, mockResolver, mainAddress, mainENSHijacker);
      await setupENS(mockRegistry, mockResolver, anotherAddress, authENSHijacker);

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          web3.utils.encodePacked({ value: authENSHijacker.split(".")[0], type: "string" }),
          mainAddress,
          mainENSHijacker.split("."),
          { from: anotherAddress }
        ),
        "Main ENS mismatch"
      );
    });

    it("test nothing", async function () {
      await mockContract.testNothing();
    });
  });
});
