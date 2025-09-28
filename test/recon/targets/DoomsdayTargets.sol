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

    /// @dev Property: mint/redeem doesn't cause loss to user
    function doomsday_mintRedeemSymmetrical(
        uint256 sharesToMint
    ) public stateless {
        // skip if there's been any gain because it complicates the assertion checking
        // NOTE: removed because was previously checking that user doesn't gain only from minting/redeeming
        // if (MockERC4626Tester(_getYieldSource()).totalGains() > 0) {
        //     return;
        // }
        address asset = superVault.asset();
        uint256 balanceBefore = MockERC20(asset).balanceOf(_getActor());

        // 1. Mint
        vm.prank(_getActor());
        superVault.mint(sharesToMint, _getActor());

        // 2. Request Redemption
        uint256 shares = superVault.balanceOf(_getActor());
        vm.prank(_getActor());
        superVault.requestRedeem(shares, _getActor(), _getActor());

        // 3. Fulfill Redemption
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createFulfillRedeemArgs(shares);
        // called by admin address(this)
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 4. Claim Redemption
        vm.prank(_getActor());
        superVault.redeem(shares, _getActor(), _getActor());

        uint256 balanceAfter = MockERC20(asset).balanceOf(_getActor());

        uint256 TOLERANCE = 10; // 10 wei max tolerance of assets lost
        // 5. Check that user didn't lose assets
        gte(
            balanceAfter + TOLERANCE,
            balanceBefore,
            "User loses assets in deposit/withdrawal flow"
        );
    }

    /// @dev Property: deposit/withdraw doesn't cause loss to user
    function doomsday_depositWithdrawSymmetrical(
        uint256 assetsToDeposit
    ) public stateless returns (uint256, uint256) {
        // skip if there's been any gain because it complicates the assertion checking
        // NOTE: removed because was previously checking that user doesn't gain only from minting/redeeming
        // if (MockERC4626Tester(_getYieldSource()).totalGains() > 0) {
        //     return;
        // }
        address asset = superVault.asset();
        uint256 balanceBefore = MockERC20(asset).balanceOf(_getActor());

        // 1. Deposit
        vm.prank(_getActor());
        superVault.deposit(assetsToDeposit, _getActor());

        // 2. Request Withdrawal (through redemption in ERC7540)
        uint256 shares = superVault.balanceOf(_getActor());
        vm.prank(_getActor());
        superVault.requestRedeem(shares, _getActor(), _getActor());

        // 3. Fulfill Withdrawal
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createFulfillRedeemArgs(shares);
        // fulfills as admin (address(this))
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 4. Claim Withdrawal
        uint256 withdrawableAssets = superVault.maxWithdraw(_getActor());
        vm.prank(_getActor());
        superVault.withdraw(withdrawableAssets, _getActor(), _getActor());

        uint256 balanceAfter = MockERC20(asset).balanceOf(_getActor());

        uint256 TOLERANCE = 10; // 10 wei max tolerance of assets lost
        // 5. Check that user didn't lose assets
        gte(
            balanceAfter + TOLERANCE,
            balanceBefore,
            "User loses assets in deposit/withdrawal flow"
        );

        return (balanceAfter, balanceBefore);
    }

    /// @dev Property: maxRedeem is reset to 0 after full redemption
    /// @dev Property: redeeming maxRedeem shouldn't revert
    function doomsday_maxRedeemResetsAfterFullRedemption(
        uint256 sharesToMint
    ) public stateless {
        // 1. Deposit to get shares
        vm.prank(_getActor());
        superVault.mint(sharesToMint, _getActor());

        // redeem all user shares
        uint256 shares = superVault.balanceOf(_getActor());

        // 2. Request full redemption
        vm.prank(_getActor());
        superVault.requestRedeem(shares, _getActor(), _getActor());

        // 3. Fulfill the redemption request
        ISuperVaultStrategy.FulfillArgs
            memory fulfillArgs = _createFulfillRedeemArgs(shares);
        // fulfill as address(this)
        superVaultStrategy.fulfillRedeemRequests(fulfillArgs);

        // 4. Check maxRedeem before claiming
        uint256 maxRedeemBeforeClaim = superVault.maxRedeem(_getActor());

        // 5. Claim the full redemption
        vm.prank(_getActor());
        try
            superVault.redeem(maxRedeemBeforeClaim, _getActor(), _getActor())
        {} catch {
            if (maxRedeemBeforeClaim > 0) {
                t(false, "redeeming maxRedeem should not revert");
            }
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
        vm.prank(_getActor());
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
        uint256 maxWithdrawBefore = superVault.maxWithdraw(_getActor());

        // 5. Withdraw the exact amount returned by maxWithdraw
        vm.prank(_getActor());
        try
            superVault.withdraw(maxWithdrawBefore, _getActor(), _getActor())
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
        // fulfill as address(this)
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
        vm.prank(address(this));
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
    // NOTE: if withdrawing from a given strategy via fulfillRedeemRequests fails, it can be expected that one of the YieldSourceTargets would be called to switch the yield source
    // this should allow fulfillments to eventually succeed so we don't need to sort through all yield sources that have currently been deposited into before fulfilling
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
