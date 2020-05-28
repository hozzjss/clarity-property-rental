import {
  Client,
  Provider,
  ProviderRegistry,
  Result,
} from "@blockstack/clarity";
import { assert } from "chai";
import keys from "../../keys";

describe("Property rental contract test suite", () => {
  let propertyRentalClient: Client;
  let provider: Provider;

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    propertyRentalClient = new Client(
      keys.renterAddress + ".property-rental",
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

    // it("should create only one property per contract based on name, type, and serial number and owner should be its owner", async () => {
    //   const query = propertyRentalClient.createQuery({
    //     method: { name: "get-owner", args: [] },
    //   });
    //   const receipt = await propertyRentalClient.submitQuery(query);
    //   const result = Result.unwrap(receipt);
    //   assert.include(result.toString(), keys.ownerAddress);
    // });

    it(`should help both parties negotiate terms,
      and the contract cannot be signed until both parties
      agree to the terms`, async () => {
      const negotiate = async (
        negotiator: string,
        newRent: number,
        newDuration: number,
        newDeposit: number
      ) => {
        const transaction = propertyRentalClient.createTransaction({
          method: {
            args: [`${newRent}`, `${newDuration}`, `${newDeposit}`],
            name: "negotiate-rent",
          },
        });

        return await propertyRentalClient.submitTransaction(transaction);
      };
    });

    it("Should get current month", async () => {
      const query = propertyRentalClient.createQuery({
        method: {
          args: [],
          name: "get-current-month",
        },
      });
      const receipt = await propertyRentalClient.submitQuery(query);
      const result = Result.unwrap(receipt);
      assert.equal(result, "u" + (new Date().getMonth() + 1));
    });
  });
  after(async () => {
    await provider.close();
  });
});
