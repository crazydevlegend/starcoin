// Copyright (c) The Libra Core Contributors
// SPDX-License-Identifier: Apache-2.0

//! Support for running the VM to execute and verify transactions.
use crate::account::{Account, AccountData};
use anyhow::Result;
use starcoin_crypto::HashValue;
use starcoin_statedb::{ChainStateDB, ChainStateWriter};
use starcoin_types::{
    access_path::AccessPath,
    block_metadata::BlockMetadata,
    transaction::{SignedUserTransaction, Transaction, TransactionOutput},
    vm_error::VMStatus,
    write_set::WriteSet,
};
use starcoin_vm_runtime::starcoin_vm::StarcoinVM;
use starcoin_vm_types::{
    account_config::{association_address, AccountResource, BalanceResource},
    file_format::CompiledModule,
    identifier::Identifier,
    language_storage::ModuleId,
    state_view::StateView,
};

/// Provides an environment to run a VM instance.
pub struct FakeExecutor {
    data_store: ChainStateDB,
    block_time: u64,
}

impl FakeExecutor {
    /// Creates an executor from a genesis [`WriteSet`].
    pub fn from_genesis(write_set: &WriteSet) -> Self {
        let mut executor = FakeExecutor {
            data_store: ChainStateDB::mock(),
            block_time: 0,
        };
        executor.apply_write_set(write_set);
        executor
    }

    /// Creates an executor in which no genesis state has been applied yet.
    pub fn no_genesis() -> Self {
        FakeExecutor {
            data_store: ChainStateDB::mock(),
            block_time: 0,
        }
    }

    /// Creates a number of [`Account`] instances all with the same balance and sequence number,
    /// and publishes them to this executor's data store.
    pub fn create_accounts(&mut self, size: usize, balance: u64, seq_num: u64) -> Vec<Account> {
        let mut accounts: Vec<Account> = Vec::with_capacity(size);
        for _i in 0..size {
            let account_data = AccountData::new(balance, seq_num);
            self.add_account_data(&account_data);
            accounts.push(account_data.into_account());
        }
        accounts
    }

    /// Applies a [`WriteSet`] to this executor's data store.
    pub fn apply_write_set(&mut self, write_set: &WriteSet) {
        self.data_store
            .apply_write_set(write_set.clone())
            .expect("statedb apply write set should work.");
    }

    /// Adds an account to this executor's data store.
    pub fn add_account_data(&mut self, account_data: &AccountData) {
        let write_set = account_data.to_writeset();
        self.apply_write_set(&write_set)
    }

    /// Adds a module to this executor's data store.
    ///
    /// Does not do any sort of verification on the module.
    pub fn add_module(&mut self, module_id: &ModuleId, module: &CompiledModule) {
        let access_path = AccessPath::from(module_id);
        let mut blob = vec![];
        module
            .serialize(&mut blob)
            .expect("serializing this module should work");
        self.data_store
            .set(&access_path, blob)
            .expect("statedb set should success");
    }

    /// Reads the resource [`Value`] for an account from this executor's data store.
    pub fn read_account_resource(&self, account: &Account) -> Option<AccountResource> {
        let ap = account.make_account_access_path();
        let data_blob = self
            .data_store
            .get(&ap)
            .expect("account must exist in data store")
            .expect("data must exist in data store");
        scs::from_bytes(data_blob.as_slice()).ok()
    }

    /// Reads the balance resource value for an account from this executor's data store.
    pub fn read_balance_resource(&self, account: &Account) -> Option<BalanceResource> {
        Some(self.read_account_info(account)?.1)
    }

    // Reads the balance resource value for an account from this executor's data store with the
    // given balance currency_code.
    fn read_balance_resource_from_currency_code(
        &self,
        account: &Account,
        balance_currency_code: Identifier,
    ) -> Option<BalanceResource> {
        let ap = account.make_balance_access_path(balance_currency_code);
        let data_blob = self
            .data_store
            .get(&ap)
            .expect("account must exist in data store")
            .expect("data must exist in data store");
        scs::from_bytes(data_blob.as_slice()).ok()
    }

    /// Reads the AccountResource and BalanceResource for this account. These are coupled together.
    pub fn read_account_info(
        &self,
        account: &Account,
    ) -> Option<(AccountResource, BalanceResource)> {
        self.read_account_resource(account).and_then(|ar| {
            self.read_balance_resource_from_currency_code(
                account,
                ar.balance_currency_code().to_owned(),
            )
            .map(|br| (ar, br))
        })
    }

    /// Executes the given block of transactions.
    ///
    /// Typical tests will call this method and check that the output matches what was expected.
    /// However, this doesn't apply the results of successful transactions to the data store.
    pub fn execute_block(
        &self,
        txn_block: Vec<SignedUserTransaction>,
    ) -> Result<Vec<TransactionOutput>> {
        self.execute_transaction_block(
            txn_block
                .iter()
                .map(|txn| Transaction::UserTransaction(txn.clone()))
                .collect(),
        )
    }

    pub fn execute_transaction_block(
        &self,
        txn_block: Vec<Transaction>,
    ) -> Result<Vec<TransactionOutput>> {
        let mut vm = StarcoinVM::new();
        vm.execute_transactions(&self.data_store, txn_block)
    }

    pub fn execute_transaction(&self, txn: SignedUserTransaction) -> TransactionOutput {
        let txn_block = vec![txn];
        let mut outputs = self
            .execute_block(txn_block)
            .expect("The VM should not fail to startup");
        outputs
            .pop()
            .expect("A block with one transaction should have one output")
    }

    /// Get the blob for the associated AccessPath
    pub fn read_from_access_path(&self, path: &AccessPath) -> Option<Vec<u8>> {
        StateView::get(&self.data_store, path).unwrap()
    }

    /// Verifies the given transaction by running it through the VM verifier.
    pub fn verify_transaction(&self, txn: SignedUserTransaction) -> Option<VMStatus> {
        let mut vm = StarcoinVM::new();
        vm.load_configs(self.get_state_view());
        vm.verify_transaction(&self.data_store, txn)
    }

    pub fn get_state_view(&self) -> &ChainStateDB {
        &self.data_store
    }

    pub fn new_block(&mut self) {
        self.block_time += 1;
        let new_block = BlockMetadata::new(HashValue::zero(), 0, association_address(), None);
        let output = self
            .execute_transaction_block(vec![Transaction::BlockMetadata(new_block)])
            .expect("Executing block prologue should succeed")
            .pop()
            .expect("Failed to get the execution result for Block Prologue");
        // check if we emit the expected event, there might be more events for transaction fees
        //let event = output.events()[0].clone();
        //TODO block event.
        //assert!(event.key() == &new_block_event_key());
        //assert!(scs::from_bytes::<NewBlockEvent>(event.event_data()).is_ok());
        self.apply_write_set(output.write_set());
    }
}