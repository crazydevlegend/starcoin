// Test for Hash function in Move

script {
use 0x1::Hash;

fun main() {

    let input = x"616263";
    let expected_output = x"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
    assert(Hash::sha2_256(input) == expected_output, 0);

    let input = x"616263";
    let expected_output = x"3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532";
    assert(Hash::sha3_256(input) == expected_output, 0);

    let input = x"616263";
    let expected_output = x"4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45";
    assert(Hash::keccak_256(input) == expected_output, 0);

    let input = x"616263";
    let expected_output = x"8eb208f7e05d987a9b044a8e98c6b087f15a0bfc";
    assert(Hash::ripemd160(input) == expected_output, 0);

}
}
