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
    uint256 transactions_root;
    /// The nonce that allows the block's hash to satisfy the proof of work
    uint256 pow_nonce;
}

/// A STUB of a Merkle Proof
///
/// Rather than actually reassembling a partial tree of siblings etc, we just have a simple field
/// indicating whether the proof should be treated as valid or not.
///
/// We stub the proof system because students already built exactly this in assignment 1.
/// For this assignment, there is enough to focus on in the smart contract and blockchain aspects.
struct MerkleProof {
    bool verifies;
}

/// (Stubbed) Verify whether a Merkle proof is valid against the given root.
///
/// You pass in the piece of data that you are claiming is present in the tree,
/// the known good Merkle root, and the Merkle proof.
///
/// This function works for both transaction and state proofs.
/// For transactions, just pass the tx hash directly
/// For state claims, pass the keccak hash of the encoded claim
function check_merkle_proof(
    uint256 claim_hash,
    MerkleProof memory proof,
    uint256 merkle_root
) pure returns (bool) {
    // This is where the actual merkle proof checking logic _would_ go
    // if we weren't stubbing the proofs. Instead this stub is given.
    // We mention the variable to silence the unused variable warning.
    claim_hash;
    merkle_root;
    return proof.verifies;
}

/// A claim that something exists in storage on the source chain.
/// Such claims can be verified against the source chain through the verify_state function.
///
/// We model the source chain storage as a key value mapping, like most blockchains.
/// An instance of this struct would claim that a particular key holds a particular value.
///
/// For assignment purposes, the storage model doesn't matter so much because we stub the proofs.
/// Nonethless, we give a somewhat realistic model.
struct StateClaim {
    uint256 key;
    uint256 value;
}

