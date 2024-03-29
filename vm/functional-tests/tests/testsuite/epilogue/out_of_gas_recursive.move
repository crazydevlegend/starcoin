address default = {{default}};
module default::OddOrEven {
    public fun is_odd(x: u64): bool { if (x == 0) false else is_even(x - 1) }
    public fun is_even(x: u64): bool { if (x == 0) true else is_odd(x - 1) }
}

//! new-transaction
//! max-gas: 600000
address default = {{default}};
script {
use default::OddOrEven;
fun main() {
    OddOrEven::is_odd(1001);
}
}
// check: "EXECUTION_FAILURE { status_code: OUT_OF_GAS, location: 0xd98f86e3303c97b00313854b8314f51b::OddOrEven,"
// check: "gas_used: 600000,"
// check: "Keep(OUT_OF_GAS)"
