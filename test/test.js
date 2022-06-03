const truffleAssert = require('truffle-assertions');

const LinkedAddress = artifacts.require("LinkedAddress");

contract('LinkedAddress', function ([...accounts]) {
  const [
    owner,
    admin,
    another1,
    another2,
    another3,
    another4,
    another5,
    another6,
  ] = accounts;

  describe('LinkedAddress', function() {

    var mockContract;

    beforeEach(async function () {
      mockContract = await LinkedAddress.new();
    });

    it('test', async function () {
      // TODO
    });

  });
});