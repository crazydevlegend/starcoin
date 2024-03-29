address 0x1 {
/// Each address that holds a `SharedEd25519PublicKey` resource can rotate the public key stored in
/// this resource, but the account's authentication key will be updated in lockstep. This ensures
/// that the two keys always stay in sync.
module SharedEd25519PublicKey {
    use 0x1::Authenticator;
    use 0x1::Account;
    use 0x1::Signature;
    use 0x1::Signer;
    use 0x1::Errors;

    spec module {
        pragma verify;
        pragma aborts_if_is_strict;
    }

    /// A resource that forces the account associated with `rotation_cap` to use a ed25519
    /// authentication key derived from `key`
    struct SharedEd25519PublicKey has key {
        /// 32 byte ed25519 public key
        key: vector<u8>,
        /// rotation capability for an account whose authentication key is always derived from `key`
        rotation_cap: Account::KeyRotationCapability,
    }

    const EMALFORMED_PUBLIC_KEY: u64 = 101;

    /// (1) Rotate the authentication key of the sender to `key`
    /// (2) Publish a resource containing a 32-byte ed25519 public key and the rotation capability
    ///     of the sender under the `account`'s address.
    /// Aborts if the sender already has a `SharedEd25519PublicKey` resource.
    /// Aborts if the length of `new_public_key` is not 32.
    public fun publish(account: &signer, key: vector<u8>) {
        let t = SharedEd25519PublicKey {
            key: x"",
            rotation_cap: Account::extract_key_rotation_capability(account)
        };
        rotate_key_(&mut t, key);
        move_to(account, t);
    }

    spec publish {
        aborts_if !exists<Account::Account>(Signer::spec_address_of(account));
        aborts_if 0x1::Option::is_none(global<Account::Account>(Signer::spec_address_of(account)).key_rotation_capability);
        aborts_if !exists<Account::Account>(
                  0x1::Option::borrow<Account::KeyRotationCapability>(
                      global<Account::Account>(Signer::spec_address_of(account))
                      .key_rotation_capability
                  ).account_address);
        aborts_if !Signature::ed25519_validate_pubkey(key);
        aborts_if exists<SharedEd25519PublicKey>(Signer::spec_address_of(account));
        aborts_if len(Authenticator::spec_ed25519_authentication_key(key)) != 32;
    }

    fun rotate_key_(shared_key: &mut SharedEd25519PublicKey, new_public_key: vector<u8>) {
        // Cryptographic check of public key validity
        assert(
            Signature::ed25519_validate_pubkey(copy new_public_key),
            Errors::invalid_argument(EMALFORMED_PUBLIC_KEY)
        );
        Account::rotate_authentication_key_with_capability(
            &shared_key.rotation_cap,
            Authenticator::ed25519_authentication_key(copy new_public_key)
        );
        shared_key.key = new_public_key;
    }

    spec rotate_key_ {
        aborts_if !exists<Account::Account>(shared_key.rotation_cap.account_address);
        aborts_if !Signature::ed25519_validate_pubkey(new_public_key);
        aborts_if len(Authenticator::spec_ed25519_authentication_key(new_public_key)) != 32;
    }

    /// (1) rotate the public key stored `account`'s `SharedEd25519PublicKey` resource to
    /// `new_public_key`
    /// (2) rotate the authentication key using the capability stored in the `account`'s
    /// `SharedEd25519PublicKey` to a new value derived from `new_public_key`
    /// Aborts if the sender does not have a `SharedEd25519PublicKey` resource.
    /// Aborts if the length of `new_public_key` is not 32.
    public fun rotate_key(account: &signer, new_public_key: vector<u8>) acquires SharedEd25519PublicKey {
        rotate_key_(borrow_global_mut<SharedEd25519PublicKey>(Signer::address_of(account)), new_public_key);
    }

    spec rotate_key {
        aborts_if !exists<SharedEd25519PublicKey>(Signer::address_of(account));
        aborts_if !exists<Account::Account>(global<SharedEd25519PublicKey>(Signer::address_of(account)).rotation_cap.account_address);
        aborts_if !Signature::ed25519_validate_pubkey(new_public_key);
        aborts_if len(Authenticator::spec_ed25519_authentication_key(new_public_key)) != 32;
    }

    /// Return the public key stored under `addr`.
    /// Aborts if `addr` does not hold a `SharedEd25519PublicKey` resource.
    public fun key(addr: address): vector<u8> acquires SharedEd25519PublicKey {
        *&borrow_global<SharedEd25519PublicKey>(addr).key
    }

    spec key {
        aborts_if !exists<SharedEd25519PublicKey>(addr);
    }

    /// Returns true if `addr` holds a `SharedEd25519PublicKey` resource.
    public fun exists_at(addr: address): bool {
        exists<SharedEd25519PublicKey>(addr)
    }

    spec exists_at {
        aborts_if false;
    }
}
}
