// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "./BridgeInterface.sol";

contract JoshyBridge is Bridge {

    /// The main source chain header database.
    /// Maps header hashes to complete headers.
    mapping(uint256 => Header) headers;

    /// The tip of the current best known source chain
    uint256 best_hash;


    function best_header() public view returns (Header memory) {
        return headers[best_hash];
    }

    function best_header_at_height(uint256 height) external view returns (Header memory) {
        // This is an O(n) solution. We start at the best block and walk backwards until we find the
        // desired height. It may be better to have an additional storage that maps heights to canonical blocks.
        uint256 cur_hash = best_hash;
        uint256 cur_height = best_header().height;

        while (cur_height > height) {
            cur_height -= 1;
            cur_hash = headers[cur_hash].parent;
        }

        return headers[cur_hash];
    }

    function submit_new_header(Header calldata h) external {

    }

    function verify_state_inclusion(uint256 hash, uint256 depth, MerkleProof calldata p) external view returns (bool){

    }
}
