#![cfg_attr(not(feature = "std"), no_std, no_main)]

#[ink::contract]
mod spv_bridge {
    use ink::storage::Mapping;
    use ink::env::hash::{Sha2x256, HashOutput};

    pub type HashValue = [u8; 32];

    /// A block header from the source chain.
    #[derive(Debug, Copy, Clone, PartialEq, Eq, scale::Decode, scale::Encode)]
    #[cfg_attr(
        feature = "std",
        derive(ink::storage::traits::StorageLayout, scale_info::TypeInfo)
    )]
    pub struct Header {
        /// The height of this block in the chain
        height: u64,
        /// The hash of this block's parent
        parent: HashValue,
        /// The merkle tree root of the storage
        storage_root: u64,
        /// The merkle tree root of the transactions included in the block
        transactions_root: u64,
        /// The nonce that allows the block's hash to satisfy the proof of work
        pow_nonce: u64,
    }

    /// A STUB of a Merkle Proof
    ///
    /// Rather than actually reassembling a partial tree of siblings etc, we just have a simple field
    /// indicating whether the proof should be treated as valid or not.
    ///
    /// We stub the proof system because students already built exactly this in assignment 1.
    /// For this assignment, there is enough to focus on in the smart contract and blockchain aspects.
    #[derive(Debug, Copy, Clone, PartialEq, Eq, scale::Decode, scale::Encode)]
    #[cfg_attr(
        feature = "std",
        derive(ink::storage::traits::StorageLayout, scale_info::TypeInfo)
    )]
    pub struct MerkleProof {
        verifies: bool,
    }

    impl MerkleProof {
        pub fn check_merkle_proof(_claim: Hash, proof: MerkleProof, _merkle_root: Hash) -> bool {
            // This is where the actual merkle proof checking logic _would_ go
            // if we weren't stubbing the proofs. Instead this stub is given.
            proof.verifies
        }
    }

    /// A claim that something exists in storage on the source chain.
    /// Such claims can be verified against the source chain through the verify_state function.
    ///
    /// We model the source chain storage as a key value mapping, like most blockchains.
    /// An instance of this struct would claim that a particular key holds a particular value.
    ///
    /// For assignment purposes, the storage model doesn't matter so much because we stub the proofs.
    /// Nonethless, we give a somewhat realistic model.
    #[derive(Debug, Copy, Clone, PartialEq, Eq, scale::Decode, scale::Encode)]
    #[cfg_attr(
        feature = "std",
        derive(ink::storage::traits::StorageLayout, scale_info::TypeInfo)
    )]
    pub struct StateClaim {
        key: u64,
        value: u64,
    }


    #[ink(storage)]
    pub struct SpvBridge {
        /// The main source chain header database.
        /// Maps header hashes to complete headers.
        headers: Mapping<HashValue, Header>,

        /// A representation of the canonical source chain.
        /// Maps block heights to the canonical source block hash at that height.
        /// Updates when a re-org happens
        canon_chain: Mapping<u64, HashValue>,

        /// The user who submitted each block hash.
        /// Fees paid by verifiers will go to this address.
        fee_recipient: Mapping<HashValue, AccountId>,

        /// The height of the current best known source chain
        best_height: u64,

        /// The difficulty threshold for the PoW
        difficulty_threshold: HashValue,

        /// The fee the relayer must pay in order to relay a block on top
        /// of any protocol level gas fees
        relay_fee: Balance,

        /// The fee the verifier must pay in order to verify that their
        /// transaction or state claim is canonical on the source chain.
        verify_fee: Balance,

    }

    /// Errors that can occur upon calling this contract.
    #[derive(Debug, PartialEq, Eq, scale::Encode, scale::Decode)]
    #[cfg_attr(feature = "std", derive(::scale_info::TypeInfo))]
    pub enum Error {
        /// Insufficent relay fee
        InsufficientRelayFee,
        /// Block is already known
        HeaderAlreadySubmitted,
        /// Parent is not in the DB
        UnknownParent,
        /// Header height is invalid
        IncorrectHeight,
        /// PoW threshold has not been met
        PoWThresholdNotMet
    }

    /// Type alias for the contract's `Result` type.
    pub type Result<T> = core::result::Result<T, Error>;

    /// Someone has successfully submitted a source chain header.
    #[ink(event)]
    pub struct HeaderSubmitted {
        block_hash: HashValue,
        block_height: u64,
        #[ink(topic)]
        submitter: AccountId
    }

    /// An on-chain light client (or SPV client) for a foreign source chain.
    ///
    /// This contract, inspired by btc-relay, allows users to submit new block headers
    /// from a foreign PoW blockchain for validation. It then allows (potentially different)
    /// users to verify claims about what transactions and state exist on the source chain.
    impl SpvBridge {
        /// Initialize the on-chain light client with a "checkpoint" header.
        ///
        /// In many cases, the source chain is older than the target chain, and may have a long
        /// history. We allow starting from a recent point in the source chain and verifying
        /// thereafter.
        ///
        /// This constructor allows the contract deployer to specifiy the recent block from which to start
        #[ink(constructor)]
        pub fn new(source_genesis_header: Header, difficulty: HashValue, init_relay_fee: Balance, init_verify_fee: Balance) -> Self {
            let caller = Self::env().caller();

            let mut headers = Mapping::default();
            let mut canon_chain = Mapping::default();
            let mut fee_recipient = Mapping::default();

            let difficulty_threshold = difficulty;
            let relay_fee = init_relay_fee;
            let verify_fee = init_verify_fee;

            // Calculate header hash and put header in storage
            let h = Self::hash_header(source_genesis_header);
            headers.insert(h, &source_genesis_header);
            
             // Update other storages
            let best_height = source_genesis_header.height;
            canon_chain.insert(best_height, &h);

            // Record the deployer as the fee recipient for the checkpoint block
            fee_recipient.insert(h, &caller);

            Self {
                headers,
                canon_chain,
                fee_recipient,
                best_height,
                difficulty_threshold,
                relay_fee,
                verify_fee
            }
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
        #[ink(message, payable)]
        pub fn submit_new_header(&mut self, header: Header) -> Result<()> {
            todo!()
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
        #[ink(message, payable)]
        pub fn verify_transaction(&mut self, tx_hash: HashValue, header_hash: HashValue, min_depth: u64, p: MerkleProof) -> bool {
            todo!()
        }

        /// Verify that some state exists on the source chain.
        ///
        /// The checks performed are the same as when verifying a transaction.
        /// However, in this chase, you pass the hash of the state claim
        #[ink(message, payable)]
        pub fn verify_state(&mut self, claim: StateClaim, block_hash: HashValue, min_depth: u64, p: MerkleProof) -> bool {
            let mut claim_hash = <Sha2x256 as HashOutput>::Type::default();
            ink::env::hash_encoded::<Sha2x256, _>(&claim, &mut claim_hash);
            
            todo!()
        }

        /// Helper function to hash a block header.
        /// It would be pretty reasonable to just put this inline.
        /// But we provide it to help avoid bit-level errors from hashing differently.
        pub fn hash_header(header: Header) -> HashValue {
            let mut hash_value = <Sha2x256 as HashOutput>::Type::default();
            ink::env::hash_encoded::<Sha2x256, _>(&header, &mut hash_value);
            hash_value
        }

        /// A helper function to detect whether a header exists in the storage
        pub fn  header_is_known(header_hash: HashValue) -> bool {
            todo!()
        }

        /// A helper unction to determine whether a header is in the canon chain
        pub fn header_is_canon(header_hash: HashValue) -> bool {
            todo!()
        }

        /// This function is not graded. It is just for collecting feedback.
        /// On a scale from 0 - 100, with zero being extremely easy and 100 being extremely hard, how hard
        /// did you find the exercises in this section?
        pub fn how_hard_was_this_section() -> u8 {
            todo!()
        }

        /// This function is not graded. It is just for collecting feedback.
        /// About how much time (in hours) did you spend on the exercises in this section?
        pub fn how_many_hours_did_you_spend_on_this_section() -> f32 {
            todo!()
        }
    }


    #[cfg(test)]
    mod tests {
        // The threshold is set so that we have roughly 1 in 4 chance of finding a valid block.
        const THRESHOLD: [u8; 32] = [63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        const RELAY_FEE: u128 = 1_000;
        const VERIFY_FEE: u128 = 100;

        use super::*;

        fn default_accounts(
        ) -> ink::env::test::DefaultAccounts<ink::env::DefaultEnvironment> {
            ink::env::test::default_accounts::<Environment>()
        }

        fn set_next_caller(caller: AccountId) {
            ink::env::test::set_caller::<Environment>(caller);
        }


        fn make_child(parent: Header) -> Header {
            make_child_with_transactions_root(parent, 0)
        }

        fn make_child_with_transactions_root(parent: Header, tx_root: u64) -> Header {
            let mut child = Header {
                height: parent.height + 1,
                parent: SpvBridge::hash_header(parent),
                storage_root: 0,
                transactions_root: tx_root,
                pow_nonce: 1
            };

            while SpvBridge::hash_header(child) >= THRESHOLD {
                child.pow_nonce = child.pow_nonce + 1;
            }

            child
        }

        pub fn deploy_bridge(deployer: AccountId) -> (SpvBridge, Header) {
            set_next_caller(deployer);

            let source_genesis_header =  Header {
                height: 100,
                parent: [0; 32],
                storage_root: 0,
                transactions_root: 0,
                // The initial block is not checked; not even its pow seal;
                // We put a non-zero nonce here to make sure this block
                // isn't the default block.
                pow_nonce: 1
            };
            let spv_bridge = SpvBridge::new(source_genesis_header, THRESHOLD, RELAY_FEE, VERIFY_FEE);

            let hash_value = SpvBridge::hash_header(source_genesis_header);
            
            (spv_bridge, source_genesis_header)
        }

        #[ink::test]
        fn test_constructor_works() {
            let default_accounts = default_accounts();
            set_next_caller(default_accounts.alice);

            let (spv_bridge, genesis_header) = deploy_bridge(default_accounts.alice);
            let genesis_hash = SpvBridge::hash_header(genesis_header);
            assert_eq!(spv_bridge.fee_recipient.get(genesis_hash), Some(default_accounts.alice));
        }

        #[ink::test]
        fn test_submit_extend_longest_chain() {
            let default_accounts = default_accounts();
            set_next_caller(default_accounts.alice);

            let (mut bridge, genesis_header) = deploy_bridge(default_accounts.alice);
            let genesis_hash = SpvBridge::hash_header(genesis_header);
            let child_header = make_child(genesis_header);
            let child_hash = SpvBridge::hash_header(child_header);

            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(child_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));

            // Validate Storage
            assert_eq!(bridge.canon_chain.get(100), Some(genesis_hash));
            assert_eq!(bridge.canon_chain.get(101), Some(child_hash));

            assert_eq!(bridge.fee_recipient.get(genesis_hash), Some(default_accounts.alice));
            assert_eq!(bridge.fee_recipient.get(child_hash), Some(default_accounts.alice));

        }

        #[ink::test]
        fn test_submit_side_chain() {
            // We start by creating a linear source chain that looks like this
            // G---A---B
            let default_accounts = default_accounts();
            set_next_caller(default_accounts.alice);

            let (mut bridge, genesis_header) = deploy_bridge(default_accounts.alice);
            let genesis_hash = SpvBridge::hash_header(genesis_header);
            let a_header = make_child(genesis_header);
            let a_hash = SpvBridge::hash_header(a_header);
            let b_header = make_child(a_header);
            let b_hash = SpvBridge::hash_header(b_header);

            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(a_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));
            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(b_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));

            // Now we create a fork in the source chain.
            // The fork is not long enough to cause a re-org.
            // We should be able to submit the header successfully, but it should not cause a re-org
            // G---A---B
            //  \
            //   --C

            let c_header = make_child_with_transactions_root(genesis_header, 1);
            let c_hash = SpvBridge::hash_header(c_header);
            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(c_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));


            // Validate Storage
            assert_eq!(bridge.canon_chain.get(100), Some(genesis_hash));
            assert_eq!(bridge.canon_chain.get(101), Some(a_hash));
            assert_eq!(bridge.canon_chain.get(102), Some(b_hash));

            assert_eq!(bridge.fee_recipient.get(genesis_hash), Some(default_accounts.alice));
            assert_eq!(bridge.fee_recipient.get(a_hash), Some(default_accounts.alice));
            assert_eq!(bridge.fee_recipient.get(b_hash), Some(default_accounts.alice));
            assert_eq!(bridge.fee_recipient.get(c_hash), Some(default_accounts.alice));
        }

        #[ink::test]
        fn test_submit_reorg_chain() {
            // We start by creating a linear source chain that looks like this
            // G---A
            let default_accounts = default_accounts();
            set_next_caller(default_accounts.alice);

            let (mut bridge, genesis_header) = deploy_bridge(default_accounts.alice);
            let genesis_hash = SpvBridge::hash_header(genesis_header);
            let a_header = make_child(genesis_header);
            let a_hash = SpvBridge::hash_header(a_header);
            
            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(a_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));
            
            // Now we create a fork in the source chain.
            // The fork is long enough to cause a re-org.
            // G---A
            //  \
            //   --C---D

            let c_header = make_child_with_transactions_root(genesis_header, 1);
            let c_hash = SpvBridge::hash_header(c_header);
            let d_header = make_child_with_transactions_root(c_header, 1);
            let d_hash = SpvBridge::hash_header(d_header);
            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(c_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));
            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(d_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));

            // Validate Storage
            assert_eq!(bridge.canon_chain.get(100), Some(genesis_hash));
            assert_eq!(bridge.canon_chain.get(101), Some(c_hash));
            assert_eq!(bridge.canon_chain.get(102), Some(d_hash));

            assert_eq!(bridge.fee_recipient.get(genesis_hash), Some(default_accounts.alice));
            assert_eq!(bridge.fee_recipient.get(a_hash), Some(default_accounts.alice));
            assert_eq!(bridge.fee_recipient.get(c_hash), Some(default_accounts.alice));
            assert_eq!(bridge.fee_recipient.get(d_hash), Some(default_accounts.alice));
        }

        #[ink::test]
        fn test_tx_verification_success() {
            // We start by creating a linear source chain that looks like this
            // G---A
            let default_accounts = default_accounts();
            set_next_caller(default_accounts.alice);

            let (mut bridge, genesis_header) = deploy_bridge(default_accounts.alice);
            let genesis_hash = SpvBridge::hash_header(genesis_header);
            let a_header = make_child(genesis_header);
            let a_hash = SpvBridge::hash_header(a_header);
            
            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(a_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));

            assert!(
                ink::env::pay_with_call!(
                    bridge.verify_transaction([0u8; 32],genesis_hash, 0, MerkleProof { verifies: true } ),
                    VERIFY_FEE
                )
            );
        }

        #[ink::test]
        fn test_tx_verification_failure() {
            // We start by creating a linear source chain that looks like this
            // G---A
            let default_accounts = default_accounts();
            set_next_caller(default_accounts.alice);

            let (mut bridge, genesis_header) = deploy_bridge(default_accounts.alice);
            let genesis_hash = SpvBridge::hash_header(genesis_header);
            let a_header = make_child(genesis_header);
            let a_hash = SpvBridge::hash_header(a_header);
            
            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(a_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));

            assert_eq!(
                ink::env::pay_with_call!(
                    bridge.verify_transaction([0u8; 32],genesis_hash, 0, MerkleProof { verifies: false } ),
                    VERIFY_FEE
                ),
                false
            );
        }

        //TODO There are many more ways that a transaction or state verification can fail,
        // that we have not yet tested for.
        // You would be wise to add some tests of your own to ensure your code is working as expected.
        
        #[ink::test]
        fn test_state_verification_success() {
            // We start by creating a linear source chain that looks like this
            // G---A
            let default_accounts = default_accounts();
            set_next_caller(default_accounts.alice);

            let (mut bridge, genesis_header) = deploy_bridge(default_accounts.alice);
            let genesis_hash = SpvBridge::hash_header(genesis_header);
            let a_header = make_child(genesis_header);
            let a_hash = SpvBridge::hash_header(a_header);
            
            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(a_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));

            let claim = StateClaim {
                key: 0,
                value: 0,
            };

            assert!(
                ink::env::pay_with_call!(
                    bridge.verify_state(claim, genesis_hash, 0, MerkleProof { verifies: true } ),
                    VERIFY_FEE
                )
            );
        }

        #[ink::test]
        fn test_state_verification_failure() {
            // We start by creating a linear source chain that looks like this
            // G---A
            let default_accounts = default_accounts();
            set_next_caller(default_accounts.alice);

            let (mut bridge, genesis_header) = deploy_bridge(default_accounts.alice);
            let genesis_hash = SpvBridge::hash_header(genesis_header);
            let a_header = make_child(genesis_header);
            let a_hash = SpvBridge::hash_header(a_header);
            
            let relay_response = ink::env::pay_with_call!(bridge.submit_new_header(a_header), RELAY_FEE);
            assert_eq!(relay_response, Ok(()));

            let claim = StateClaim {
                key: 0,
                value: 0,
            };

            assert_eq!(
                ink::env::pay_with_call!(
                    bridge.verify_state(claim, genesis_hash, 0, MerkleProof { verifies: false } ),
                    VERIFY_FEE
                ),
                false
            );
        }
    }

}
