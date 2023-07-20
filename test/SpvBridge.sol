// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SpvBridge.sol";

contract SpvBridgeTest is Test {
    SpvBridge public bridge;

    function setUp() public {

        Header memory g = new Header {
            height: 100,
            parent: 0,
            storage_root: 0,
            transactions_root: 0,
            // FIXME: Should the constructor validate
            // the PoW on the checkpoint block?
            pow_nonce: 0
        };

        bridge = new SpvBridge(g, 10_000_000_000);
    }

    function testSubmitExtendLongestChain() public {
        //todo
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