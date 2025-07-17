// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ISuperDeployer } from "@superform-v2-core/src/interfaces/ISuperDeployer.sol";
import { ConfigPeriphery } from "./utils/ConfigPeriphery.sol";
import { CoreS3Fetcher } from "./utils/CoreS3Fetcher.sol";

// Periphery contracts
import { SuperGovernor } from "../src/SuperGovernor.sol";
import { SuperVaultAggregator } from "../src/SuperVault/SuperVaultAggregator.sol";
import { SuperVault } from "../src/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../src/SuperVault/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../src/SuperVault/SuperVaultEscrow.sol";
import { ECDSAPPSOracle } from "../src/oracles/ECDSAPPSOracle.sol";
import { SuperOracle } from "../src/oracles/SuperOracle.sol";
import { VaultBank } from "../src/VaultBank/VaultBank.sol";

import { console2 } from "forge-std/console2.sol";

contract DeployV2Periphery is DeployV2Base, ConfigPeriphery, CoreS3Fetcher {
    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address private vaultBankAddress;

    struct PeripheryContracts {
        address superGovernor;
        address superVaultAggregator;
        address ecdsappsOracle;
        address superOracle;
        address vaultImpl;
        address strategyImpl;
        address escrowImpl;
        address vaultBank;
    }

    struct HookAddresses {
        address approveErc20Hook;
        address transferErc20Hook;
        address batchTransferHook;
        address batchTransferFromHook;
        address offrampTokensHook;
        address deposit4626VaultHook;
        address approveAndDeposit4626VaultHook;
        address redeem4626VaultHook;
        address deposit5115VaultHook;
        address redeem5115VaultHook;
        address approveAndDeposit5115VaultHook;
        address deposit7540VaultHook;
        address requestDeposit7540VaultHook;
        address approveAndRequestDeposit7540VaultHook;
        address approveAndRequestRedeem7540VaultHook;
        address redeem7540VaultHook;
        address requestRedeem7540VaultHook;
        address withdraw7540VaultHook;
        address acrossSendFundsAndExecuteOnDstHook;
        address swap1InchHook;
        address swapOdosHook;
        address approveAndSwapOdosHook;
        address cancelDepositRequest7540Hook;
        address cancelRedeemRequest7540Hook;
        address claimCancelDepositRequest7540Hook;
        address claimCancelRedeemRequest7540Hook;
        address cancelRedeemHook;
        address deBridgeSendOrderAndExecuteOnDstHook;
        address deBridgeCancelOrderHook;
        address ethenaCooldownSharesHook;
        address ethenaUnstakeHook;
    }

    /// @notice Sets up complete configuration for periphery contracts
    /// @param env Environment (0/2 = production, 1 = test)
    /// @param saltNamespace Salt namespace for deployment (if empty, uses production default)
    function _setConfiguration(uint256 env, string memory saltNamespace) internal {
        // Set base configuration (chain names, common addresses)
        _setBaseConfiguration(env, saltNamespace);

        // Set periphery contract dependencies
        _setPeripheryConfiguration();
    }

    function run(uint256 env, uint64 chainId) public broadcast(env) {
        _setConfiguration(env, "");
        _deployPeriphery(chainId);
    }

    function run(uint256 env, uint64 chainId, string memory saltNamespace) public broadcast(env) {
        _setConfiguration(env, saltNamespace);
        _deployPeriphery(chainId);
    }

    function _deployPeriphery(uint64 chainId) internal {
        console2.log("Deploying V2 Periphery on chainId: ", chainId);

        // Read SuperDeployer from core deployment
        _readSuperDeployer(chainId);

        // Deploy periphery contracts
        PeripheryContracts memory peripheryContracts = _deployPeripheryContracts(chainId);

        // Read hook addresses from core deployment
        HookAddresses memory hookAddresses = _readHookAddresses(chainId);

        // Register hooks and configure governor
        _registerHooks(hookAddresses, SuperGovernor(peripheryContracts.superGovernor));
        _configureGovernor(
            SuperGovernor(peripheryContracts.superGovernor),
            peripheryContracts.superVaultAggregator,
            peripheryContracts.vaultBank
        );

        // Grant roles and revoke from deployer
        _configureGovernorRoles(SuperGovernor(peripheryContracts.superGovernor));

        // Write all exported contracts for this chain
        _writeExportedContracts(chainId);
    }

    function _fetchOrReadCoreContracts() internal returns (string memory coreJson) {
        // Determine branch name based on environment
        string memory branchName;
        if (vm.envOr("CI", false)) {
            branchName = vm.envString("GITHUB_REF_NAME");
        } else {
            branchName = "local";
        }

        console2.log("Fetching core contracts for branch:", branchName);

        // Try to read from local file first
        coreJson = readCoreContractsFromFile(branchName);

        if (bytes(coreJson).length == 0) {
            // If not found locally, fetch from S3
            console2.log("Core contracts not found locally, fetching from S3...");
            coreJson = fetchAndSaveCoreContracts(branchName);
        } else {
            console2.log("Using cached core contracts from local file");
        }

        return coreJson;
    }

    function _readSuperDeployer(uint64 chainId) internal {
        string memory coreJson = _fetchOrReadCoreContracts();
        string memory networkName = chainNames[chainId];
        configuration.deployer = getContractAddress(coreJson, networkName, "SuperDeployer");
        console2.log("Using SuperDeployer from core deployment at:", configuration.deployer);
    }

    function _readHookAddresses(uint64 chainId) internal returns (HookAddresses memory) {
        string memory coreJson = _fetchOrReadCoreContracts();
        string memory networkName = chainNames[chainId];

        HookAddresses memory hookAddresses;
        hookAddresses.approveErc20Hook = getContractAddress(coreJson, networkName, "ApproveERC20Hook");
        hookAddresses.transferErc20Hook = getContractAddress(coreJson, networkName, "TransferERC20Hook");
        hookAddresses.batchTransferHook = getContractAddress(coreJson, networkName, "BatchTransferHook");
        hookAddresses.batchTransferFromHook = getContractAddress(coreJson, networkName, "BatchTransferFromHook");
        hookAddresses.offrampTokensHook = getContractAddress(coreJson, networkName, "OfframpTokensHook");
        hookAddresses.deposit4626VaultHook = getContractAddress(coreJson, networkName, "Deposit4626VaultHook");
        hookAddresses.approveAndDeposit4626VaultHook =
            getContractAddress(coreJson, networkName, "ApproveAndDeposit4626VaultHook");
        hookAddresses.redeem4626VaultHook = getContractAddress(coreJson, networkName, "Redeem4626VaultHook");
        hookAddresses.deposit5115VaultHook = getContractAddress(coreJson, networkName, "Deposit5115VaultHook");
        hookAddresses.redeem5115VaultHook = getContractAddress(coreJson, networkName, "Redeem5115VaultHook");
        hookAddresses.approveAndDeposit5115VaultHook =
            getContractAddress(coreJson, networkName, "ApproveAndDeposit5115VaultHook");
        hookAddresses.deposit7540VaultHook = getContractAddress(coreJson, networkName, "Deposit7540VaultHook");
        hookAddresses.requestDeposit7540VaultHook =
            getContractAddress(coreJson, networkName, "RequestDeposit7540VaultHook");
        hookAddresses.approveAndRequestDeposit7540VaultHook =
            getContractAddress(coreJson, networkName, "ApproveAndRequestDeposit7540VaultHook");
        hookAddresses.approveAndRequestRedeem7540VaultHook =
            getContractAddress(coreJson, networkName, "ApproveAndRequestRedeem7540VaultHook");
        hookAddresses.redeem7540VaultHook = getContractAddress(coreJson, networkName, "Redeem7540VaultHook");
        hookAddresses.requestRedeem7540VaultHook =
            getContractAddress(coreJson, networkName, "RequestRedeem7540VaultHook");
        hookAddresses.withdraw7540VaultHook = getContractAddress(coreJson, networkName, "Withdraw7540VaultHook");
        hookAddresses.acrossSendFundsAndExecuteOnDstHook =
            getContractAddress(coreJson, networkName, "AcrossSendFundsAndExecuteOnDstHook");
        hookAddresses.swap1InchHook = getContractAddress(coreJson, networkName, "Swap1InchHook");
        hookAddresses.swapOdosHook = getContractAddress(coreJson, networkName, "SwapOdosV2Hook");
        hookAddresses.approveAndSwapOdosHook = getContractAddress(coreJson, networkName, "ApproveAndSwapOdosV2Hook");
        hookAddresses.cancelDepositRequest7540Hook =
            getContractAddress(coreJson, networkName, "CancelDepositRequest7540Hook");
        hookAddresses.cancelRedeemRequest7540Hook =
            getContractAddress(coreJson, networkName, "CancelRedeemRequest7540Hook");
        hookAddresses.claimCancelDepositRequest7540Hook =
            getContractAddress(coreJson, networkName, "ClaimCancelDepositRequest7540Hook");
        hookAddresses.claimCancelRedeemRequest7540Hook =
            getContractAddress(coreJson, networkName, "ClaimCancelRedeemRequest7540Hook");
        hookAddresses.cancelRedeemHook = getContractAddress(coreJson, networkName, "CancelRedeemHook");
        hookAddresses.deBridgeSendOrderAndExecuteOnDstHook =
            getContractAddress(coreJson, networkName, "DeBridgeSendOrderAndExecuteOnDstHook");
        hookAddresses.deBridgeCancelOrderHook = getContractAddress(coreJson, networkName, "DeBridgeCancelOrderHook");
        hookAddresses.ethenaCooldownSharesHook = getContractAddress(coreJson, networkName, "EthenaCooldownSharesHook");
        hookAddresses.ethenaUnstakeHook = getContractAddress(coreJson, networkName, "EthenaUnstakeHook");

        return hookAddresses;
    }

    function _deployPeripheryContracts(uint64 chainId)
        internal
        returns (PeripheryContracts memory peripheryContracts)
    {
        // retrieve deployer
        ISuperDeployer deployer = ISuperDeployer(configuration.deployer);

        // Deploy SuperGovernor
        peripheryContracts.superGovernor = __deployContract(
            deployer,
            SUPER_GOVERNOR_KEY,
            chainId,
            __getSalt(SUPER_GOVERNOR_KEY),
            abi.encodePacked(
                type(SuperGovernor).creationCode,
                abi.encode(
                    configuration.owner,
                    configuration.owner,
                    configuration.owner,
                    configuration.treasury,
                    configuration.polymerProvers[chainId]
                )
            )
        );

        // Deploy SuperVault implementations first
        peripheryContracts.vaultImpl = __deployContract(
            deployer,
            "SuperVaultImplementation",
            chainId,
            __getSalt("SuperVaultImplementation"),
            type(SuperVault).creationCode
        );

        peripheryContracts.strategyImpl = __deployContract(
            deployer,
            "SuperVaultStrategyImplementation",
            chainId,
            __getSalt("SuperVaultStrategyImplementation"),
            type(SuperVaultStrategy).creationCode
        );

        peripheryContracts.escrowImpl = __deployContract(
            deployer,
            "SuperVaultEscrowImplementation",
            chainId,
            __getSalt("SuperVaultEscrowImplementation"),
            type(SuperVaultEscrow).creationCode
        );

        // Deploy SuperVaultAggregator (takes all four addresses)
        peripheryContracts.superVaultAggregator = __deployContract(
            deployer,
            SUPER_VAULT_AGGREGATOR_KEY,
            chainId,
            __getSalt(SUPER_VAULT_AGGREGATOR_KEY),
            abi.encodePacked(
                type(SuperVaultAggregator).creationCode,
                abi.encode(
                    peripheryContracts.superGovernor,
                    peripheryContracts.vaultImpl,
                    peripheryContracts.strategyImpl,
                    peripheryContracts.escrowImpl
                )
            )
        );

        // Deploy ECDSAPPSOracle
        peripheryContracts.ecdsappsOracle = __deployContract(
            deployer,
            ECDSAPPS_ORACLE_KEY,
            chainId,
            __getSalt(ECDSAPPS_ORACLE_KEY),
            abi.encodePacked(type(ECDSAPPSOracle).creationCode, abi.encode(peripheryContracts.superGovernor))
        );

        // Deploy SuperOracle
        peripheryContracts.superOracle = __deployContract(
            deployer,
            SUPER_ORACLE_KEY,
            chainId,
            __getSalt(SUPER_ORACLE_KEY),
            abi.encodePacked(
                type(SuperOracle).creationCode,
                abi.encode(configuration.owner, new address[](0), new address[](0), new uint256[](0), new bytes32[](0))
            )
        );

        // Deploy VaultBank
        peripheryContracts.vaultBank = __deployContract(
            deployer,
            VAULT_BANK_KEY,
            chainId,
            __getSalt(VAULT_BANK_KEY),
            abi.encodePacked(type(VaultBank).creationCode, abi.encode(peripheryContracts.superGovernor))
        );

        // Configure SuperGovernor with oracle and validator
        SuperGovernor(peripheryContracts.superGovernor).setActivePPSOracle(peripheryContracts.ecdsappsOracle);
        SuperGovernor(peripheryContracts.superGovernor).addValidator(configuration.validator);

        // Store VaultBank address for multi-chain configuration (CREATE2 ensures same address across chains)
        vaultBankAddress = peripheryContracts.vaultBank;

        // Add VaultBanks for all supported chains (same address due to CREATE2)
        _configureAllChainVaultBanks(SuperGovernor(peripheryContracts.superGovernor));

        console2.log("All periphery contracts deployed and configured successfully.");

        return peripheryContracts;
    }

    function _registerHooks(HookAddresses memory hookAddresses, SuperGovernor superGovernor) internal {
        // Register fulfillRequests hooks
        superGovernor.registerHook(hookAddresses.deposit4626VaultHook, true);
        superGovernor.registerHook(hookAddresses.approveAndDeposit4626VaultHook, true);
        superGovernor.registerHook(hookAddresses.redeem4626VaultHook, true);
        superGovernor.registerHook(hookAddresses.deposit5115VaultHook, true);
        superGovernor.registerHook(hookAddresses.approveAndDeposit5115VaultHook, true);
        superGovernor.registerHook(hookAddresses.redeem5115VaultHook, true);
        superGovernor.registerHook(hookAddresses.deposit7540VaultHook, true);
        superGovernor.registerHook(hookAddresses.redeem7540VaultHook, true);
        superGovernor.registerHook(hookAddresses.approveAndRequestRedeem7540VaultHook, true);

        // Register remaining hooks
        superGovernor.registerHook(hookAddresses.approveErc20Hook, false);
        superGovernor.registerHook(hookAddresses.transferErc20Hook, false);
        superGovernor.registerHook(hookAddresses.batchTransferHook, false);
        superGovernor.registerHook(hookAddresses.batchTransferFromHook, false);
        superGovernor.registerHook(hookAddresses.requestDeposit7540VaultHook, false);
        superGovernor.registerHook(hookAddresses.approveAndRequestDeposit7540VaultHook, false);
        superGovernor.registerHook(hookAddresses.requestRedeem7540VaultHook, false);
        superGovernor.registerHook(hookAddresses.withdraw7540VaultHook, false);
        superGovernor.registerHook(hookAddresses.swap1InchHook, false);
        superGovernor.registerHook(hookAddresses.swapOdosHook, false);
        superGovernor.registerHook(hookAddresses.approveAndSwapOdosHook, false);
        superGovernor.registerHook(hookAddresses.acrossSendFundsAndExecuteOnDstHook, false);
        superGovernor.registerHook(hookAddresses.deBridgeSendOrderAndExecuteOnDstHook, false);
        superGovernor.registerHook(hookAddresses.deBridgeCancelOrderHook, false);
        superGovernor.registerHook(hookAddresses.cancelDepositRequest7540Hook, false);
        superGovernor.registerHook(hookAddresses.cancelRedeemRequest7540Hook, false);
        superGovernor.registerHook(hookAddresses.claimCancelDepositRequest7540Hook, false);
        superGovernor.registerHook(hookAddresses.claimCancelRedeemRequest7540Hook, false);
        superGovernor.registerHook(hookAddresses.cancelRedeemHook, false);
        superGovernor.registerHook(hookAddresses.ethenaCooldownSharesHook, false);
        superGovernor.registerHook(hookAddresses.ethenaUnstakeHook, false);
        superGovernor.registerHook(hookAddresses.offrampTokensHook, false);

        console2.log("All hooks registered successfully.");
    }

    function _configureGovernor(SuperGovernor superGovernor, address aggregator, address vaultBank) internal {
        superGovernor.setAddress(superGovernor.SUPER_VAULT_AGGREGATOR(), aggregator);
        superGovernor.setAddress(superGovernor.VAULT_BANK(), vaultBank);
        console2.log("SuperGovernor configured with SuperVaultAggregator and VaultBank.");
    }

    function _configureGovernorRoles(SuperGovernor superGovernor) internal {
        // Grant SUPER_GOVERNOR_ROLE to the validator address and revoke from TEST_DEPLOYER
        superGovernor.grantRole(keccak256("SUPER_GOVERNOR_ROLE"), 0xd95f4bc7733d9E94978244C0a27c1815878a59BB);
        console2.log("Granted SUPER_GOVERNOR_ROLE to: 0xd95f4bc7733d9E94978244C0a27c1815878a59BB");

        superGovernor.revokeRole(keccak256("SUPER_GOVERNOR_ROLE"), TEST_DEPLOYER);
        console2.log("Revoked SUPER_GOVERNOR_ROLE from TEST_DEPLOYER");
    }

    /// @notice Configures VaultBanks for all supported chains using CREATE2 deterministic address
    /// @param superGovernor The SuperGovernor instance to configure
    function _configureAllChainVaultBanks(SuperGovernor superGovernor) internal {
        console2.log("Configuring VaultBanks for all supported chains...");

        // Supported chain IDs - VaultBank will have same address due to CREATE2
        uint64[3] memory supportedChains = [uint64(1), uint64(8453), uint64(10)];

        for (uint256 i = 0; i < supportedChains.length; i++) {
            uint64 chainId = supportedChains[i];

            superGovernor.addVaultBank(chainId, vaultBankAddress);
            console2.log("Added VaultBank for chain", chainId, "at address:", vaultBankAddress);
        }

        console2.log("Multi-chain VaultBank configuration completed");
    }
}
