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
      "SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.property-rental",
      "property-rental",
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

    it("should create only one property per contract based on name, type, and serial number and owner should be its owner", async () => {
      const query = propertyRentalClient.createQuery({
        method: { name: "get-owner", args: [] },
      });
      const receipt = await propertyRentalClient.submitQuery(query);
      const result = Result.unwrap(receipt);
      assert.include(
        result.toString(),
        "ST1TXPQCP005M76WZN7KXJ83V289WP098GKG6F2VS"
      );
    });
  });
  after(async () => {
    await provider.close();
  });
});
