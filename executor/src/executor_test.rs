// Copyright (c) The Starcoin Core Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::{
    executor::{mock_txn, Executor},
    mock_executor::{
        get_signed_txn, MockChainState, MockExecutor,
    },
    TransactionExecutor,
};
use config::VMConfig;
use crypto::ed25519::compat;
use logger::prelude::*;
use types::{
    access_path::AccessPath,
    account_address::{AccountAddress, ADDRESS_LENGTH},
    transaction::{SignedUserTransaction, Transaction},
};
use vm_runtime::{
    account::AccountData,
    mock_vm::{encode_mint_transaction, encode_transfer_program, encode_transfer_transaction,
              DISCARD_STATUS, KEEP_STATUS,
    }

};
use std::time::Duration;
use std::convert::TryInto;
use std::sync::Arc;
use state_tree::mock::MockStateNodeStore;
use statedb::ChainStateDB;

fn gen_address(index: u8) -> AccountAddress {
    AccountAddress::new([index; ADDRESS_LENGTH])
}


#[stest::test]
fn test_execute_mint_txn() {
    let storage = MockStateNodeStore::new();
    let chain_state = ChainStateDB::new(Arc::new(storage), None);
    let mut executor = MockExecutor::new();
    let account_address = AccountAddress::random();
    executor.create_account(account_address, &chain_state);
    info!("create account: {:?}", account_address);
    let txn = encode_mint_transaction(account_address, 100);
    let config = VMConfig::default();
    info!("invoke Executor::execute_transaction");
    let output = MockExecutor::execute_transaction(&config, &chain_state, txn).unwrap();

    assert_eq!(KEEP_STATUS.clone(), *output.status());
}

#[stest::test]
fn test_execute_transfer_txn() {
    let storage = MockStateNodeStore::new();
    let chain_state = ChainStateDB::new(Arc::new(storage), None);
    let mut executor = MockExecutor::new();
    let sender_account_address = AccountAddress::random();
    let receiver_account_address = AccountAddress::random();
    executor.create_account(sender_account_address, &chain_state);
    executor.create_account(receiver_account_address, &chain_state);
    info!("create account: sender: {:?}, receiver: {:?}", sender_account_address, receiver_account_address);
    let mint_txn = encode_mint_transaction(sender_account_address, 10000);
    let transfer_txn = encode_transfer_transaction(sender_account_address, receiver_account_address, 100);
    let config = VMConfig::default();
    info!("invoke Executor::execute_transaction");
    let output1 = MockExecutor::execute_transaction(&config, &chain_state, mint_txn).unwrap();
    let output2 = MockExecutor::execute_transaction(&config, &chain_state, transfer_txn).unwrap();

    assert_eq!(KEEP_STATUS.clone(), *output1.status());
    assert_eq!(KEEP_STATUS.clone(), *output2.status());
}

#[stest::test]
fn test_validate_txn() {
    let chain_state = MockChainState::new();
    let txn = encode_mint_transaction(gen_address(0), 100);
    let config = VMConfig::default();

    let (private_key, public_key) = compat::generate_keypair(None);

    let receiver = gen_address(1);
    let program = encode_transfer_program(receiver, 100);
    let txn = get_signed_txn(receiver, 1, &private_key, public_key, program);

    let output = MockExecutor::validate_transaction(&config, &chain_state, txn);

    assert_eq!(None, output);
}

#[stest::test]
fn test_execute_txn_with_starcoin_vm() {
    let chain_state = MockChainState::new();
    //let txn = encode_mint_transaction(gen_address(0), 100);
    let txn = mock_txn();
    let config = VMConfig::default();
    info!("invoke Executor::execute_transaction");
    let output = Executor::execute_transaction(&config, &chain_state, txn).unwrap();

    assert_eq!(KEEP_STATUS.clone(), *output.status());
}

