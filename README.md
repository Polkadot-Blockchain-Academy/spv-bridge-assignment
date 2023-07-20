# Week 2 Assignment - Simple On-Chain Bridge

This assignment covers material from Module 3: Blockchain and Module 4: Smart Contracts.
In it, you will build a btc-relay-like on-chain bridge smart contract.
You will build this bridge in FIXME decide whether it is (BOTH wasm and evm, EITHER wasm or evm, JUST use solidity).

## Solidity

For your first implementation, you need to use a language that targets the EVM.
This basically means Solidity or Vyper (although if you know some esoteric evm language, you are welcome to use that as well).

## ink!

For your second implementation, you need to use a language that targets wasm (the pallet-contracts interface).
This basically means either ink! or ask (although, again, more exotic ones are also welcome).

## Primary Bridge Functionality

The exact implementation of the bridge will vary depending on your language.
There is detailed starter code in each language in this repository to guide you.
Regardless of what language you choose, the bridge will have a few common features.

* **Header Submission** - Any user may act as a relayer, submitting a header from the source chain, and it should be checked on-chain.
* **Transaction Verification** - Any user may act as a verifier, checking whether a transaction that they care about is present in the  source chain
* **State Verification** - Any user may act as a verifier, checking whether some state they care about is present in the source chain.
* **Incentives** - Relayers should earn rewards for their service and verifiers should pay those rewards.
We will use a simple system where the relayer pays a fee to submit (which is burned) and verifiers pay a fee to verify which is passed on to the relayer of the corresponding block.

# Competencies

In this assignment, students will have the opportunity to demonstrate that they have acquired competencies in the following areas:

1. Validate a block header
2. Validate a transaction's existence in a block via Merkle proof
3. Validate some state's existence at some block via Merkle proof


1. Make basic smart contract-style safety checks
  - Don't blindly overwrite storage
  -
2. 