/// An on-chain light client (or SPV client) for a foreign source chain.
///
/// This contract, inspired by btc-relay, allows users to submit new block headers
/// from a foreign PoW blockchain for validation. It then allows (potentially different)
/// users to verify claims about what transactions and state exist on the source chain.
contract SpvBridge {
    /// The main source chain header database.
    /// Maps header hashes to complete headers.
    mapping(uint256 => Header) public headers;

    /// A representation of the canonical source chain.
    /// Maps block heights to the canonical source block hash at that height.
    /// Updates when a re-org happens
    mapping(uint256 => uint256) public canon_chain;

    /// The user who submitted each block hash.
    /// Fees paid by verifiers will go to this address.
    mapping(uint256 => address) public fee_recipient;

    /// The height of the current best known source chain
    uint256 public best_height;

    /// The difficulty threshold for the PoW
    uint256 public difficulty_threshold;

    /// The fee the relayer must pay in order to relay a block on top
    /// of any protocol level gas fees
    uint256 public relay_fee;

    /// The fee the verifier must pay in order to verify that their
    /// transaction or state claim is canonical on the source chain.
    uint256 public verify_fee;

    /// Initialize the on-chain light client with a "checkpoint" header.
    ///
    /// In many cases, the source chain is older than the target chain, and may have a long
    /// history. We allow starting from a recent point in the source chain and verifying
    /// thereafter.
    ///
    /// This constructor allows the contract deployer to specifiy the recent block from which to start
    constructor(
        Header memory source_genesis_header,
        uint256 difficulty,
        uint256 init_relay_fee,
        uint256 init_verify_fee
    ) {
        // Store the simple global params
        difficulty_threshold = difficulty;
        relay_fee = init_relay_fee;
        verify_fee = init_verify_fee;

        // Calculate header hash and put header in storage
        uint256 h = hash_header(source_genesis_header);
        headers[h] = source_genesis_header;

        // Update other storages
        best_height = source_genesis_header.height;
        canon_chain[best_height] = h;

        // Record the deployer as the fee recipient for the checkpoint block
        fee_recipient[h] = msg.sender;
    }

    /// Someone has successfully submitted a source chain header.
    event HeaderSubmitted(
        uint256 block_hash,
        uint256 block_height,
        address submitter
    );

    /// Helper function to hash a block header.
    /// It would be pretty reasonable to just put this inline.
    /// But we provide it to help avoid bit-level errors from hashing diferently.
    function hash_header(Header memory header) public pure returns (uint256) {
        return uint(keccak256(abi.encode(header)));
    }

    /// Submit a new source chain block header to the bridge for verification.
    /// In order for the new header to be valid, these conditions must be met:
    /// 0. The relayer must pay the relay fee (which will be locked forever).
    /// 1. The header must not already be in the db
    /// 2. The header's parent must already be in the db
    /// 3. The header's height must be one more than it's parent
    /// 4. The header's hash must satisfy the PoW threshold
    ///
    /// Once the block is validated you must determine whether this causes
    /// a re-org or not, and update storage accordingly.
    ///
    /// The relay fee does not go to anyone. It is locked up forever; effectively burnt.
    function submit_new_header(Header calldata header) external payable {
        require(msg.value >= relay_fee, "insufficient relay fee");
        
        uint256 header_hash = hash_header(header);

        // Check if the block itself is already known.
        require(!header_is_known(header_hash), "header already submitted");

        // Check if the parent is in the database and if not revert.
        require(header_is_known(header.parent), "unknown parent");
        Header memory parent_header = headers[header.parent];

        // Verify the height increases by 1
        require(parent_header.height + 1 == header.height, "incorrect height");

        // Verify the PoW
        require(header_hash < difficulty_threshold, "PoW threshold not met");
        
        // Add the new header to the database
        // and the fee recipient to the database
        headers[header_hash] = header;
        fee_recipient[header_hash] = msg.sender;

        // It is possible that this new header caused a source chain re-org
        // which we need to handle here. Rather than determine whether a re-org
        // happened at all, we will just check whether this gives us a new longest chain
        if (header.height > best_height) {
            best_height = header.height;
            canon_chain[header.height] = header_hash;

            // Any time we have a new longest chain, we run the re-org algo.
            // In the case where it is actually just extending the already-longest chain
            // we will take zero iterations through this loop.
            uint256 ancestor_hash = header.parent;
            while (!header_is_canon(ancestor_hash)) {
                // Look up the actual ancestor header
                Header storage ancestor = headers[ancestor_hash];

                // Make it canon
                canon_chain[ancestor.height] = ancestor_hash;

                // Get ready for the next iteration
                ancestor_hash = ancestor.parent;
            }
        }

        // Emit event
        emit HeaderSubmitted(header_hash, header.height, msg.sender);
    }

    /// A helper function to detect whether a header exists in the storage
    function header_is_known(uint256 header_hash) public view returns (bool) {
        Header storage header = headers[header_hash];

        // Verify that it is not the all zero header
        return 
            header.height != 0 ||
            header.parent != 0 ||
            header.storage_root != 0 ||
            header.transactions_root !=0 ||
            header.pow_nonce != 0;
    }

    /// A helper unction to determine whether a header is in the canon chain
    function header_is_canon(uint256 header_hash) public view returns (bool) {
        Header storage header = headers[header_hash];

        // Use the header's height to check whether it exists in the cannon chain storage
        return header_is_known(header_hash) && canon_chain[header.height] == header_hash;
    }

    /// Verify that some transaction has occurred on the source chain.
    ///
    /// In order for a verification to be successful (to return true), these conditions must be met:
    /// 0. The verifier must pay the verification fee (which will go to the relayer).
    /// 1. The block is in the db
    /// 2. The block is in the best chain
    /// 3. The block's height in the best chain is at least `min_depth` before the tip of the chain.
    ///    A min_depth of 0 just means that the header is canon at all.
    ///    A min_depth of 1 means there is at least one block confirmation afterward.
    /// 4. The merkle proof must be valid
    function verify_transaction(
        uint256 tx_hash,
        uint256 header_hash,
        uint256 min_depth,
        MerkleProof calldata p
    ) external payable returns (bool) {
        require(msg.value >= verify_fee, "insufficient verification fee");

        Header storage header = headers[header_hash];
        if (
            !header_is_canon(header_hash) ||
            best_height - header.height < min_depth ||
            !check_merkle_proof(tx_hash, p, header.transactions_root)
        ) {
            return false;
        }

        // Transfer the payment to the relayer.
        payable(fee_recipient[header_hash]).transfer(verify_fee);

        return true;
    }

    /// Verify that some state exists on the source chain.
    ///
    /// The checks performed are the same as when verifying a transaction.
    /// However, in this chase, you pass the hash of the state claim
    function verify_state(
        StateClaim memory claim,
        uint256 header_hash,
        uint256 min_depth,
        MerkleProof calldata p
    ) external payable returns (bool) {
        require(msg.value >= verify_fee, "insufficient verification fee");

        uint256 claim_hash = uint(keccak256(abi.encode(claim)));

        Header storage header = headers[header_hash];
        if (
            !header_is_canon(header_hash) ||
            best_height - header.height < min_depth ||
            !check_merkle_proof(claim_hash, p, header.transactions_root)
        ) {
            return false;
        }

        // Transfer the payment to the relayer.
        payable(fee_recipient[header_hash]).transfer(verify_fee);

        return true;
    }

    /// This function is not graded. It is just for collecting feedback.
    /// On a scale from 0 - 100, with zero being extremely easy and 100 being extremely hard, how hard
    /// did you find the exercises in this section?
    function how_hard_was_this_section() public pure returns (uint256) {
        //TODO
    }

    /// This function is not graded. It is just for collecting feedback.
    /// About how much time (in minutes) did you spend on the exercises in this section?
    function how_many_minutes_did_you_spend_on_this_section()
        public
        pure
        returns (uint256)
    {
        //TODO
    }
}
