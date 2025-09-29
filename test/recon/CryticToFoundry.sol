// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {MockERC20} from "@recon/MockERC20.sol";
import {MockERC4626Tester} from "test/recon/mocks/MockERC4626Tester.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Deposit4626VaultHook} from "lib/v2-core/src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import {ApproveAndDeposit4626VaultHook} from "lib/v2-core/src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import {Redeem4626VaultHook} from "lib/v2-core/src/hooks/vaults/4626/Redeem4626VaultHook.sol";
import {ISuperGovernor, FeeType} from "src/interfaces/ISuperGovernor.sol";

import {IECDSAPPSOracle} from "src/interfaces/oracles/IECDSAPPSOracle.sol";
import {ISuperVaultStrategy} from "src/interfaces/SuperVault/ISuperVaultStrategy.sol";
import {ISuperVaultAggregator} from "src/interfaces/SuperVault/ISuperVaultAggregator.sol";
import {YieldSourceType} from "test/recon/managers/YieldManager.sol";

import {MerkleTestHelper} from "./helpers/MerkleTestHelper.sol";
import {TargetFunctions} from "./TargetFunctions.sol";
import {MockERC4626Tester} from "./mocks/MockERC4626Tester.sol";
import {YieldSourceType} from "./managers/YieldManager.sol";

// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();
    }

    // attempt to force vault loss on withdrawal
    function test_forceLossOnWithdrawal() public {
        // register yield source
        superVaultStrategy_manageYieldSource_clamped(0);

        // make a deposit
        uint256 amounToDeposit = 10e18;
        superVault_deposit(amounToDeposit);

        // transfer assets into yield source
        uint256[] memory hookTypeInts = new uint256[](1);
        hookTypeInts[0] = 0;
        uint256[] memory amountsToInvest = new uint256[](1);
        amountsToInvest[0] = 2;
        bool[] memory usePrevHookAmounts = new bool[](1);
        usePrevHookAmounts[0] = false;
        superVaultStrategy_executeHooks_clamped(
            hookTypeInts,
            amountsToInvest,
            usePrevHookAmounts
        );

        // force a loss on the yield source
        // Set a 10% loss on withdrawal (10% of withdrawn amount will be lost)
        yieldSource_setLossOnWithdraw(1000); // 1000 basis points = 10%

        // Now call the doomsday function which should demonstrate the vulnerability
        // where the user will receive less than they deposited due to the loss on withdrawal
        uint256 sharesToMint = 5e18; // Mint some shares for the test

        // This will fail its internal assertion because the assertion in doomsday_mintRedeemSymmetrical
        // expects balanceAfter >= balanceBefore, but due to the loss on withdrawal,
        // the user will receive less assets than they initially put in
        doomsday_mintRedeemSymmetrical(sharesToMint);
    }

    // attempt to force loss on withdrawal on fulfillment
    function test_superVaultStrategy_fulfillRedeemRequestsLossOnWithdraw()
        public
    {
        // Setup yield source
        superVaultStrategy_manageYieldSource_clamped(
            uint256(YieldSourceType.ERC4626)
        );

        // User deposits into SuperVault to create shares
        switchActor(1);
        address user1 = _getActor();
        superVault_deposit(1000e18);

        // Manager invests funds into yield source using executeHooks
        switchActor(0);

        // First, invest deposits into the yield source
        // Use the clamped function to execute hooks
        uint256[] memory hookTypeInts = new uint256[](1);
        hookTypeInts[0] = 0; // ApproveAndDeposit4626 is the first enum value (index 0)

        uint256[] memory amountsToInvest = new uint256[](1);
        amountsToInvest[0] = 500e18; // Amount to deposit

        bool[] memory usePrevHookAmounts = new bool[](1);
        usePrevHookAmounts[0] = false;

        superVaultStrategy_executeHooks_clamped(
            hookTypeInts,
            amountsToInvest,
            usePrevHookAmounts
        );

        // Multiple users request redemptions with the same amount
        switchActor(1);
        uint256 redeemAmt = 100e18;
        superVault_requestRedeem(redeemAmt);

        // Second user also requests the same amount
        switchActor(2);
        address user2 = _getActor();
        superVault_deposit(500e18);
        superVault_requestRedeem(redeemAmt);

        // Get yield source reference and calculate implied PPS before
        MockERC4626Tester vault = MockERC4626Tester(_getYieldSource());
        uint256 impliedPPSBefore = vault.totalSupply() > 0
            ? (vault.totalAssets() * 1e18) / vault.totalSupply()
            : 1e18;

        console2.log("Yield Source PPS Before: %e", impliedPPSBefore);

        // Calculate expected assets to be received based on current PPS
        uint256 expectedAssets = vault.previewRedeem(redeemAmt);
        console2.log("Expected assets from yield source: %e", expectedAssets);

        // Track strategy's asset balance before fulfillment
        uint256 strategyAssetBalanceBefore = MockERC20(superVault.asset())
            .balanceOf(address(superVaultStrategy));
        console2.log(
            "Strategy asset balance before: %e",
            strategyAssetBalanceBefore
        );

        // Set loss on withdraw to demonstrate the property violation
        yieldSource_setLossOnWithdraw(1000); // 10% loss on withdraw

        // Execute fulfillRedeemRequests
        superVaultStrategy_fulfillRedeemRequests_clamped(redeemAmt);

        // Track strategy's asset balance after fulfillment
        uint256 strategyAssetBalanceAfter = MockERC20(superVault.asset())
            .balanceOf(address(superVaultStrategy));
        uint256 actualAssetsReceived = strategyAssetBalanceAfter -
            strategyAssetBalanceBefore;

        console2.log(
            "Strategy asset balance after: %e",
            strategyAssetBalanceAfter
        );
        console2.log(
            "Actual assets received by strategy: %e",
            actualAssetsReceived
        );

        // Calculate expected assets after applying lossOnWithdraw
        uint256 lossAmount = (expectedAssets * 1000) / 10000; // 10% loss
        uint256 expectedAssetsAfterLoss = expectedAssets - lossAmount;
        console2.log(
            "Expected assets after 10%% loss: %e",
            expectedAssetsAfterLoss
        );

        // Calculate implied price per share after
        uint256 impliedPPSAfter = vault.totalSupply() > 0
            ? (vault.totalAssets() * 1e18) / vault.totalSupply()
            : 1e18;

        console2.log("Yield Source PPS After: %e", impliedPPSAfter);

        // Property 1: The implied price per share of the yield source should not change
        assertEq(
            impliedPPSAfter,
            impliedPPSBefore,
            "Yield source implied PPS should not change after fulfillRedeemRequests"
        );

        // Property 2: The assets actually received should match the expected assets (without loss)
        // This will fail when there is a nonzero lossOnWithdraw
        assertEq(
            actualAssetsReceived,
            expectedAssets,
            "SuperVaultStrategy should receive full expected assets (property violation when lossOnWithdraw > 0)"
        );
    }

    /// Reproducers

    /// Triaged

    // forge test --match-test test_property_comparePreviewMintAndConvertToAssets_13 -vvv
    // NOTE: see issue here: https://github.com/Recon-Fuzz/superform-review/issues/49
    function test_property_comparePreviewMintAndConvertToAssets_13() public {
        superVaultStrategy_proposeVaultFeeConfigUpdate(
            0,
            10000,
            0x00000000000000000000000000000000DeaDBeef
        );

        vm.warp(block.timestamp + 237093);

        vm.roll(block.number + 1);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 367768);
        superVaultStrategy_executeVaultFeeConfigUpdate();

        property_comparePreviewMintAndConvertToAssets(1);
    }

    // forge test --match-test test_property_previewEquivalenceFromAssets_1 -vvv
    // NOTE: same as above, see issue here: https://github.com/Recon-Fuzz/superform-review/issues/49
    function test_property_previewEquivalenceFromAssets_1() public {
        superVaultStrategy_proposeVaultFeeConfigUpdate(
            0,
            10000,
            0x00000000000000000000000000000000DeaDBeef
        );

        vm.warp(block.timestamp + 605012);

        vm.roll(block.number + 1);

        superVaultStrategy_executeVaultFeeConfigUpdate();

        property_previewEquivalenceFromAssets(1);
    }

    // forge test --match-test test_property_previewEquivalenceFromShares_1 -vvv
    // NOTE: optimization tests in optimize_previewMintSharesGreater and optimize_previewDepositSharesGreater
    // NOTE: see issue here: https://github.com/Recon-Fuzz/superform-review/issues/55
    function test_property_previewEquivalenceFromShares_1() public {
        vm.warp(block.timestamp + 5);

        vm.roll(block.number + 1);

        ECDSAPPSOracle_updatePPS_clamped(1);

        console2.log("precision: ", superVault.PRECISION());
        property_previewEquivalenceFromShares(1);
    }

    // forge test --match-test test_doomsday_mintRedeemSymmetrical_4 -vvv
    // NOTE: requires admin hasn't called executeHooks to deposit into strategy yet but still fulfills
    // NOTE: see issue: https://github.com/Recon-Fuzz/superform-review/issues/61
    // NOTE: only breaks by < 10 wei, so to reproduce need to remove TOLERANCE value from doomsday test
    function test_doomsday_mintRedeemSymmetrical_4() public {
        superVaultStrategy_manageYieldSource_clamped(0);

        switchActor(1);
        yieldSource_mint(5, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);

        doomsday_mintRedeemSymmetrical(1);
    }

    // forge test --match-test test_doomsday_depositWithdrawSymmetrical_5 -vvv
    // NOTE: same as above, see issue: https://github.com/Recon-Fuzz/superform-review/issues/61
    // NOTE: only breaks by < 10 wei, so to reproduce need to remove TOLERANCE value from doomsday test
    function test_doomsday_depositWithdrawSymmetrical_5() public {
        superVaultStrategy_manageYieldSource_clamped(0);

        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);

        switchActor(1);

        (
            uint256 balanceAfter,
            uint256 balanceBefore
        ) = doomsday_depositWithdrawSymmetrical(2);
    }

    // forge test --match-test test_property_accumulatorSharesDecreaseOnFulfill_exact_6 -vvv
    // NOTE: see issue: https://github.com/Recon-Fuzz/superform-review/issues/62
    function test_property_accumulatorSharesDecreaseOnFulfill_exact_6() public {
        superVaultStrategy_manageYieldSource_clamped(0);

        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);

        superVault_deposit(4);

        superVault_requestRedeem_clamped(2);

        superVaultStrategy_fulfillRedeemRequests_clamped(1);

        property_accumulatorSharesDecreaseOnFulfill_exact();
    }

    // forge test --match-test test_doomsday_maxWithdrawResetsAfterFullWithdrawal_17 -vvv
    // NOTE: see issue here: https://github.com/Recon-Fuzz/superform-review/issues/66
    function test_doomsday_maxWithdrawResetsAfterFullWithdrawal_17() public {
        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);

        superVaultStrategy_manageYieldSource_clamped(0);

        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);

        superVault_deposit(3);

        superVault_requestRedeem_clamped(1);

        vm.warp(block.timestamp + 5);

        vm.roll(block.number + 1);

        ECDSAPPSOracle_updatePPS_clamped(
            700960855099362077226925743595804258294593977845093495232344554
        );

        yieldSource_simulateGain(973782);

        superVaultStrategy_fulfillRedeemRequests_clamped(1);

        superVault_requestRedeem_clamped(1);

        doomsday_maxWithdrawResetsAfterFullWithdrawal(988620);
    }

    // forge test --match-test test_property_sumOfClaimable_5 -vvv
    function test_property_sumOfClaimable_5() public {
        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);

        superVaultStrategy_manageYieldSource_clamped(0);

        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);

        superVault_deposit(3);

        superVault_requestRedeem_clamped(1);

        vm.warp(block.timestamp + 5);

        vm.roll(block.number + 1);

        ECDSAPPSOracle_updatePPS_clamped(
            700960855099362077226925743595804258294593977845093495232344554
        );

        yieldSource_simulateGain(973782);

        superVaultStrategy_fulfillRedeemRequests_clamped(1);

        superVault_requestRedeem_clamped(1);

        superVaultStrategy_fulfillRedeemRequests_clamped(1);

        property_sumOfClaimable();
    }

    /// To Triage

    // forge test --match-test test_superVaultStrategy_fulfillRedeemRequests_clamped_1 -vvv
    // NOTE: optimize_burnMoreThanRequestedInRedemption and optimize_burnLessThanRequestedInRedemption optimize the difference here
    // NOTE: waiting on results of latest run
    function test_superVaultStrategy_fulfillRedeemRequests_clamped_1() public {
        superVault_deposit(4);
        superVault_requestRedeem_clamped(2);
        superVaultStrategy_manageYieldSource_clamped(0);

        uint256[] memory hookTypes = new uint256[](1);
        hookTypes[
            0
        ] = 727274302833518615492845037239295802792876209365430308729559717363410497539;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        bool[] memory usePrevAmounts = new bool[](1);
        usePrevAmounts[0] = false;

        superVaultStrategy_executeHooks_clamped(
            hookTypes,
            amounts,
            usePrevAmounts
        );

        // summed accumulator shares decreases by 2 instead of 1 (the amount that the totalSupply decreases by)
        superVaultStrategy_fulfillRedeemRequests_clamped(1);
    }

    // forge test --match-test test_superVault_redeem_7 -vvv
    function test_superVault_redeem_7() public {
        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);

        superVaultStrategy_manageYieldSource_clamped(0);

        superVault_deposit(2);

        vm.warp(block.timestamp + 5);

        vm.roll(block.number + 1);

        superVault_requestRedeem_clamped(1);

        console2.log("price before: %e", superVaultStrategy.getStoredPPS());
        ECDSAPPSOracle_updatePPS_clamped(
            1444867979276057160025867155929543172595885788623704073633756549908877603528
        );
        console2.log(
            "price after: %e",
            superVaultStrategy.getStoredPPS() / 1e18
        );
        console2.log("uint88 max: %e", type(uint88).max);

        yieldSource_simulateGain(16331982);

        superVaultStrategy_fulfillRedeemRequests_clamped(1);

        superVault_redeem(
            3545828913032973376745291833460689430358553977498753678092653926509955
        );
    }

    // forge test --match-test test_doomsday_allUsersCanRedeem_9 -vvv
    function test_doomsday_allUsersCanRedeem_9() public {
        superVaultStrategy_manageYieldSource_clamped(0);
        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);
        superVault_deposit(3);

        // Time delay: 5 seconds Block delay: 1
        vm.warp(block.timestamp + 5);
        vm.roll(block.number + 1);

        superVault_requestRedeem_clamped(2);
        ECDSAPPSOracle_updatePPS_clamped(
            9320504895243615085225396559992523398860920652524151006431471807578417
        );
        yieldSource_simulateGain(325076);
        superVaultStrategy_fulfillRedeemRequests_clamped(2);

        uint256[] memory hookTypes = new uint256[](1);
        hookTypes[
            0
        ] = 4729689556898063238393822096407759716827207368140679563236174818045595764054;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 8201632728374255258148623956880033657806200687347644349;
        bool[] memory usePrevAmounts = new bool[](1);
        usePrevAmounts[0] = false;

        superVaultStrategy_executeHooks_clamped(
            hookTypes,
            amounts,
            usePrevAmounts
        );
        doomsday_allUsersCanRedeem();
    }

    // forge test --match-test test_property_superVaultStrategySolvency_11 -vvv
    function test_property_superVaultStrategySolvency_11() public {
        superVaultStrategy_manageYieldSource_clamped(0);
        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);
        superVault_deposit(2);
        superVault_requestRedeem_clamped(1);
        superVaultStrategy_fulfillRedeemRequests_clamped(1);

        uint256[] memory hookTypes = new uint256[](1);
        hookTypes[0] = 27653577;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 12079250118338547037798040541261519698465894585477304077;
        bool[] memory usePrevAmounts = new bool[](1);
        usePrevAmounts[0] = false;

        superVaultStrategy_executeHooks_clamped(
            hookTypes,
            amounts,
            usePrevAmounts
        );
        property_superVaultStrategySolvency();
    }

    // forge test --match-test test_doomsday_mintRedeemSymmetrical_5 -vvv
    function test_doomsday_mintRedeemSymmetrical_5() public {
        superVaultStrategy_manageYieldSource_clamped(0);

        yieldSource_mint(1, 0xc3C1658B1e3b9e017030807d0C50895456FD2379);

        vm.warp(block.timestamp + 5);

        vm.roll(block.number + 1);

        ECDSAPPSOracle_updatePPS_clamped(
            893250029380653568623780066441443881670086486436756102557863845932909
        );

        yieldSource_simulateGain(99585);

        switchActor(1);

        doomsday_mintRedeemSymmetrical(1);
    }

    /// Optimization tests
    // forge test --match-test test_optimize_maxDustAccumulation_1 -vvv
    function test_optimize_maxDustAccumulation_1() public {
        // Max value: 673998960742062360239077156080980998554;

        yieldSource_mint(132, 0x0000000000000000000000000000000000000000);

        asset_mint(
            0xc3C1658B1e3b9e017030807d0C50895456FD2379,
            333716593821123896775702548649212786971
        );

        console2.log("strategy", address(superVaultStrategy));
        address[] memory yieldSources = _getYieldSources();
        for (uint256 i = 0; i < yieldSources.length; i++) {
            if (yieldSources[i] != address(0)) {
                // Get the underlying asset balance held in each yield source
                console2.log("yield source", address(yieldSources[i]));
            }
        }

        asset_mint(
            0xc7183455a4C133Ae270771860664b6B7ec320bB1,
            340282366920938463463374607431768211451
        );
    }

    /// Gotchas

    // forge test --match-test test_property_naivePPSDoesntChangeOnDepositOrMint_2 -vvv
    // NOTE: naive PPS isn't used anywhere but useful to know that donations alter naive PPS
    function test_property_naivePPSDoesntChangeOnDepositOrMint_2() public {
        yieldSource_mint(1, 0x0000000000000000000000000000000000000000);

        // crytic_erc7540_7_deposit(2);

        superVault_mint(1);

        property_naivePPSDoesntChangeOnDepositOrMint();
    }

    // NOTE: naive PPS isn't used anywhere but useful to know
    // NOTE: shares are burned on fulfillment but assets only get transferred on withdraw/redeem so implied PPS changes after assets get transferred to user
    function test_property_naivePPSDoesntChangeOnRedeemOrWithdraw() public {
        superVault_deposit(4);
        superVault_requestRedeem_clamped(2);
        superVaultStrategy_manageYieldSource_clamped(0);

        uint256[] memory hookTypeInts = new uint256[](1);
        hookTypeInts[
            0
        ] = 3366039565052519506129160632812429979925236647654304654821762322802056013872;
        uint256[] memory amountsToInvest = new uint256[](1);
        amountsToInvest[0] = 2;
        bool[] memory usePrevHookAmounts = new bool[](1);
        usePrevHookAmounts[0] = false;
        superVaultStrategy_executeHooks_clamped(
            hookTypeInts,
            amountsToInvest,
            usePrevHookAmounts
        );
        superVaultStrategy_fulfillRedeemRequests_clamped(2);
        superVault_withdraw_clamped(1);
        property_naivePPSDoesntChangeOnRedeemOrWithdraw();
    }

    // forge test --match-test test_property_naivePPSDoesntChangeOnDepositOrMint_ -vvv
    function test_property_naivePPSDoesntChangeOnDepositOrMint_() public {
        superVault_deposit(2);

        yieldSource_simulateGain(1);

        superVault_mint(1);

        property_naivePPSDoesntChangeOnDepositOrMint();
    }

    // forge test --match-test test_property_previewEquivalenceFromAssets_ -vvv
    function test_property_previewEquivalenceFromAssets_() public {
        superVaultStrategy_proposeVaultFeeConfigUpdate(
            0,
            10000,
            0x00000000000000000000000000000000DeaDBeef
        );

        vm.warp(block.timestamp + 577107);

        vm.roll(block.number + 1);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 27732);
        superVaultStrategy_executeVaultFeeConfigUpdate();

        property_previewEquivalenceFromAssets(1);
    }

    // forge test --match-test test_property_previewEquivalenceFromShares_ -vvv
    function test_property_previewEquivalenceFromShares_() public {
        vm.warp(block.timestamp + 5);

        vm.roll(block.number + 1);

        ECDSAPPSOracle_updatePPS_clamped(100000); /// @audit Something dangerous tied to how prices work!?

        property_previewEquivalenceFromShares(1);
    }

    // forge test --match-test test_property_comparePreviewMintAndConvertToAssets_ -vvv
    function test_property_comparePreviewMintAndConvertToAssets_() public {
        superVaultStrategy_proposeVaultFeeConfigUpdate(
            0,
            10000,
            0x00000000000000000000000000000000DeaDBeef
        );

        vm.warp(block.timestamp + 604912);

        vm.roll(block.number + 1);

        superVaultStrategy_executeVaultFeeConfigUpdate();

        property_comparePreviewMintAndConvertToAssets(1);
    }

    /// @dev Test: Multi-actor deposit, withdrawal request, loss simulation, and distribution validation
    function test_multiActorDepositWithdrawLossDistribution() public {
        console2.log(
            "Assets in Strategy B4",
            MockERC20(superVault.asset()).balanceOf(address(superVaultStrategy))
        );
        console2.log(
            "Shares in vault B4",
            MockERC20(_getYieldSource()).balanceOf(address(superVaultStrategy))
        );
        console2.log(
            "Max Redeem B4",
            MockERC4626Tester(_getYieldSource()).maxRedeem(
                address(superVaultStrategy)
            )
        );

        // Deposit
        superVault_deposit(1000e18);
        switchActor(1);
        superVault_deposit(1000e18);

        switchActor(0); // Back to 0

        // Add yield source
        superVaultStrategy_manageYieldSource_clamped(0);

        // Deposit into it
        uint256[] memory hookTypeInts = new uint256[](1);
        hookTypeInts[0] = 0; // ApproveAndDeposit4626

        uint256[] memory amountsToInvest = new uint256[](1);
        amountsToInvest[0] = MockERC20(superVault.asset()).balanceOf(
            address(superVaultStrategy)
        );

        bool[] memory usePrevAmounts = new bool[](1);
        usePrevAmounts[0] = false;

        superVaultStrategy_executeHooks_clamped(
            hookTypeInts,
            amountsToInvest,
            usePrevAmounts
        );

        console2.log(
            "Assets in Strategy",
            MockERC20(superVault.asset()).balanceOf(address(superVaultStrategy))
        );
        console2.log(
            "Shares in vault",
            MockERC20(_getYieldSource()).balanceOf(address(superVaultStrategy))
        );
        console2.log(
            "Max Redeem",
            MockERC4626Tester(_getYieldSource()).maxRedeem(
                address(superVaultStrategy)
            )
        );

        // // Set loss on withdraw for ERC4626
        MockERC4626Tester(_getYieldSource()).setLossOnWithdraw(1000);

        // Request all redemptions
        superVault_requestRedeem_clamped(superVault.balanceOf(_getActor()));
        switchActor(1);
        superVault_requestRedeem_clamped(superVault.balanceOf(_getActor()));

        switchActor(0);
        superVaultStrategy_fulfillRedeemRequests_clamped(
            superVaultStrategy.pendingRedeemRequest(_getActor())
        );
        console2.log("pendingRedeemRequest", "0");
        switchActor(1);
        superVaultStrategy_fulfillRedeemRequests_clamped(
            superVaultStrategy.pendingRedeemRequest(_getActor())
        );
        console2.log("pendingRedeemRequest", "1");
        switchActor(0);

        // Compute the insolvency
        uint256 maxWithdrawAcc;
        for (uint256 i; i < _getActors().length; i++) {
            maxWithdrawAcc += superVault.maxWithdraw(_getActors()[i]);
        }

        console2.log("Max Withdraw Acc", maxWithdrawAcc);
        console2.log(
            "Strategy Balance Solvency",
            MockERC20(superVault.asset()).balanceOf(address(superVaultStrategy))
        );

        // Show the revert
        console2.log("Max Withdraw", superVault.maxWithdraw(_getActor()));
        superVault_withdraw(superVault.maxWithdraw(_getActor()));
        switchActor(1);
        console2.log("Max Withdraw", superVault.maxWithdraw(_getActor()));
        superVault_withdraw(superVault.maxWithdraw(_getActor()));

        // Check if solvent / insolvent due to cached PPS
    }
}
