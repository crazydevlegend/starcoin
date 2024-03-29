
address 0x1 {
/// Move representation of the authenticator types
/// - Ed25519 (single-sig)
/// - MultiEd25519 (K-of-N multisig)
module Authenticator {
    use 0x1::Hash;
    use 0x1::BCS;
    use 0x1::Vector;
    use 0x1::Errors;

    spec module {
        pragma verify;
        pragma aborts_if_is_strict;
    }

    const AUTHENTICATION_KEY_LENGTH: u64 = 32;

    const ED25519_SCHEME_ID: u8 = 0;
    const MULTI_ED25519_SCHEME_ID: u8 = 1;

    /// A multi-ed25519 public key
    struct MultiEd25519PublicKey has copy, drop, store {
        /// vector of ed25519 public keys
        public_keys: vector<vector<u8>>,
        /// approval threshold
        threshold: u8,
    }

    /// Maximum number of keys allowed in a MultiEd25519 public/private key
    const MAX_MULTI_ED25519_KEYS: u64 = 32;

    const EWRONG_AUTHENTICATION_KEY_LENGTH: u64 = 101;
    /// Threshold provided was 0 which can't be used to create a `MultiEd25519` key
    const EZERO_THRESHOLD: u64 = 102;
    /// Not enough keys were provided for the specified threshold when creating an `MultiEd25519` key
    const ENOT_ENOUGH_KEYS_FOR_THRESHOLD: u64 = 103;
    /// Too many keys were provided for the specified threshold when creating an `MultiEd25519` key
    const ENUM_KEYS_ABOVE_MAX_THRESHOLD: u64 = 104;

    /// Create a a multisig policy from a vector of ed25519 public keys and a threshold.
    /// Note: this does *not* check uniqueness of keys. Repeated keys are convenient to
    /// encode weighted multisig policies. For example Alice AND 1 of Bob or Carol is
    /// public_key: {alice_key, alice_key, bob_key, carol_key}, threshold: 3
    /// Aborts if threshold is zero or bigger than the length of `public_keys`.
    public fun create_multi_ed25519(
        public_keys: vector<vector<u8>>,
        threshold: u8
    ): MultiEd25519PublicKey {
        // check threshold requirements
        let len = Vector::length(&public_keys);
        assert(threshold != 0, Errors::invalid_argument(EZERO_THRESHOLD));
        assert(
            (threshold as u64) <= len,
            Errors::invalid_argument(ENOT_ENOUGH_KEYS_FOR_THRESHOLD)
        );
        // the multied25519 signature scheme allows at most 32 keys
        assert(
            len <= MAX_MULTI_ED25519_KEYS,
            Errors::invalid_argument(ENUM_KEYS_ABOVE_MAX_THRESHOLD)
        );

        MultiEd25519PublicKey { public_keys, threshold }
    }

    spec create_multi_ed25519 {
        aborts_if threshold == 0;
        aborts_if threshold > Vector::length(public_keys);
        aborts_if Vector::length(public_keys) > 32;
    }

    /// Compute an authentication key for the ed25519 public key `public_key`
    public fun ed25519_authentication_key(public_key: vector<u8>): vector<u8> {
        Vector::push_back(&mut public_key, ED25519_SCHEME_ID);
        Hash::sha3_256(public_key)
    }

    spec ed25519_authentication_key {
        pragma opaque = true;
        aborts_if false;
        ensures [abstract] result == spec_ed25519_authentication_key(public_key);
    }

    /// We use an uninterpreted function to represent the result of key construction. The actual value
    /// does not matter for the verification of callers.
    spec fun spec_ed25519_authentication_key(public_key: vector<u8>): vector<u8>;

    /// convert authentication key to address
    public fun derived_address(authentication_key: vector<u8>): address {
        assert(Vector::length(&authentication_key) == AUTHENTICATION_KEY_LENGTH, Errors::invalid_argument(EWRONG_AUTHENTICATION_KEY_LENGTH));
        let address_bytes = Vector::empty<u8>();

        let i = 16;
        while (i < 32) {
            let b = *Vector::borrow(&authentication_key, i);
            Vector::push_back(&mut address_bytes, b);
            i = i + 1;
        };

        BCS::to_address(address_bytes)
    }

    spec derived_address {
        pragma opaque = true;
        aborts_if len(authentication_key) != 32;
        ensures [abstract] result == spec_derived_address(authentication_key);
    }

    /// We use an uninterpreted function to represent the result of derived address. The actual value
    /// does not matter for the verification of callers.
    spec fun spec_derived_address(authentication_key: vector<u8>): address;

    /// Compute a multied25519 account authentication key for the policy `k`
    public fun multi_ed25519_authentication_key(k: &MultiEd25519PublicKey): vector<u8> {
        let public_keys = &k.public_keys;
        let len = Vector::length(public_keys);
        let authentication_key_preimage = Vector::empty();
        let i = 0;
        while (i < len) {
            let public_key = *Vector::borrow(public_keys, i);
            Vector::append(
                &mut authentication_key_preimage,
                public_key
            );
            i = i + 1;
        };
        Vector::append(&mut authentication_key_preimage, BCS::to_bytes(&k.threshold));
        Vector::push_back(&mut authentication_key_preimage, MULTI_ED25519_SCHEME_ID);
        Hash::sha3_256(authentication_key_preimage)
    }

    spec multi_ed25519_authentication_key {
        aborts_if false;
    }

    /// Return the public keys involved in the multisig policy `k`
    public fun public_keys(k: &MultiEd25519PublicKey): &vector<vector<u8>> {
        &k.public_keys
    }

    spec public_keys {
        aborts_if false;
    }

    /// Return the threshold for the multisig policy `k`
    public fun threshold(k: &MultiEd25519PublicKey): u8 {
        *&k.threshold
    }

    spec threshold {
        aborts_if false;
    }

}
}
