// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { PeripheryHelpers } from "./utils/PeripheryHelpers.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";

// Import core BaseTest
import { BaseTest as CoreBaseTest } from "@superform-v2-core/test/BaseTest.t.sol";
import { ISuperLedgerConfiguration } from "@superform-v2-core/src/interfaces/accounting/ISuperLedgerConfiguration.sol";
// Periphery-specific imports
import { SuperGovernor } from "../src/SuperGovernor.sol";
import { SuperBank } from "../src/SuperBank.sol";
import { SuperOracle } from "../src/oracles/SuperOracle.sol";
import { SuperVaultAggregator } from "../src/SuperVault/SuperVaultAggregator.sol";
import { SuperVault } from "../src/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../src/SuperVault/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../src/SuperVault/SuperVaultEscrow.sol";
import { ECDSAPPSOracle } from "../src/oracles/ECDSAPPSOracle.sol";

import "forge-std/console2.sol";

struct PeripheryAddresses {
    SuperGovernor superGovernor;
    SuperBank superBank;
    SuperOracle oracleRegistry;
    SuperVaultAggregator superVaultAggregator;
    ECDSAPPSOracle ecdsappsOracle;
}

contract BaseTest is PeripheryHelpers, CoreBaseTest {
    using Clones for address;

    /*//////////////////////////////////////////////////////////////
                           PERIPHERY STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Global addresses for SuperVault strategies
    address public globalSVStrategy;
    address public globalSVGearStrategy;
    address public globalRuggableVault;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Call core setup first
        super.setUp();
        deployPeripheryAccounts();

        // Deploy periphery contracts
        PeripheryAddresses[] memory PA = new PeripheryAddresses[](chainIds.length);
        PA = _deployPeripheryContracts(PA);

        // Update treasury in SuperLedgerConfiguration to point to SuperBank
        _updateTreasuryInSuperLedgerConfiguration();

        // Configure periphery
        _configurePeripheryGovernor(PA);

        // Register periphery hooks
        _registerPeripheryHooks(PA);
    }

    /*//////////////////////////////////////////////////////////////
                          PERIPHERY DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function _deployPeripheryContracts(PeripheryAddresses[] memory PA) internal returns (PeripheryAddresses[] memory) {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            PA[i].superGovernor = new SuperGovernor{ salt: SALT }(
                address(this), address(this), address(this), TREASURY, POLYMER_PROVER[chainIds[i]]
            );
            vm.label(address(PA[i].superGovernor), SUPER_GOVERNOR_KEY);
            contractAddresses[chainIds[i]][SUPER_GOVERNOR_KEY] = address(PA[i].superGovernor);

            PA[i].superBank = new SuperBank{ salt: SALT }(address(PA[i].superGovernor));
            vm.label(address(PA[i].superBank), SUPER_BANK_KEY);
            contractAddresses[chainIds[i]][SUPER_BANK_KEY] = address(PA[i].superBank);

            // Update TREASURY to point to SuperBank
            TREASURY = address(PA[i].superBank);

            PA[i].oracleRegistry = new SuperOracle{ salt: SALT }(
                address(this), new address[](0), new address[](0), new bytes32[](0), new address[](0)
            );
            vm.label(address(PA[i].oracleRegistry), SUPER_ORACLE_KEY);
            contractAddresses[chainIds[i]][SUPER_ORACLE_KEY] = address(PA[i].oracleRegistry);

            PA[i].ecdsappsOracle = new ECDSAPPSOracle(address(PA[i].superGovernor));
            vm.label(address(PA[i].ecdsappsOracle), ECDSAPPS_ORACLE_KEY);
            contractAddresses[chainIds[i]][ECDSAPPS_ORACLE_KEY] = address(PA[i].ecdsappsOracle);

            // Deploy implementation contracts first
            address vaultImpl = address(new SuperVault());
            address strategyImpl = address(new SuperVaultStrategy());
            address escrowImpl = address(new SuperVaultEscrow());

            PA[i].superVaultAggregator =
                new SuperVaultAggregator(address(PA[i].superGovernor), vaultImpl, strategyImpl, escrowImpl);
            vm.label(address(PA[i].superVaultAggregator), SUPER_VAULT_AGGREGATOR_KEY);
            contractAddresses[chainIds[i]][SUPER_VAULT_AGGREGATOR_KEY] = address(PA[i].superVaultAggregator);

            if (chainIds[i] == ETH) {
                /// @dev set any new sv addresses here
                address aggregator = address(PA[i].superVaultAggregator);
                globalSVStrategy = SuperVaultAggregator(aggregator).STRATEGY_IMPLEMENTATION()
                    .predictDeterministicAddress(
                    keccak256(
                        abi.encodePacked(existingUnderlyingTokens[ETH][USDC_KEY], "SuperVault", "SV_USDC", uint256(0))
                    ),
                    aggregator
                );
                globalSVGearStrategy = SuperVaultAggregator(aggregator).STRATEGY_IMPLEMENTATION()
                    .predictDeterministicAddress(
                    keccak256(
                        abi.encodePacked(existingUnderlyingTokens[ETH][USDC_KEY], "SuperVault", "svGearbox", uint256(1))
                    ),
                    aggregator
                );

                globalRuggableVault = SuperVaultAggregator(aggregator).STRATEGY_IMPLEMENTATION()
                    .predictDeterministicAddress(
                    keccak256(
                        abi.encodePacked(
                            existingUnderlyingTokens[ETH][USDC_KEY], "SuperVault", "SV_USDC_RUG", uint256(1)
                        )
                    ),
                    aggregator
                );
            }

            // Set up governor configurations
            PA[i].superGovernor.setActivePPSOracle(address(PA[i].ecdsappsOracle));
            PA[i].superGovernor.addValidator(VALIDATOR);
        }
        return PA;
    }

    function _configurePeripheryGovernor(PeripheryAddresses[] memory PA) internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            SuperGovernor superGovernor = PA[i].superGovernor;

            superGovernor.setAddress(superGovernor.SUPER_VAULT_AGGREGATOR(), address(PA[i].superVaultAggregator));

            superGovernor.setAddress(superGovernor.TREASURY(), TREASURY);
        }
    }

    /**
     * @notice Registers periphery-specific hooks with the governor
     * @param PA Array of PeripheryAddresses structs containing periphery contract addresses
     */
    function _registerPeripheryHooks(PeripheryAddresses[] memory PA) internal {
        if (DEBUG) console2.log("---------------- REGISTERING PERIPHERY HOOKS ----------------");
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            SuperGovernor superGovernor = PA[i].superGovernor;

            console2.log("Registering periphery hooks for chain", chainIds[i]);

            // Register fulfillRequests hooks
            superGovernor.registerHook(hookAddresses[chainIds[i]][DEPOSIT_4626_VAULT_HOOK_KEY], true);
            superGovernor.registerHook(hookAddresses[chainIds[i]][REDEEM_4626_VAULT_HOOK_KEY], true);
            superGovernor.registerHook(hookAddresses[chainIds[i]][DEPOSIT_5115_VAULT_HOOK_KEY], true);
            superGovernor.registerHook(hookAddresses[chainIds[i]][REDEEM_5115_VAULT_HOOK_KEY], true);
            superGovernor.registerHook(hookAddresses[chainIds[i]][REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][REQUEST_REDEEM_7540_VAULT_HOOK_KEY], false);

            // Register remaining hooks
            superGovernor.registerHook(hookAddresses[chainIds[i]][APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY], true);
            superGovernor.registerHook(hookAddresses[chainIds[i]][APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY], true);
            superGovernor.registerHook(
                hookAddresses[chainIds[i]][APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY], true
            );
            superGovernor.registerHook(hookAddresses[chainIds[i]][APPROVE_ERC20_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][TRANSFER_ERC20_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][DEPOSIT_7540_VAULT_HOOK_KEY], true);
            superGovernor.registerHook(hookAddresses[chainIds[i]][WITHDRAW_7540_VAULT_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][APPROVE_AND_REQUEST_REDEEM_7540_VAULT_HOOK_KEY], true);
            superGovernor.registerHook(hookAddresses[chainIds[i]][SWAP_1INCH_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][SWAP_ODOSV2_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][APPROVE_AND_SWAP_ODOSV2_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][FLUID_CLAIM_REWARD_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][FLUID_STAKE_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][APPROVE_AND_FLUID_STAKE_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][FLUID_UNSTAKE_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][GEARBOX_CLAIM_REWARD_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][GEARBOX_STAKE_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][GEARBOX_APPROVE_AND_STAKE_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][GEARBOX_UNSTAKE_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][YEARN_CLAIM_ONE_REWARD_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][CANCEL_REDEEM_REQUEST_7540_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][CANCEL_REDEEM_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][MINT_SUPERPOSITIONS_HOOK_KEY], false);

            // EXPERIMENTAL HOOKS FROM HERE ONWARDS
            superGovernor.registerHook(hookAddresses[chainIds[i]][ETHENA_COOLDOWN_SHARES_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][ETHENA_UNSTAKE_HOOK_KEY], true);
            superGovernor.registerHook(hookAddresses[chainIds[i]][MORPHO_BORROW_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][MORPHO_REPAY_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][PENDLE_ROUTER_REDEEM_HOOK_KEY], false);
            superGovernor.registerHook(hookAddresses[chainIds[i]][OFFRAMP_TOKENS_HOOK_KEY], false);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          PERIPHERY GETTERS
    //////////////////////////////////////////////////////////////*/

    function _getPeripheryContract(uint64 chainId, string memory contractName) internal view returns (address) {
        return contractAddresses[chainId][contractName];
    }

    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    function _updateTreasuryInSuperLedgerConfiguration() internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            // Get the yield source oracle IDs that were created in _setupSuperLedger
            bytes32[] memory yieldSourceOracleIds = new bytes32[](4);
            yieldSourceOracleIds[0] =
                keccak256(abi.encodePacked(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER));
            yieldSourceOracleIds[1] =
                keccak256(abi.encodePacked(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER));
            yieldSourceOracleIds[2] =
                keccak256(abi.encodePacked(bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), MANAGER));
            yieldSourceOracleIds[3] =
                keccak256(abi.encodePacked(bytes32(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY)), MANAGER));

            // Read current configs to preserve existing settings
            ISuperLedgerConfiguration.YieldSourceOracleConfig[] memory currentConfigs = ISuperLedgerConfiguration(
                _getContract(chainIds[i], SUPER_LEDGER_CONFIGURATION_KEY)
            ).getYieldSourceOracleConfigs(yieldSourceOracleIds);

            // Create new config proposals with updated treasury
            ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory newConfigs =
                new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](4);

            newConfigs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: currentConfigs[0].yieldSourceOracle,
                feePercent: currentConfigs[0].feePercent,
                feeRecipient: TREASURY, // Updated treasury (SuperBank)
                ledger: currentConfigs[0].ledger
            });
            newConfigs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: currentConfigs[1].yieldSourceOracle,
                feePercent: currentConfigs[1].feePercent,
                feeRecipient: TREASURY, // Updated treasury (SuperBank)
                ledger: currentConfigs[1].ledger
            });
            newConfigs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: currentConfigs[2].yieldSourceOracle,
                feePercent: currentConfigs[2].feePercent,
                feeRecipient: TREASURY, // Updated treasury (SuperBank)
                ledger: currentConfigs[2].ledger
            });
            newConfigs[3] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: currentConfigs[3].yieldSourceOracle,
                feePercent: currentConfigs[3].feePercent,
                feeRecipient: TREASURY, // Updated treasury (SuperBank)
                ledger: currentConfigs[3].ledger
            });

            vm.startPrank(MANAGER);

            // Propose the configuration changes
            ISuperLedgerConfiguration(_getContract(chainIds[i], SUPER_LEDGER_CONFIGURATION_KEY))
                .proposeYieldSourceOracleConfig(yieldSourceOracleIds, newConfigs);

            vm.stopPrank();

            // Advance time past the proposal expiration period (1 week)
            vm.warp(block.timestamp + 1 weeks + 1);

            vm.startPrank(MANAGER);

            // Accept the proposed configuration changes
            ISuperLedgerConfiguration(_getContract(chainIds[i], SUPER_LEDGER_CONFIGURATION_KEY))
                .acceptYieldSourceOracleConfigProposal(yieldSourceOracleIds);

            vm.stopPrank();
        }
    }
}
