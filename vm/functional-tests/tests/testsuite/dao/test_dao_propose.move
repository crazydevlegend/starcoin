//! account: alice
//! account: bob

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 86400000

//! new-transaction
//! sender: association
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Account;
    use 0x1::STC::STC;
    use 0x1::Signer;

    fun transfer_some_token_to_alice_and_bob(signer: signer) {
        let balance = Account::balance<STC>(Signer::address_of(&signer));
        Account::pay_from<STC>(&signer, @alice, balance / 4);
        Account::pay_from<STC>(&signer, @bob, balance / 4);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    fun propose(signer: signer) {
        ModifyDaoConfigProposal::propose<STC>(signer, 60 * 60 * 24 * 1000, 0, 50, 0, 0);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Dao;
    use 0x1::STC::STC;
    use 0x1::ModifyDaoConfigProposal;

    fun proposal_info(_signer: signer) {
        let state = Dao::proposal_state<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
        assert(state == 1, (state as u64));

        let (id, start_time, end_time, for_votes, against_votes)
                = Dao::proposal_info<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice);

        assert(id == 0, 101);
        assert(start_time == 86460000, 102); // be consistent with genesis config
        assert(end_time == 90060000, 103); // be consistent with genesis config
        assert(for_votes == 0, 104);
        assert(against_votes == 0, 104);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 87000000


//! new-transaction
//! sender: bob
// call cast_vote to stake some token
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Dao;
    fun vote(signer: signer) {
        let balance = Account::balance<STC>(Signer::address_of(&signer));
        let balance = Account::withdraw<STC>(&signer, balance / 2);
        Dao::cast_vote<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0, balance, true);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: bob
// call cast_vote again to stake more token
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Dao;
    fun vote(signer: signer) {
        let balance = Account::balance<STC>(Signer::address_of(&signer));
        let balance = Account::withdraw<STC>(&signer, balance);
        Dao::cast_vote<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0, balance, true);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 3
//! block-time: 88000000


//! new-transaction
//! sender: bob
// test revoke_vote
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    use 0x1::Dao;
    use 0x1::Signer;
    use 0x1::Account;
    fun check_state_and_revoke(signer: signer) {
        let state = Dao::proposal_state<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
        assert(state == 2, (state as u64));
        let (_, pow) = Dao::vote_of<STC>(Signer::address_of(&signer), @alice, 0);
        let token = Dao::revoke_vote<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0, pow / 2);
        Account::deposit_to_self(&signer, token);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: bob

address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    use 0x1::Dao;
    use 0x1::Signer;
    use 0x1::Account;
    fun recast_vote(signer: signer) {
        let state = Dao::proposal_state<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
        assert(state == 2, (state as u64));
        {
            let balance = Account::balance<STC>(Signer::address_of(&signer));
            let balance = Account::withdraw<STC>(&signer, balance / 2);
            Dao::cast_vote<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0, balance, true);
        }
    }
}
// check: EXECUTED

//! new-transaction
//! sender: bob
// test flip_vote
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    use 0x1::Dao;
    use 0x1::Signer;
    use 0x1::Account;
    fun flip_vote(signer: signer) {
        // flip
        Dao::change_vote<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0, false);
        {
            let balance = Account::balance<STC>(Signer::address_of(&signer));
            let balance = Account::withdraw<STC>(&signer, balance / 2);
            Dao::cast_vote<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0, balance, false);
        };
        // revoke while 'against'
        {
            let (_, pow) = Dao::vote_of<STC>(Signer::address_of(&signer), @alice, 0);
            let token = Dao::revoke_vote<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0, pow / 10);
            Account::deposit_to_self(&signer, token);
        };
        // flip back
        Dao::change_vote<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0, true);
        {
            let balance = Account::balance<STC>(Signer::address_of(&signer));
            let balance = Account::withdraw<STC>(&signer, balance / 2);
            Dao::cast_vote<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0, balance, true);
        };
    }
}
// check: EXECUTED


//! block-prologue
//! author: genesis
//! block-number: 4
//! block-time: 180000000


//! new-transaction
//! sender: bob

address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    use 0x1::Account;
    use 0x1::Dao;
    fun queue_proposal(signer: signer) {
        let state = Dao::proposal_state<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
        assert(state == 4, (state as u64));
        {
            let token = Dao::unstake_votes<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(&signer, @alice, 0);
            Account::deposit_to_self(&signer, token);
        };
        Dao::queue_proposal_action<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
        // ModifyDaoConfigProposal::execute<STC>(@alice, 0);
        let state = Dao::proposal_state<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
        assert(state == 5, (state as u64));
    }
}
// check: EXECUTED


//! block-prologue
//! author: genesis
//! block-number: 5
//! block-time: 250000000


//! new-transaction
//! sender: bob

address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    use 0x1::Dao;
    fun cleanup_proposal_should_fail(_signer: signer) {
        Dao::destroy_terminated_proposal<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
    }
}
// check: "Keep(ABORTED { code: 359169"

//! new-transaction
//! sender: bob

address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    use 0x1::Dao;
    fun execute_proposal_action(_signer: signer) {
        let state = Dao::proposal_state<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
        assert(state == 6, (state as u64));
        ModifyDaoConfigProposal::execute<STC>(@alice, 0);
        assert(Dao::voting_delay<STC>()==3600 * 24 * 1000, Dao::voting_delay<STC>());
        assert(Dao::voting_quorum_rate<STC>() == 50, 1000);
    }
}
// check: EXECUTED


//! block-prologue
//! author: genesis
//! block-number: 6
//! block-time: 310000000


//! new-transaction
//! sender: bob

address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::ModifyDaoConfigProposal;
    use 0x1::STC::STC;
    use 0x1::Dao;
    fun cleanup_proposal(_signer: signer) {
        let state = Dao::proposal_state<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
        assert(state == 7, (state as u64));
        Dao::destroy_terminated_proposal<STC, ModifyDaoConfigProposal::DaoConfigUpdate>(@alice, 0);
    }
}
// check: EXECUTED

