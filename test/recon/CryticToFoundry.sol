// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {Asserts} from "@chimera/Asserts.sol";

import {Test} from "forge-std/Test.sol";
import {TargetFunctions} from "./TargetFunctions.sol";

// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    mapping(string => bool) private assertionFailures;

    function setUp() public {
        setup();

        // Route invariant fuzzing through handlers on this contract.
        targetContract(address(this));
        targetSender(address(0x10000));
        targetSender(address(0x20000));
        targetSender(address(0x30000));
    }

    function _isAssertion(string memory reason) internal pure returns (bool) {
        return
            bytes(reason).length >= 3 &&
            bytes(reason)[0] == '!' &&
            bytes(reason)[1] == '!' &&
            bytes(reason)[2] == '!';
    }

    function gt(
        uint256 a,
        uint256 b,
        string memory reason
    ) internal virtual override(FoundryAsserts, Asserts) {
        if (_isAssertion(reason)) {
            _recordAssertion(a > b, reason);
        } else {
            super.gt(a, b, reason);
        }
    }

    function gte(
        uint256 a,
        uint256 b,
        string memory reason
    ) internal virtual override(FoundryAsserts, Asserts) {
        if (_isAssertion(reason)) {
            _recordAssertion(a >= b, reason);
        } else {
            super.gte(a, b, reason);
        }
    }

    function lt(
        uint256 a,
        uint256 b,
        string memory reason
    ) internal virtual override(FoundryAsserts, Asserts) {
        if (_isAssertion(reason)) {
            _recordAssertion(a < b, reason);
        } else {
            super.lt(a, b, reason);
        }
    }

    function lte(
        uint256 a,
        uint256 b,
        string memory reason
    ) internal virtual override(FoundryAsserts, Asserts) {
        if (_isAssertion(reason)) {
            _recordAssertion(a <= b, reason);
        } else {
            super.lte(a, b, reason);
        }
    }

    function eq(
        uint256 a,
        uint256 b,
        string memory reason
    ) internal virtual override(FoundryAsserts, Asserts) {
        if (_isAssertion(reason)) {
            _recordAssertion(a == b, reason);
        } else {
            super.eq(a, b, reason);
        }
    }

    function t(
        bool b,
        string memory reason
    ) internal virtual override(FoundryAsserts, Asserts) {
        if (_isAssertion(reason)) {
            _recordAssertion(b, reason);
        } else {
            super.t(b, reason);
        }
    }

    function _recordAssertion(bool ok, string memory reason) internal {
        if (ok) {
            return;
        }

        assertionFailures[reason] = true;
    }

    function _assertNoAssertionFailure(string memory reason) internal view {
        assertTrue(!assertionFailures[reason], reason);
    }

    function invariant_assertion_failure_doomsday_primaryManagerAlwaysChangeable_ASSERTION_PRIMARY_MANAGER_ALWAYS_CHANGEABLE()
        public
        returns (bool)
    {
        assertTrue(
            !assertionFailures[ASSERTION_PRIMARY_MANAGER_ALWAYS_CHANGEABLE],
            ASSERTION_PRIMARY_MANAGER_ALWAYS_CHANGEABLE
        );
        return true;
    }

    function invariant_assertion_failure_doomsday_allUsersCanWithdraw_ASSERTION_ALL_USERS_CAN_WITHDRAW_WHEN_UNPAUSED()
        public
        returns (bool)
    {
        assertTrue(
            !assertionFailures[ASSERTION_ALL_USERS_CAN_WITHDRAW_WHEN_UNPAUSED],
            ASSERTION_ALL_USERS_CAN_WITHDRAW_WHEN_UNPAUSED
        );
        return true;
    }

    function invariant_assertion_failure_doomsday_redemptionsNeverReverts_ASSERTION_REDEEM_SHOULD_NOT_REVERT_INVALID_REDEEM_CLAIM()
        public
        returns (bool)
    {
        assertTrue(
            !assertionFailures[
                ASSERTION_REDEEM_SHOULD_NOT_REVERT_INVALID_REDEEM_CLAIM
            ],
            ASSERTION_REDEEM_SHOULD_NOT_REVERT_INVALID_REDEEM_CLAIM
        );
        return true;
    }

    function invariant_assertion_failure_superVault_transferFrom_ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER_FROM()
        public
        returns (bool)
    {
        assertTrue(
            !assertionFailures[
                ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER_FROM
            ],
            ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER_FROM
        );
        return true;
    }

    function invariant_assertion_failure_doomsday_previewDepositEquivalence_ASSERTION_PREVIEW_DEPOSIT_EQUIVALENCE()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_PREVIEW_DEPOSIT_EQUIVALENCE);
        return true;
    }

    function invariant_assertion_failure_doomsday_previewMintEquivalence_ASSERTION_PREVIEW_MINT_EQUIVALENCE()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_PREVIEW_MINT_EQUIVALENCE);
        return true;
    }

    function invariant_assertion_failure_doomsday_mintRedeemSymmetrical_ASSERTION_MINT_REDEEM_SYMMETRICAL()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_MINT_REDEEM_SYMMETRICAL);
        return true;
    }

    function invariant_assertion_failure_doomsday_depositWithdrawSymmetrical_ASSERTION_DEPOSIT_WITHDRAW_SYMMETRICAL()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_DEPOSIT_WITHDRAW_SYMMETRICAL);
        return true;
    }

    function invariant_assertion_failure_doomsday_maxRedeemResetsAfterFullRedemption_ASSERTION_MAX_REDEEM_RESETS_AFTER_FULL_REDEMPTION()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(
            ASSERTION_MAX_REDEEM_RESETS_AFTER_FULL_REDEMPTION
        );
        return true;
    }

    function invariant_assertion_failure_doomsday_maxWithdrawResetsAfterFullWithdrawal_ASSERTION_MAX_WITHDRAW_RESETS_AFTER_FULL_WITHDRAWAL()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(
            ASSERTION_MAX_WITHDRAW_RESETS_AFTER_FULL_WITHDRAWAL
        );
        return true;
    }

    function invariant_assertion_failure_doomsday_fulfillDoesntOverRedeemMultipleActors_ASSERTION_FULFILL_DOESNT_OVER_REDEEM_MULTIPLE_ACTORS()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(
            ASSERTION_FULFILL_DOESNT_OVER_REDEEM_MULTIPLE_ACTORS
        );
        return true;
    }

    function invariant_assertion_failure_superVault_cancelRedeem_ASSERTION_CANCEL_REDEEM_NO_OVERPAY()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_CANCEL_REDEEM_NO_OVERPAY);
        return true;
    }

    function invariant_assertion_failure_superVault_deposit_ASSERTION_PREVIEW_DEPOSIT_MATCHES_EXECUTION()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_PREVIEW_DEPOSIT_MATCHES_EXECUTION);
        return true;
    }

    function invariant_assertion_failure_superVault_mint_ASSERTION_PREVIEW_MINT_MATCHES_EXECUTION()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_PREVIEW_MINT_MATCHES_EXECUTION);
        return true;
    }

    function invariant_assertion_failure_superVault_transfer_ASSERTION_TRANSFER_SHARES_CONSERVED()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_TRANSFER_SHARES_CONSERVED);
        return true;
    }

    function invariant_assertion_failure_superVaultStrategy_fulfillRedeemRequests_ASSERTION_STRATEGY_NO_LOSS_ON_FULFILLMENT()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_STRATEGY_NO_LOSS_ON_FULFILLMENT);
        return true;
    }

    function invariant_assertion_failure_global_previewEquivalenceFromShares_ASSERTION_GLOBAL_PREVIEW_EQUIVALENCE_FROM_SHARES()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(ASSERTION_GLOBAL_PREVIEW_EQUIVALENCE_FROM_SHARES);
        return true;
    }

    function invariant_assertion_failure_global_previewEquivalenceFromAssets_ASSERTION_GLOBAL_PREVIEW_EQUIVALENCE_FROM_ASSETS()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(
            ASSERTION_GLOBAL_PREVIEW_EQUIVALENCE_FROM_ASSETS
        );
        return true;
    }

    function invariant_assertion_failure_global_comparePreviewMintAndConvertToAssets_ASSERTION_GLOBAL_PREVIEW_MINT_GTE_CONVERT_TO_ASSETS()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(
            ASSERTION_GLOBAL_PREVIEW_MINT_GTE_CONVERT_TO_ASSETS
        );
        return true;
    }

    function invariant_assertion_failure_global_comparePreviewDepositAndConvertToShares_ASSERTION_GLOBAL_CONVERT_TO_SHARES_GTE_PREVIEW_DEPOSIT()
        public
        returns (bool)
    {
        _assertNoAssertionFailure(
            ASSERTION_GLOBAL_CONVERT_TO_SHARES_GTE_PREVIEW_DEPOSIT
        );
        return true;
    }

    function invariant_assertion_failure_global_erc7540_4_deposit_ASSERTION_ERC7540_4_DEPOSIT() public returns (bool) {
        _assertNoAssertionFailure(ASSERTION_ERC7540_4_DEPOSIT);
        return true;
    }

    function invariant_assertion_failure_global_erc7540_4_mint_ASSERTION_ERC7540_4_MINT() public returns (bool) {
        _assertNoAssertionFailure(ASSERTION_ERC7540_4_MINT);
        return true;
    }

    function invariant_assertion_failure_global_erc7540_4_withdraw_ASSERTION_ERC7540_4_WITHDRAW() public returns (bool) {
        _assertNoAssertionFailure(ASSERTION_ERC7540_4_WITHDRAW);
        return true;
    }

    function invariant_assertion_failure_global_erc7540_4_redeem_ASSERTION_ERC7540_4_REDEEM() public returns (bool) {
        _assertNoAssertionFailure(ASSERTION_ERC7540_4_REDEEM);
        return true;
    }

    function invariant_assertion_failure_global_erc7540_5_ASSERTION_ERC7540_5() public returns (bool) {
        _assertNoAssertionFailure(ASSERTION_ERC7540_5);
        return true;
    }

    function invariant_assertion_failure_global_erc7540_7_withdraw_ASSERTION_ERC7540_7_WITHDRAW() public returns (bool) {
        _assertNoAssertionFailure(ASSERTION_ERC7540_7_WITHDRAW);
        return true;
    }

    function invariant_assertion_failure_global_erc7540_7_redeem_ASSERTION_ERC7540_7_REDEEM() public returns (bool) {
        _assertNoAssertionFailure(ASSERTION_ERC7540_7_REDEEM);
        return true;
    }

    function invariant_assertion_failure_assert_canary_ASSERTION_CANARY()
        public
        returns (bool)
    {
        assertTrue(
            !assertionFailures[ASSERTION_CANARY],
            ASSERTION_CANARY
        );
        return true;
    }

    function invariant_noop() public returns (bool) {
        return true;
    }
}
