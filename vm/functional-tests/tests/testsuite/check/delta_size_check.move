//! account: alice, 90000 0x1::STC::STC
//! account: bob, 90000 0x1::STC::STC

//! sender: alice

address alice = {{alice}};
address bob = {{bob}};
module alice::A {
    struct Coin has key, store {
        u: u64,
    }

    public fun new(): Coin {
        Coin { u: 1 }
    }

    public fun value(this: &Coin) : u64 {
        //borrow of move
        let f = (move this).u;
        f
    }
    public fun destroy(t: Coin): u64 {
        let Coin { u } = t;
        u
    }
}

//! new-transaction
//! sender: bob

address alice = {{alice}};
address bob = {{bob}};
module bob::Tester {
    use alice::A;

    struct Pair has key, store { x: A::Coin, y: A::Coin }

    public fun test(account: &signer) {
        move_to<Pair>(account, Pair { x: A::new(), y: A::new() });
    }

}

//! new-transaction
//! sender: bob

address alice = {{alice}};
address bob = {{bob}};
script {
use bob::Tester;

fun main(account: signer) {
    Tester::test(&account);
}
}

// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
address bob = {{bob}};
script {
use alice::A;

fun main() {
    let x = A::new();
    let x_ref = &x;
    let y = A::value(x_ref);
    assert(y == 1, 42);
   let z = A::destroy(x);
   assert(z == 1, 43);
}
}

// check: EXECUTED
