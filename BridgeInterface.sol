// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

/// A block header from the source chain.
struct Header {
    /// The height of this block in the chain
    uint256 height;
    /// The hash of this block's parent
    uint256 parent;
    /// The merkle tree root of the storage
    uint256 storage_root;
    /// The merkle tree root of the transactions included in the block
    uint256 extrinsics_root;
    /// The nonce that allows the block's hash to satisfy the proof of work
    uint256 pow_nonce;
}


/// A Merkle Proof
/// Design TODO
struct MerkleProof {
    ///TODO
    uint256 a;
}

/// @title The standard interface for an on-chain light client contracts
/// inspired loosely by btc-relay
interface Bridge {

    //TODO some kind of constructor where we supply a cannonical starting hash
    // could also take a constant PoW difficulty on the source chain

    /// @dev Get the latest known source chain block header.
    /// @return A block header
    function best_header() external view returns (Header memory);

    /// @dev Get the source chain block header at the given height in the best chain.
    /// @param height the height of the source chain header to get
    /// @return A block header
    function best_header_at_height(uint256 height) external view returns (Header memory);

    /// @dev Submit a new source chain block header for checking here on hte destination chain
    /// @param h TODO
    function submit_new_header(Header calldata h) external;

    /// @dev Checks a Merkle proof that some given state is included in the source chain.
    /// @param hash the source chain block hash in which the state is expected to be included
    /// @param depth the number of source chain confirmations that are known to have built on the block in question.
    /// @return Whether the proof is valid and the state really is included in the source chain.
    function verify_state_inclusion(uint256 hash, uint256 depth, MerkleProof calldata p) external view returns (bool);
}
