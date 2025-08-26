// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../../BaseTest.t.sol";
import { console } from "forge-std/console.sol";

contract GetAddressesFromBaseTest is BaseTest {
    function setUp() public override {
        // Call the BaseTest setUp which does all the deployment work
        super.setUp();
    }

    /**
     * @notice Get addresses for deterministic merkle tree generation
     * @dev This logs addresses for the merkle tree pre-generation system
     */
    function test_getAddresses() external view {
        // Simply log each address individually to avoid stack too deep
        console.log("VAULT_globalSVStrategy:", globalSVStrategy);
        console.log("VAULT_globalSVGearStrategy:", globalSVGearStrategy);
        console.log("VAULT_globalRuggableVault:", globalRuggableVault);

        // Test vault addresses
        console.log("VAULT_test1_DynamicAllocation_MockVault:", test1_DynamicAllocation_MockVault);
        console.log("VAULT_test3_UnderlyingVaults_StressTest:", test3_UnderlyingVaults_StressTest);
        console.log("VAULT_test6_yieldAccumulation_vault1:", test6_yieldAccumulation_vault1);
        console.log("VAULT_test6_yieldAccumulation_vault2:", test6_yieldAccumulation_vault2);
        console.log("VAULT_test6_yieldAccumulation_vault3:", test6_yieldAccumulation_vault3);
        console.log(
            "VAULT_test6_yieldAccumulation_WithRebalancing_vault1:", test6_yieldAccumulation_WithRebalancing_vault1
        );
        console.log(
            "VAULT_test6_yieldAccumulation_WithRebalancing_vault2:", test6_yieldAccumulation_WithRebalancing_vault2
        );
        console.log(
            "VAULT_test6_yieldAccumulation_WithRebalancing_vault3:", test6_yieldAccumulation_WithRebalancing_vault3
        );
        console.log("VAULT_test10_RuggableVault_Deposit:", test10_RuggableVault_Deposit);
        console.log("VAULT_test10_RuggableVault_Withdraw:", test10_RuggableVault_Withdraw);
        console.log(
            "VAULT_test10_RuggableVault_Withdraw_ConvertDistortion:", test10_RuggableVault_Withdraw_ConvertDistortion
        );
        console.log("VAULT_test11_Allocate_NewYieldSource:", test11_Allocate_NewYieldSource);

        console.log("HOOK_APPROVE_AND_DEPOSIT_4626_VAULT_HOOK:", globalMerkleHooks[0]);
        console.log("HOOK_REDEEM_4626_VAULT_HOOK:", globalMerkleHooks[1]);
        console.log("HOOK_APPROVE_AND_GEARBOX_STAKE_HOOK:", globalMerkleHooks[2]);
        console.log("HOOK_GEARBOX_UNSTAKE_HOOK:", globalMerkleHooks[3]);
        console.log("HOOK_MOCK_NATIVE_ETH_HOOK:", globalMerkleHooksPeriphery[0]);
        console.log("MOCK_ETH_RECEIVER:", contractAddresses[ETH]["MOCK_ETH_RECEIVER"]);
    }
}
