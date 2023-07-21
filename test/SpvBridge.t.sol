// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SpvBridge.sol";

contract SpvBridgeTest is Test {
    SpvBridge public bridge;
    // Threshold is max / 4 so we have about a 1 in 4 chance of finding a valid nonce
    uint threshold = uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 4;
    uint relay_fee = 1_000;
    uint verify_fee = 100;
    Header genesis;
    uint genesis_hash;
    address player;

    event HeaderSubmitted(uint256 block_hash, uint256 block_height, address submitter);

    // Helper function to generate a child block.
    // The tx_root can be passed in manually to allow unique forks.
    function make_child(Header memory parent, uint256 tx_root) public view returns (Header memory) {
        uint256 parent_hash = uint(keccak256(abi.encode(parent)));
        Header memory child = Header ({
            height: parent.height + 1,
            parent: parent_hash,
            storage_root: 0,
            transactions_root: tx_root,
            pow_nonce: 0
        });

        while (uint(keccak256(abi.encode(child))) >= threshold) {
            child.pow_nonce = child.pow_nonce + 1;
        }

        return child;
    }

    // Helper function to generate a child block with zero tx_root.
    function make_child(Header memory parent) public view returns (Header memory) {
        return make_child(parent, 0);
    }

    function setUp() public {

        genesis = Header ({
            height: 100,
            parent: 0,
            storage_root: 0,
            transactions_root: 0,
            // The initial block is not checked; not even its pow seal;
            // We put a non-zero nonce here to make sure this block
            // isn't the default block.
            pow_nonce: 1
        });

        genesis_hash = uint(keccak256(abi.encode(genesis)));

        vm.prank(player);
        bridge = new SpvBridge(genesis, threshold, relay_fee, verify_fee);
        player = address(0);
        deal(player, 10_000 ether);
    }

    function testSubmitExtendLongestChain() public {
        // Calculate a new header
        Header memory child = make_child(genesis);
        uint256 child_hash = uint(keccak256(abi.encode(child)));

        // Expect the event
        vm.expectEmit();
        emit HeaderSubmitted(child_hash, 101, player);

        // Submit the new header
        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(child);
        
        // Validate the storage
        assertEq(bridge.canon_chain(100), genesis_hash);
        assertEq(bridge.canon_chain(101), child_hash);

        assertEq(bridge.fee_recipient(genesis_hash), player);
        assertEq(bridge.fee_recipient(child_hash), player);
    }

    function testSubmitSideChain() public {

        // We start by creating a linear source chain that looks like this
        // G---A---B

        // Calculate new headers and submit
        Header memory a = make_child(genesis);
        uint256 a_hash = uint(keccak256(abi.encode(a)));
        Header memory b = make_child(a);
        uint256 b_hash = uint(keccak256(abi.encode(b)));

        // Submit the chain to the bridge
        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(a);
        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(b);

        // Now we create a fork in the source chain.
        // The fork is not long enough to cause a re-org.
        // We should be able to submit the header successfully, but it should not cause a re-org
        // G---A---B
        //  \
        //   --C

        Header memory c = make_child(genesis, 1);
        uint256 c_hash = uint(keccak256(abi.encode(c)));
        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(c);
        
        // Validate the storage
        assertEq(bridge.canon_chain(100), genesis_hash);
        assertEq(bridge.canon_chain(101), a_hash);
        assertEq(bridge.canon_chain(102), b_hash);

        assertEq(bridge.fee_recipient(genesis_hash), player);
        assertEq(bridge.fee_recipient(a_hash), player);
        assertEq(bridge.fee_recipient(b_hash), player);
        assertEq(bridge.fee_recipient(c_hash), player);
    }

    function testSubmitReorgChain() public {

        // We start by creating a linear source chain that looks like this
        // G---A

        // Calculate new headers and submit
        Header memory a = make_child(genesis);
        uint256 a_hash = uint(keccak256(abi.encode(a)));

        // Submit the chain to the bridge
        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(a);

        // Now we create a fork in the source chain.
        // The fork is long enough to cause a re-org.
        // G---A
        //  \
        //   --C---D

        Header memory c = make_child(genesis, 1);
        uint256 c_hash = uint(keccak256(abi.encode(c)));
        Header memory d = make_child(c, 1);
        uint256 d_hash = uint(keccak256(abi.encode(d)));

        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(c);
        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(d);
        
        // Validate the storage
        assertEq(bridge.canon_chain(100), genesis_hash);
        assertEq(bridge.canon_chain(101), c_hash);
        assertEq(bridge.canon_chain(102), d_hash);

        assertEq(bridge.fee_recipient(genesis_hash), player);
        assertEq(bridge.fee_recipient(a_hash), player);
        assertEq(bridge.fee_recipient(c_hash), player);
        assertEq(bridge.fee_recipient(d_hash), player);
    }

    function testTxVerificationSuccess() public {
        // We start by creating a linear source chain that looks like this
        // G---A
        Header memory a = make_child(genesis);

        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(a);

        // Now we try to validate a transaction using the stubbed logic
        assert(bridge.verify_transaction{value: verify_fee}(0, genesis_hash, 0, MerkleProof({verifies: true})));
    }

    function testTxVerificationFailure() public {
        // We start by creating a linear source chain that looks like this
        // G---A
        Header memory a = make_child(genesis);

        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(a);

        // Now we try to validate a transaction using the stubbed logic
        assert(!bridge.verify_transaction{value: verify_fee}(0, genesis_hash, 0, MerkleProof({verifies: false})));
    }

    //TODO There are many more ways that a transaction or state verification can fail,
    // that we have not yet tested for.
    // You would be wise to add some tests of your own to ensure your code is working as expected.

    function testStateVerificationSuccess() public {
        // We start by creating a linear source chain that looks like this
        // G---A
        Header memory a = make_child(genesis);

        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(a);

        // Now we try to validate a state claim using the stubbed logic
        StateClaim memory claim = StateClaim({
            key: 123,
            value: 456
        });

        assert(bridge.verify_state{value: verify_fee}(claim, genesis_hash, 0, MerkleProof({verifies: true})));
    }

    function testStateVerificationFail() public {
        // We start by creating a linear source chain that looks like this
        // G---A
        Header memory a = make_child(genesis);

        vm.prank(player);
        bridge.submit_new_header{value: relay_fee}(a);

        // Now we try to validate a state claim using the stubbed logic
        StateClaim memory claim = StateClaim({
            key: 123,
            value: 456
        });

        assert(!bridge.verify_state{value: verify_fee}(claim, genesis_hash, 0, MerkleProof({verifies: false})));
    }
}
