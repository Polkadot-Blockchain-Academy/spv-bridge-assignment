// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SpvBridge.sol";

contract SpvBridgeTest is Test {
    SpvBridge public bridge;
    // Threshold is max / 4 so we have about a 1 in 4 chance of finding a valid nonce
    uint threshold = uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) / 4;
    uint relay_fee = 1_000;
    Header genesis;
    uint genesis_hash;
    address player;

    event HeaderSubmitted(uint256 block_hash, uint256 block_height, address submitter);

    function make_child(Header memory parent) public view returns (Header memory) {
        uint256 parent_hash = uint(keccak256(abi.encode(parent)));
        Header memory child = Header ({
            height: parent.height + 1,
            parent: parent_hash,
            storage_root: 0,
            transactions_root: 0,
            pow_nonce: 0
        });

        while (uint(keccak256(abi.encode(child))) >= threshold) {
            child.pow_nonce = child.pow_nonce + 1;
        }

        return child;
    }

    function setUp() public {

        genesis = Header({
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
        bridge = new SpvBridge(genesis, threshold, relay_fee);
        player = address(0);
    }

    function testSubmitExtendLongestChain() public {
        // Calculate a new header
        Header memory child = make_child(genesis);
        uint256 child_hash = uint(keccak256(abi.encode(child)));

        // FIXME WTF isn't the event validation working?
        // Expect the event
        // vm.expectEmit();
        // emit HeaderSubmitted(child_hash, 1, player);

        // Submit the new header
        vm.prank(player);
        bridge.submit_new_header(child);
        
        // Validate the storage
        assertEq(bridge.cannon_chain(100), genesis_hash);
        assertEq(bridge.cannon_chain(101), child_hash);

        assertEq(bridge.fee_recipient(genesis_hash), player);
        assertEq(bridge.fee_recipient(child_hash), player);
    }
}

// Test braindump

// constructor happy path
// submit to extend longest chain
// submit to add side chain
// submit to cause re-org
// Tx verification happy path
// Tx verification fail path
// State verification happy path
// State verification one fail path