# Week 2 Assignment - Simple On-Chain Bridge

This assignment covers material from Module 3: Blockchain and Module 4: Smart Contracts.
In it, you will build a btc-relay-like on-chain bridge smart contract.
You will build this bridge in either ink! or solidity.

## Primary Bridge Functionality

The exact implementation of the bridge will vary depending on your language.
There is detailed starter code in each language in this repository to guide you.
Regardless of what language you choose, the bridge will have a few common features.

- **Header Submission** - Any user may act as a relayer, submitting a header from the source chain, and it should be checked on-chain.
- **Transaction Verification** - Any user may act as a verifier, checking whether a transaction that they care about is present in the source chain
- **State Verification** - Any user may act as a verifier, checking whether some state they care about is present in the source chain.
- **Incentives** - Relayers should earn rewards for their service and verifiers should pay those rewards.
  We will use a simple system where the relayer pays a fee to submit (which is burned) and verifiers pay a fee to verify which is passed on to the relayer of the corresponding block.

## Minimal Public Test Suite

We provide a small and intentionally incomplete test suite that tests a few common cases in your contract.
This is to help you understand if you're on the right track.
You should also write your own tests to check more edge cases.

### Ink tests

To run the ink! tests:

```bash
cd ink/spv_bridge
cargo test
```

### Solidity tests

To run the solidity tests, you will need [foundry](https://book.getfoundry.sh/) installed. Then you can run:

```bash
forge test
```

## Submission and Grading

Work will only be graded if pushed to the `main` branch in Github before the deadline, all other branches will be ignored.

**NOTE: Your exam will be graded with a private set of integration tests.**

This has some important implications:

- Do not make anything private.
- Do not change the name/signature of any function.

## Deadline

The deadline for submission will be communicated when the assignment is first sent to you, and the Github classroom invitation link mentions this explicitly as well. All grades will be assessed using the commit present on main at the time of the deadline. All other work will be ignored.

## Private Test Suite and Manual Grading

The primary way we will grade your work is through an automated testing suite that is kept private to the Academy team.

There are also some human-graded aspects such as:

- Ensuring that your code is of high quality and readability.
- Ensuring that your solutions are not plagiarized.
- Ensuring that you haven't imported a dependency to do the heavy lifting of your code problem.

## 🚀 Good luck! 🚀

Please reach out to the Academy team if you have any questions or concerns related to this assignment.
