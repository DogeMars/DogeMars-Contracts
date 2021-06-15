# DogeMars

DogeMars is a community token developed based on BSC. The purpose of DogeMars is to help Dogecoin achieve its due value.

## DogeMars Protocol

In each trade, the transaction is taxed a 10% fee, which is split 2 ways.
* 5% fee is reallocated to all existing DogeMars holders.
* 5% fee is split 50 / 50, half of which is sold into Dogecoin by the contract, while the other half are paired automatically with the previously mentioned Dogecoin and added as a liquidity pair on PancakeSwap, permanently locked.

## Contracts

* DogeMars - implements DogeMars Protocol described above
* BulkSender - can be used for airdrop
* LiquiditySponsor - lock 48% DogeMars, which can only be used for adding liquidity
* InvitationFund - reward Dogecoin to those who invite new ones to DogeMars
