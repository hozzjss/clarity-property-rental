const BigNum = require("bn.js");
import {
  makeContractCall,
  makeSmartContractDeploy,
  StacksTestnet,
  broadcastTransaction,
  uintCV,
  makeContractSTXPostCondition,
  FungibleConditionCode,
} from "@blockstack/stacks-transactions";
import * as fs from "fs";

const delay = (ms = 10000) => new Promise((r) => setTimeout(r, ms));

const STACKS_API_URL = "http://127.0.0.1:20443";
const network = new StacksTestnet();
network.coreApiUrl = STACKS_API_URL;
import keys from "../../keys";
import { PostCondition } from "@blockstack/stacks-transactions/lib/postcondition";
const contractName = "property-rental";
const codeBody = fs.readFileSync("./contracts/property-rental.clar").toString();

const acceptTerms = async (
  partyKey: string,
  nonce: number,
  conditions: PostCondition[]
) => {
  const transaction = await makeContractCall({
    contractAddress: keys.renterAddress,
    contractName,
    functionName: "accept-terms",
    functionArgs: [],
    fee: new BigNum(300),
    senderKey: partyKey,
    nonce: new BigNum(nonce),
    network,
    postConditions: conditions,
  });

  var result = await broadcastTransaction(transaction, network);
  await delay();
  console.log(result);
};

describe("status contract test suite", async () => {
  before(async () => {
    const fee = new BigNum(15000);
    console.log("deploy contract");
    var transaction = await makeSmartContractDeploy({
      contractName,
      codeBody,
      fee,
      senderKey: keys.renterSecret,
      nonce: new BigNum(0),
      network,
    });
    console.log(await broadcastTransaction(transaction, network));
    await delay();
  });

  it(`should help both parties negotiate terms,
      and the contract cannot be signed until both parties
      agree to the terms
      `, async () => {
    const negotiate = async (
      negotiatorKey: string,
      nonce: number,
      newRent: number,
      newDuration: number,
      newDeposit: number
    ) => {
      console.log("start negotiation");
      const transaction = await makeContractCall({
        contractAddress: keys.renterAddress,
        contractName,
        functionName: "negotiate-rent",
        functionArgs: [
          uintCV(newRent),
          uintCV(newDuration),
          uintCV(newDeposit),
        ],
        fee: new BigNum(500),
        senderKey: negotiatorKey,
        nonce: new BigNum(nonce),
        network,
      });

      var result = await broadcastTransaction(transaction, network);
      console.log(result);
      await delay();
    };

    console.log(`Renter: I think the property is worth 50
    I'm renting it for 36 months 
    so you gotta give me a bargain here`);

    await negotiate(keys.renterSecret, 1, 50, 36, 50);
    await delay(1000);

    console.log(`Owner: You're driving a hard bargain`);
    console.log(`Owner: this should be fair!!`);

    await negotiate(keys.ownerSecret, 0, 90, 36, 90);

    console.log(`Renter: That does sound fair great I accept the terms`);
    await acceptTerms(keys.renterSecret, 2, []);
    await delay();

    console.log("Owner: Alright that was pretty good enjoy your rental!");
    await acceptTerms(keys.ownerSecret, 1, [
      makeContractSTXPostCondition(
        keys.renterAddress,
        contractName,
        FungibleConditionCode.Equal,
        new BigNum(50)
      ),
    ]);

    await delay();

    console.log("Contract signed!");
  });

  it("Should not complete the contract until both agree to terms", async () => {
    await acceptTerms(keys.ownerSecret, 2, [
      makeContractSTXPostCondition(
        keys.renterAddress,
        contractName,
        FungibleConditionCode.Equal,
        new BigNum(0)
      ),
    ]);

    await delay();

    await acceptTerms(keys.renterSecret, 3, [
      makeContractSTXPostCondition(
        keys.renterAddress,
        contractName,
        FungibleConditionCode.Equal,
        new BigNum(50)
      ),
    ]);

    await delay();
  });
});
