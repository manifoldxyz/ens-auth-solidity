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

    it("test functionality", async function () {
      const mainENS = "wilkins.eth";
      const authENS = "auth.wilkins.eth";

      const mainENSNode = namehash.hash(mainENS);
      const authENSReverseNode = namehash.hash(
        `${authAddress.toString().substring(2).toLowerCase()}.addr.reverse`
      );

      await mockRegistry.setResolver(mainENSNode, mockResolver.address);
      await mockResolver.setAddr(mainENSNode, mainAddress);

      await mockRegistry.setResolver(authENSReverseNode, mockResolver.address);
      await mockResolver.setName(authENSReverseNode, authENS);

      await mockContract.testValidate(
        mockRegistry.address,
        web3.utils.encodePacked({ value: authENS, type: "string" }),
        mainAddress,
        mainENS.split("."),
        { from: authAddress }
      );

      await truffleAssert.reverts(
        mockContract.testValidate(
          mockRegistry.address,
          web3.utils.encodePacked({ value: authENS, type: "string" }),
          mainAddress,
          mainENS.split("."),
          { from: anotherAddress }
        ),
        "Invalid"
      );
    });
  });
});
