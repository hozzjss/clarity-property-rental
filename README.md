# Property rental 
> A fully fledged clarity smart contract

## Use case

If you had an asset (property, device, anything) that you want to rent and you want to remove the "Trust me bro" doctrine from the equation

1. Negotiations can begin if the contract is not signed yet, or is to be renewed (you can negotiate rent, deposit, and contract duration).
2. After both parties agree to the very well negotiated terms they can -in human terms- sign the contract, or renew it with the update terms, but both parties have to agree to the new terms
3. During contract duration, if renter breaches contract by not paying after the beginning of the month till a defined grace period, the owner is given the control to either renew or end contract on grounds of breach of contract, this would guarantee the rights of the owner, the owner can extend the grace period too (for example a good landlord during the corona crisis), and can waive the month's fees, but if the month ended without payment and the owner did not waive the fees, the renter would be in debt for the owner, if the owner did not request an extension of grace period nor to end contract
4. You're a real life hero if you read all that really, I'm sorry I put you through this xD.
5. If the contract's duration ended both parties can choose to renegotiate or if one of them wishes expire contract.
6. Any party could request contract to be cancelled, and it would be cancelled only if both parties decide to cancel the contract.

To run tests you can use


for unit tests

`npm/yarn/pnpm run test:unit`


for integration tests you'll need a running local node check [Running a test node](https://docs.blockstack.org/core/smart/neon-node.html)
from the blockstack docs.

`npm/yarn/pnpm run test:integration`