// Copyright (c) The Starcoin Core Contributors
// SPDX-License-Identifier: Apache-2.0

// Copyright (c) The Libra Core Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::account_address::AccountAddress;
use crate::block::BlockHeader;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use starcoin_crypto::{hash::CryptoHash, HashValue};

/// Struct that will be persisted on chain to store the information of the current block.
///
/// The flow will look like following:
/// 1. The executor will pass this struct to VM at the end of a block proposal.
/// 2. The VM will use this struct to create a special system transaction that will modify the on
///    chain resource that represents the information of the current block. This transaction can't
///    be emitted by regular users and is generated by each of the validators on the fly. Such
///    transaction will be executed before all of the user-submitted transactions in the blocks.
/// 3. Once that special resource is modified, the other user transactions can read the consensus
///    info by calling into the read method of that resource, which would thus give users the
///    information such as the current leader.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, CryptoHash)]
pub struct BlockMetadata {
    id: HashValue,
    timestamp: u64,
    author: AccountAddress,
    auth_key_prefix: Option<Vec<u8>>,
    //TODO add more field.
}

impl BlockMetadata {
    pub fn new(
        id: HashValue,
        timestamp: u64,
        author: AccountAddress,
        auth_key_prefix: Option<Vec<u8>>,
    ) -> Self {
        Self {
            id,
            timestamp,
            author,
            auth_key_prefix,
        }
    }

    pub fn into_inner(self) -> Result<(Vec<u8>, u64, AccountAddress, Option<Vec<u8>>)> {
        let id = self.id.to_vec();
        Ok((id, self.timestamp, self.author, self.auth_key_prefix))
    }
}

impl From<BlockHeader> for BlockMetadata {
    fn from(header: BlockHeader) -> Self {
        header.into_metadata()
    }
}
