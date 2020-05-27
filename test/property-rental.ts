import {
  Client,
  Provider,
  ProviderRegistry,
  Result,
} from "@blockstack/clarity";
import { assert } from "chai";

describe("Property rental contract test suite", () => {
  let propertyRentalClient: Client;
  let provider: Provider;

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    propertyRentalClient = new Client(
      "SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.propertyRental",
      "propertyRental",
      provider
    );
  });

  it("should have a valid syntax", async () => {
    await propertyRentalClient.checkContract();
  });

  describe("deploying an instance of the contract", () => {
    before(async () => {
      await propertyRentalClient.deployContract();
    });

    it(
      "should create only one property per contract based on name, type, and serial number"
    );

    it("should return 'hello world'", async () => {
      const query = propertyRentalClient.createQuery({
        method: { name: "say-hi", args: [] },
      });
      const receipt = await propertyRentalClient.submitQuery(query);
      const result = Result.unwrapString(receipt);
      assert.equal(result, "hello world");
    });

    it("should echo number", async () => {
      const query = propertyRentalClient.createQuery({
        method: { name: "echo-number", args: ["123"] },
      });
      const receipt = await propertyRentalClient.submitQuery(query);
      const result = Result.unwrapInt(receipt);
      assert.equal(result, 123);
    });
  });

  after(async () => {
    await provider.close();
  });
});
