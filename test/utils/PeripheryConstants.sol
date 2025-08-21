// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

abstract contract PeripheryConstants {
    string public constant SUPER_ORACLE_KEY = "SuperOracle";
    string public constant SUPER_GOVERNOR_KEY = "SuperGovernor";
    string public constant SUPER_BANK_KEY = "SuperBank";
    string public constant SUPER_VAULT_AGGREGATOR_KEY = "SUPER_VAULT_AGGREGATOR";
    string public constant ECDSAPPS_ORACLE_KEY = "ECDSAPPS_ORACLE";
    string public constant ECDSAPPS_ORACLE_VERSION = "1.0";
    uint256 public constant EMERGENCY_ADMIN_KEY = 0x6;

    address public constant CHAIN_1_POLYMER_PROVER = 0x441f16587d8a8cACE647352B24E1Aefa55ACEA76;
    address public constant CHAIN_10_POLYMER_PROVER = address(0); // not available
    address public constant CHAIN_8453_POLYMER_PROVER = address(0); // not available
}
