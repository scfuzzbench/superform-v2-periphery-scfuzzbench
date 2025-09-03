// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// External dependencies
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";
import {ActorManager} from "@recon/ActorManager.sol";
import {AssetManager} from "@recon/AssetManager.sol";
import {Utils} from "@recon/Utils.sol";
import {Deposit4626VaultHook} from "lib/v2-core/src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import {ApproveAndDeposit4626VaultHook} from "lib/v2-core/src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import {Redeem4626VaultHook} from "lib/v2-core/src/hooks/vaults/4626/Redeem4626VaultHook.sol";

// Source dependencies
import "src/SuperVault/SuperVault.sol";
import "src/SuperVault/SuperVaultAggregator.sol";
import "src/SuperVault/SuperVaultEscrow.sol";
import "src/SuperVault/SuperVaultStrategy.sol";
import "src/SuperGovernor.sol";
import {ISuperVaultAggregator} from "src/interfaces/SuperVault/ISuperVaultAggregator.sol";
import {ISuperVaultStrategy} from "src/interfaces/SuperVault/ISuperVaultStrategy.sol";
import {MockYieldSourceOracle} from "test/mocks/MockYieldSourceOracle.sol";

// Test suite dependencies
import {VaultManager} from "./managers/VaultManager.sol";
import {MerkleTestHelper} from "test/recon/helpers/MerkleTestHelper.sol";

abstract contract Setup is
    BaseSetup,
    ActorManager,
    AssetManager,
    VaultManager,
    Utils
{
    // Configuration constants
    uint8 internal constant DECIMALS = 18;

    // Core contracts
    SuperGovernor superGovernor;
    SuperVault superVault;
    SuperVaultAggregator superVaultAggregator;
    SuperVaultEscrow superVaultEscrow;
    SuperVaultStrategy superVaultStrategy;

    // Implementation contracts for aggregator
    SuperVault vaultImpl;
    SuperVaultStrategy strategyImpl;
    SuperVaultEscrow escrowImpl;

    // Helpers
    MerkleTestHelper merkleHelper;
    ApproveAndDeposit4626VaultHook approveAndDepositHook;
    Redeem4626VaultHook redeemHook;

    // Mocks
    MockYieldSourceOracle yieldSourceOracle;

    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        // 1. Add additional actors
        _addActor(address(0x100)); // Actor 1
        _addActor(address(0x200)); // Actor 2

        // 2. Create assets using AssetManager
        _newAsset(DECIMALS); // Deploy token with 18 decimals

        // 3. Deploy SuperGovernor first (required by other contracts)
        superGovernor = new SuperGovernor(
            address(this), // superGovernor role
            address(this), // governor role
            address(this), // bankManager role
            address(this), // treasury
            address(this) // prover
        );

        // 4. Deploy implementation contracts for the aggregator
        vaultImpl = new SuperVault(address(superGovernor));
        strategyImpl = new SuperVaultStrategy(address(superGovernor));
        escrowImpl = new SuperVaultEscrow();

        // 5. Deploy SuperVaultAggregator with implementation contracts
        superVaultAggregator = new SuperVaultAggregator(
            address(superGovernor),
            address(vaultImpl),
            address(strategyImpl),
            address(escrowImpl)
        );

        // 5a. Register the SuperVaultAggregator address with SuperGovernor
        superGovernor.setAddress(
            superGovernor.SUPER_VAULT_AGGREGATOR(),
            address(superVaultAggregator)
        );

        // 6. Deploy Mocks
        yieldSourceOracle = new MockYieldSourceOracle(
            1e18,
            1000e18,
            1000e18,
            true
        );

        // 7. Create a vault trio using the aggregator
        ISuperVaultAggregator.VaultCreationParams
            memory params = ISuperVaultAggregator.VaultCreationParams({
                asset: _getAsset(), // Use the token created by AssetManager
                name: "SuperVault",
                symbol: "SV",
                mainManager: address(this), // CONFIGURABLE: This parameter can be modified via target functions
                secondaryManagers: new address[](0),
                minUpdateInterval: 5, // CONFIGURABLE: This parameter can be modified via target functions
                maxStaleness: 300, // CONFIGURABLE: This parameter can be modified via target functions
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: 1000, // 10% performance fee
                    managementFeeBps: 100, // 1% management fee
                    recipient: address(this)
                })
            });

        (
            address vaultAddr,
            address strategyAddr,
            address escrowAddr
        ) = superVaultAggregator.createVault(params);

        // 8. Store the deployed contracts
        superVault = SuperVault(vaultAddr);
        superVaultStrategy = SuperVaultStrategy(payable(strategyAddr));
        superVaultEscrow = SuperVaultEscrow(escrowAddr);

        /// 9. Deploy hook contracts and helper
        approveAndDepositHook = new ApproveAndDeposit4626VaultHook();
        redeemHook = new Redeem4626VaultHook();
        merkleHelper = new MerkleTestHelper();

        superGovernor.registerHook(address(approveAndDepositHook), false);
        superGovernor.registerHook(address(redeemHook), true);

        // 10. Set up approval array for contracts that need token access
        address[] memory approvalArray = new address[](2);
        approvalArray[0] = address(superVault);
        approvalArray[1] = address(superVaultStrategy);

        // 11. Finalize asset deployment (mints to actors and sets approvals)
        _finalizeAssetDeployment(_getActors(), approvalArray, type(uint88).max);
    }

    /// === MODIFIERS === ///
    /// Prank admin and actor

    modifier asAdmin() {
        vm.prank(address(this));
        _;
    }

    modifier asActor() {
        vm.prank(address(_getActor()));
        _;
    }
}
