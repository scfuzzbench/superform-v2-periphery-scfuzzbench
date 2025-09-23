// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";
import {MockERC20} from "@recon/MockERC20.sol";

import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {ISuperVaultStrategy} from "src/interfaces/SuperVault/ISuperVaultStrategy.sol";
import {YieldSourceType} from "test/recon/managers/YieldManager.sol";
import {MockERC4626Tester} from "test/recon/mocks/MockERC4626Tester.sol";

abstract contract DoomsdayTargets is BaseTargetFunctions, Properties {
    /// @dev Property: previewDeposit and deposit equivalence
    function doomsday_previewDepositEquivalence(
        uint256 assets
    ) public stateless {
        uint256 previewDepositShares = superVault.previewDeposit(assets);

        vm.prank(_getActor());
        uint256 sharesActualDeposit = superVault.deposit(assets, _getActor());

        eq(
            previewDepositShares,
            sharesActualDeposit,
            "previewDeposit and deposit equivalence"
        );
    }

    /// @dev Property: previewMint and mint equivalence
    function doomsday_previewMintEquivalence(uint256 shares) public stateless {
        uint256 previewMintAssets = superVault.previewMint(shares);

        vm.prank(_getActor());
        uint256 assetsActualMint = superVault.mint(shares, _getActor());

        eq(
            previewMintAssets,
            assetsActualMint,
            "previewMint and mint equivalence"
        );
    }

    /// @dev Property: mint/redeem is symmetrical
    // NOTE: ignores yield gain because there's no simple way to determine yield distribution for the superVault
    // NOTE: removed because donations have similar effect as yield gain and can't be easily handled
    // function doomsday_mintRedeemSymmetrical(
    //     uint256 sharesToMint
    // ) public stateless {
    //     // skip if there's been any gain because it complicates the assertion checking
    //     if (MockERC4626Tester(_getYieldSource()).totalGains() > 0) {
    //         return;
    //     }

    //     uint256 balanceBefore = MockERC20(_getAsset()).balanceOf(_getActor());

    //     // 1. Deposit
    //     superVault.mint(sharesToMint, _getActor());

    //     // 2. Request Redemption
    //     uint256 shares = superVault.balanceOf(_getActor());
    //     superVault.requestRedeem(shares, _getActor(), _getActor());

    //     // 3. Fulfill Redemption
    //     ISuperVaultStrategy.FulfillArgs
    //         memory fulfillArgs = _createFulfillRedeemArgs(shares);
    //     superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

    //     // 4. Claim Redemption
    //     superVault.redeem(shares, _getActor(), _getActor());

    //     uint256 balanceAfter = MockERC20(_getAsset()).balanceOf(_getActor());

    //     lte(
    //         balanceAfter,
    //         balanceBefore,
    //         "User gained assets in deposit/withdrawal flow"
    //     );
    // }

    /// @dev Property: deposit/withdraw is symmetrical
    // NOTE: ignores yield gain because there's no simple way to determine yield distribution for the superVault
    // NOTE: removed because donations have similar effect as yield gain and can't be easily handled
    // function doomsday_depositWithdrawSymmetrical(
    //     uint256 assetsToDeposit
    // ) public stateless {
    //     // skip if there's been any gain because it complicates the assertion checking
    //     if (MockERC4626Tester(_getYieldSource()).totalGains() > 0) {
    //         return;
    //     }

    //     uint256 balanceBefore = MockERC20(_getAsset()).balanceOf(_getActor());

    //     // 1. Deposit
    //     superVault.deposit(assetsToDeposit, _getActor());

    //     // 2. Request Withdrawal (through redemption in ERC7540)
    //     uint256 shares = superVault.balanceOf(_getActor());
    //     superVault.requestRedeem(shares, _getActor(), _getActor());

    //     // 3. Fulfill Withdrawal
    //     ISuperVaultStrategy.FulfillArgs
    //         memory fulfillArgs = _createFulfillRedeemArgs(shares);
    //     superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

    //     // 4. Claim Withdrawal
    //     uint256 withdrawableAssets = superVault.maxWithdraw(_getActor());
    //     superVault.withdraw(withdrawableAssets, _getActor(), _getActor());

    //     uint256 balanceAfter = MockERC20(_getAsset()).balanceOf(_getActor());

    //     lte(
    //         balanceAfter,
    //         balanceBefore,
    //         "User gained assets in deposit/withdrawal flow"
    //     );
    // }

    /// @dev Property: maxRedeem is reset to 0 after full redemption
    function doomsday_maxRedeemResetsAfterFullRedemption(
        uint256 sharesToMint
    ) public stateless {
        // 1. Deposit to get shares
        superVault.mint(sharesToMint, _getActor());

        uint256 shares = superVault.maxRedeem(_getActor());

        // 2. Request full redemption
        superVault.requestRedeem(shares, _getActor(), _getActor());

        // 3. Fulfill the redemption request
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createFulfillRedeemArgs(shares);
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 4. Check maxRedeem before claiming
        uint256 maxRedeemBeforeClaim = superVault.maxRedeem(_getActor());

        // 5. Claim the full redemption
        vm.prank(_getActor());
        try
            superVault.redeem(maxRedeemBeforeClaim, _getActor(), _getActor())
        {} catch {
            t(false, "redeem of maxRedeem should not revert");
        }

        // 6. Check maxRedeem is reset to 0 after full redemption
        uint256 maxRedeemAfterClaim = superVault.maxRedeem(_getActor());
        eq(
            maxRedeemAfterClaim,
            0,
            "maxRedeem should be reset to 0 after full redemption"
        );
    }

    /// @dev Property: maxWithdraw is reset to 0 after full withdrawal
    function doomsday_maxWithdrawResetsAfterFullWithdrawal(
        uint256 assetsToDeposit
    ) public stateless {
        // 1. Deposit to get shares
        superVault.deposit(assetsToDeposit, _getActor());

        uint256 shares = superVault.balanceOf(_getActor());

        // 2. Request redemption of all shares
        vm.prank(_getActor());
        superVault.requestRedeem(shares, _getActor(), _getActor());

        // 3. Fulfill the redemption request
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createFulfillRedeemArgs(shares);
        // called as admin address(this)
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 4. Check maxWithdraw after fulfillment and use that value
        uint256 maxWithdrawable = superVault.maxWithdraw(_getActor());

        // 5. Withdraw the exact amount returned by maxWithdraw
        vm.prank(_getActor());
        try
            superVault.withdraw(maxWithdrawable, _getActor(), _getActor())
        {} catch {
            t(false, "withdraw of maxWithdraw should not revert");
        }

        // 6. Check maxWithdraw is reset to 0 after full withdrawal
        uint256 maxWithdrawAfter = superVault.maxWithdraw(_getActor());
        eq(
            maxWithdrawAfter,
            0,
            "maxWithdraw should be reset to 0 after full withdrawal"
        );
    }

    /// @dev Property: fulfillRedeemRequests doesn't redeem more than requested for multiple actors
    function doomsday_fulfillDoesntOverRedeemMultipleActors(
        uint256[3] memory sharesToMint,
        uint256[3] memory actorIndexes
    ) public stateless {
        address[] memory actors = _getActors();
        if (actors.length < 3) return; // Need at least 3 actors for this test

        // Arrays to track actors and their requests
        address[] memory testActors = new address[](3);
        uint256[] memory requestedShares = new uint256[](3);
        uint256[] memory sharesBefore = new uint256[](3);

        // 1. Setup: Each actor deposits and requests redemption
        uint256 totalRequestedShares;
        for (uint256 i = 0; i < 3; i++) {
            // Get unique actor
            testActors[i] = actors[actorIndexes[i] % actors.length];

            // Mint shares for this actor
            if (sharesToMint[i] > 0) {
                vm.prank(testActors[i]);
                superVault.mint(sharesToMint[i], testActors[i]);
            }

            // Get actual share balance
            sharesBefore[i] = superVault.maxRedeem(testActors[i]);
            requestedShares[i] = sharesBefore[i];

            // Request redemption of all shares
            if (requestedShares[i] > 0) {
                vm.prank(testActors[i]);
                superVault.requestRedeem(
                    requestedShares[i],
                    testActors[i],
                    testActors[i]
                );
            }
            totalRequestedShares += requestedShares[i];
        }

        // 2. Create multi-actor FulfillArgs
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createMultiActorFulfillArgs(
                testActors,
                requestedShares
            );

        // 3. Calculate total pending before
        uint256 totalPendingBefore;
        for (uint256 i = 0; i < 3; i++) {
            totalPendingBefore += superVault.pendingRedeemRequest(
                0,
                testActors[i]
            );
        }

        // 4. Fulfill all redemption requests at once
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 5. Calculate total pending after
        uint256 totalPendingAfter;
        for (uint256 i = 0; i < 3; i++) {
            totalPendingAfter += superVault.pendingRedeemRequest(
                0,
                testActors[i]
            );
        }

        lte(
            totalPendingBefore - totalPendingAfter,
            totalRequestedShares,
            "Total shares redeemed must not exceed sum of requested shares"
        );
    }

    /// @dev Property: primary manager can always be replaced by governance via `changePrimaryManager`
    function doomsday_primaryManagerAlwaysChangeable() public stateless {
        address strategy = address(superVaultStrategy);
        address newManager = _getActor();

        // Since address(this) has SUPER_GOVERNOR_ROLE, this should always succeed
        try superGovernor.changePrimaryManager(strategy, newManager) {
            // Call succeeded - this is expected behavior
        } catch (bytes memory err) {
            bool expectedError;
            expectedError = checkError(err, "MANAGER_TAKEOVERS_FROZEN()"); // custom error
            t(
                !expectedError,
                "Primary manager should always be changeable if not paused"
            );
        }
    }

    /// @dev Property: All users should always be able to redeem unless the system is paused
    function doomsday_allUsersCanRedeem() public stateless {
        address[] memory actors = _getActors();
        bool paused = superVaultAggregator.isStrategyPaused(
            address(superVaultStrategy)
        );

        // try to redeem for all users that have redeemable assets
        for (uint256 i; i < actors.length; i++) {
            uint256 claimable = superVault.claimableRedeemRequest(0, actors[i]);

            if (claimable > 0 && !paused) {
                vm.prank(actors[i]);
                try
                    superVault.redeem(claimable, actors[i], actors[i])
                {} catch {
                    t(
                        false,
                        "users should always be able to redeem unless the system is paused"
                    );
                }
            }
        }
    }

    /// @dev Property: all users can withdraw (solvency)
    function doomsday_allUsersCanWithdraw() public stateless {
        address[] memory actors = _getActors();
        bool paused = superVaultAggregator.isStrategyPaused(
            address(superVaultStrategy)
        );

        // request redemption for all actors
        for (uint256 i; i < actors.length; i++) {
            uint256 redeemableShares = superVault.balanceOf(actors[i]);

            vm.prank(actors[i]);
            superVault.requestRedeem(redeemableShares, actors[i], actors[i]);
        }

        // fulfill redemption for all actors
        for (uint256 i; i < actors.length; i++) {
            uint256 redeemableShares = superVault.pendingRedeemRequest(
                0,
                actors[i]
            );

            // switch the actor
            _switchActor(i);

            ISuperVaultStrategy.FulfillArgs
                memory fulfillArgs = _fulfillRedeemRequestsArgs(
                    redeemableShares
                );
            superVaultStrategy.fulfillRedeemRequests(fulfillArgs);
        }

        // try to withdraw max possible for all actors
        for (uint256 i; i < actors.length; i++) {
            uint256 withdrawable = superVault.maxWithdraw(actors[i]);

            if (withdrawable > 0 && !paused) {
                vm.prank(actors[i]);
                try
                    superVault.withdraw(withdrawable, actors[i], actors[i])
                {} catch {
                    // if user can't maxWithdraw there's most likely an insolvency issue related to the TOLERANCE_CONSTANT
                    t(
                        false,
                        "users should always be able to withdraw unless the system is paused"
                    );
                }
            }
        }
    }

    /// @dev Property: Claiming redemptions should never revert with INVALID_REDEEM_CLAIM
    function doomsday_redemptionsNeverReverts(
        uint256 shares
    ) public asActor stateless {
        try superVault.redeem(shares, _getActor(), _getActor()) {} catch (
            bytes memory err
        ) {
            bool unexpectedError = checkError(err, "INVALID_REDEEM_CLAIM()");
            t(
                !unexpectedError,
                "Claiming redemptions should never revert with INVALID_REDEEM_CLAIM"
            );
        }
    }

    // Helpers

    /// @dev Helper function to clamp the values for the function call
    function _fulfillRedeemRequestsArgs(
        uint256 redeemAmount
    ) public returns (ISuperVaultStrategy.FulfillArgs memory fulfillArgs) {
        // Find a controller that has pending redeem requests
        address selectedController = _getActor();
        uint256 pendingAmount = superVaultStrategy.pendingRedeemRequest(
            selectedController
        );

        // Clamp using the actor's pending amount
        uint256 actualRedeemAmount = redeemAmount % (pendingAmount + 1);

        address[] memory controllers = new address[](1);
        controllers[0] = selectedController;

        // Determine yield source type from currently active yield source
        YieldSourceType activeYieldSourceType = _getYieldSourceTypeFromAddress(
            _getYieldSource()
        );
        address redeemHook = _getRedeemHookForType(activeYieldSourceType);

        // Create realistic hook calldata for redeem operation
        bytes memory redeemHookCalldata;

        if (
            activeYieldSourceType == YieldSourceType.ERC4626 ||
            activeYieldSourceType == YieldSourceType.ERC5115
        ) {
            // ERC4626/ERC5115 Layout: bytes32 oracleId, address yieldSource, address owner, uint256 shares, bool usePrevAmount
            redeemHookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Current active yield source
                address(superVaultStrategy), // Owner (strategy owns the yield source shares)
                actualRedeemAmount, // Amount to redeem (matches controller's pending request)
                false // Don't use previous hook amount
            );
        } else {
            // ERC7540 Layout: bytes32 oracleId, address yieldSource, uint256 shares, bool usePrevAmount
            redeemHookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Current active yield source
                actualRedeemAmount, // Amount to redeem (matches controller's pending request)
                false // Don't use previous hook amount
            );
        }

        // Create arrays for FulfillArgs
        address[] memory hooks = new address[](1);
        hooks[0] = redeemHook;

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = redeemHookCalldata;

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = actualRedeemAmount; // Expect amount matching the actual redeem

        bytes32[][] memory globalProofs = new bytes32[][](1);
        globalProofs[0] = new bytes32[](0); // Empty proof for UnsafeSuperVaultAggregator

        bytes32[][] memory strategyProofs = new bytes32[][](1);
        strategyProofs[0] = new bytes32[](0); // Empty proof

        // Create the FulfillArgs struct
        fulfillArgs = ISuperVaultStrategy.FulfillArgs({
            controllers: controllers,
            hooks: hooks,
            hookCalldata: hookCalldata,
            expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
            globalProofs: globalProofs,
            strategyProofs: strategyProofs
        });

        return fulfillArgs;
    }

    /// @dev Helper function to create FulfillArgs for multiple actors
    function _createMultiActorFulfillArgs(
        address[] memory controllers,
        uint256[] memory amounts
    ) internal view returns (ISuperVaultStrategy.FulfillArgs memory) {
        uint256 numActors = controllers.length;

        address[] memory hooks = new address[](numActors);
        bytes[] memory hookCalldata = new bytes[](numActors);
        uint256[] memory expectedAssetsOrSharesOut = new uint256[](numActors);
        bytes32[][] memory globalProofs = new bytes32[][](numActors);
        bytes32[][] memory strategyProofs = new bytes32[][](numActors);

        for (uint256 i = 0; i < numActors; i++) {
            hooks[i] = _getRedeemHookForType(
                _getYieldSourceTypeFromAddress(_getYieldSource())
            );

            if (
                _getYieldSourceTypeFromAddress(_getYieldSource()) ==
                YieldSourceType.ERC4626
            ) {
                hookCalldata[i] = abi.encodePacked(
                    bytes32(0),
                    _getYieldSource(),
                    address(superVaultStrategy),
                    amounts[i],
                    false
                );
            } else {
                hookCalldata[i] = abi.encodePacked(
                    bytes32(0),
                    _getYieldSource(),
                    amounts[i],
                    false
                );
            }

            expectedAssetsOrSharesOut[i] = amounts[i];
            globalProofs[i] = new bytes32[](0);
            strategyProofs[i] = new bytes32[](0);
        }

        return
            ISuperVaultStrategy.FulfillArgs({
                controllers: controllers,
                hooks: hooks,
                hookCalldata: hookCalldata,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: globalProofs,
                strategyProofs: strategyProofs
            });
    }

    /// @dev Helper function to create FulfillArgs for redeem requests
    function _createFulfillRedeemArgs(
        uint256 amount
    ) internal view returns (ISuperVaultStrategy.FulfillArgs memory) {
        address[] memory controllers = new address[](1);
        controllers[0] = _getActor();

        address[] memory hooks = new address[](1);
        hooks[0] = _getRedeemHookForType(
            _getYieldSourceTypeFromAddress(_getYieldSource())
        );

        bytes[] memory hookCalldata = new bytes[](1);
        if (
            _getYieldSourceTypeFromAddress(_getYieldSource()) ==
            YieldSourceType.ERC4626
        ) {
            hookCalldata[0] = abi.encodePacked(
                bytes32(0),
                _getYieldSource(),
                address(superVaultStrategy),
                amount,
                false
            );
        } else {
            hookCalldata[0] = abi.encodePacked(
                bytes32(0),
                _getYieldSource(),
                amount,
                false
            );
        }

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = amount;

        bytes32[][] memory globalProofs = new bytes32[][](1);
        globalProofs[0] = new bytes32[](0);

        bytes32[][] memory strategyProofs = new bytes32[][](1);
        strategyProofs[0] = new bytes32[](0);

        return
            ISuperVaultStrategy.FulfillArgs({
                controllers: controllers,
                hooks: hooks,
                hookCalldata: hookCalldata,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: globalProofs,
                strategyProofs: strategyProofs
            });
    }
}
