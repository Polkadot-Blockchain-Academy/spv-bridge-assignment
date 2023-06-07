// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "./BridgeInterface.sol";

contract JoshyBridge is Bridge {

    /// The main source chain header database.
    /// Maps header hashes to complete headers.
    mapping(uint256 => Header) headers;

    /// The tip of the current best known source chain
    uint256 best_hash;

    /// The difficulty threshold for the PoW
    uint256 difficulty_threshold = 5000;


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

    /// A helper function to detect whether a header exists in the storage
    function header_is_known(uint256 hash) public view returns (bool) {
        //TODO
    }

    function submit_new_header(Header calldata h) external {
        // Check if the parent is in the database and if not revert.
        require(header_is_known(h.parent));
        Header memory parent_header = headers[h.parent];

        // Verify the height increases by 1
        require(parent_header.height + 1 == h.height);

        // Verify the PoW
        uint256 header_hash = uint(keccak256(abi.encode(h)));
        require(header_hash < difficulty_threshold);
        
        // Add the new header to the database
        headers[header_hash] = h;

        //TODO Emit event
    }

    function verify_state_inclusion(uint256 hash, uint256 depth, MerkleProof calldata p) external view returns (bool){

    }
}
