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

    function invariant_assertion_failure_REDEEM_MAX_REDEEM_SHOULD_NOT_REVERT()
        public
        view
    {
        assertTrue(
            !assertionFailures[ASSERTION_REDEEM_MAX_REDEEM_SHOULD_NOT_REVERT],
            ASSERTION_REDEEM_MAX_REDEEM_SHOULD_NOT_REVERT
        );
    }

    function invariant_assertion_failure_WITHDRAW_MAX_WITHDRAW_SHOULD_NOT_REVERT()
        public
        view
    {
        assertTrue(
            !assertionFailures[
                ASSERTION_WITHDRAW_MAX_WITHDRAW_SHOULD_NOT_REVERT
            ],
            ASSERTION_WITHDRAW_MAX_WITHDRAW_SHOULD_NOT_REVERT
        );
    }

    function invariant_assertion_failure_PRIMARY_MANAGER_ALWAYS_CHANGEABLE()
        public
        view
    {
        assertTrue(
            !assertionFailures[ASSERTION_PRIMARY_MANAGER_ALWAYS_CHANGEABLE],
            ASSERTION_PRIMARY_MANAGER_ALWAYS_CHANGEABLE
        );
    }

    function invariant_assertion_failure_ALL_USERS_CAN_WITHDRAW_WHEN_UNPAUSED()
        public
        view
    {
        assertTrue(
            !assertionFailures[ASSERTION_ALL_USERS_CAN_WITHDRAW_WHEN_UNPAUSED],
            ASSERTION_ALL_USERS_CAN_WITHDRAW_WHEN_UNPAUSED
        );
    }

    function invariant_assertion_failure_REDEEM_SHOULD_NOT_REVERT_INVALID_REDEEM_CLAIM()
        public
        view
    {
        assertTrue(
            !assertionFailures[
                ASSERTION_REDEEM_SHOULD_NOT_REVERT_INVALID_REDEEM_CLAIM
            ],
            ASSERTION_REDEEM_SHOULD_NOT_REVERT_INVALID_REDEEM_CLAIM
        );
    }

    function invariant_assertion_failure_UPDATE_SHOULD_NOT_REVERT_TRANSFER()
        public
        view
    {
        assertTrue(
            !assertionFailures[ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER],
            ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER
        );
    }

    function invariant_assertion_failure_UPDATE_SHOULD_NOT_REVERT_TRANSFER_FROM()
        public
        view
    {
        assertTrue(
            !assertionFailures[
                ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER_FROM
            ],
            ASSERTION_UPDATE_SHOULD_NOT_REVERT_TRANSFER_FROM
        );
    }

    function invariant_assertion_failure_PREVIEW_DEPOSIT_EQUIVALENCE()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_PREVIEW_DEPOSIT_EQUIVALENCE);
    }

    function invariant_assertion_failure_PREVIEW_MINT_EQUIVALENCE()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_PREVIEW_MINT_EQUIVALENCE);
    }

    function invariant_assertion_failure_MINT_REDEEM_SYMMETRICAL()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_MINT_REDEEM_SYMMETRICAL);
    }

    function invariant_assertion_failure_DEPOSIT_WITHDRAW_SYMMETRICAL()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_DEPOSIT_WITHDRAW_SYMMETRICAL);
    }

    function invariant_assertion_failure_MAX_REDEEM_RESETS_AFTER_FULL_REDEMPTION()
        public
        view
    {
        _assertNoAssertionFailure(
            ASSERTION_MAX_REDEEM_RESETS_AFTER_FULL_REDEMPTION
        );
    }

    function invariant_assertion_failure_MAX_WITHDRAW_RESETS_AFTER_FULL_WITHDRAWAL()
        public
        view
    {
        _assertNoAssertionFailure(
            ASSERTION_MAX_WITHDRAW_RESETS_AFTER_FULL_WITHDRAWAL
        );
    }

    function invariant_assertion_failure_FULFILL_DOESNT_OVER_REDEEM_MULTIPLE_ACTORS()
        public
        view
    {
        _assertNoAssertionFailure(
            ASSERTION_FULFILL_DOESNT_OVER_REDEEM_MULTIPLE_ACTORS
        );
    }

    function invariant_assertion_failure_CANCEL_REDEEM_PENDING_REQUEST_ZERO()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_CANCEL_REDEEM_PENDING_REQUEST_ZERO);
    }

    function invariant_assertion_failure_CANCEL_REDEEM_AVG_REQUEST_PPS_ZERO()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_CANCEL_REDEEM_AVG_REQUEST_PPS_ZERO);
    }

    function invariant_assertion_failure_CANCEL_REDEEM_NO_OVERPAY()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_CANCEL_REDEEM_NO_OVERPAY);
    }

    function invariant_assertion_failure_PREVIEW_DEPOSIT_MATCHES_EXECUTION()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_PREVIEW_DEPOSIT_MATCHES_EXECUTION);
    }

    function invariant_assertion_failure_PREVIEW_MINT_MATCHES_EXECUTION()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_PREVIEW_MINT_MATCHES_EXECUTION);
    }

    function invariant_assertion_failure_TRANSFER_SHARES_CONSERVED()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_TRANSFER_SHARES_CONSERVED);
    }

    function invariant_assertion_failure_TRANSFER_COST_BASIS_CONSERVED()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_TRANSFER_COST_BASIS_CONSERVED);
    }

    function invariant_assertion_failure_STRATEGY_NO_LOSS_ON_FULFILLMENT()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_STRATEGY_NO_LOSS_ON_FULFILLMENT);
    }

    function invariant_assertion_failure_GLOBAL_PREVIEW_EQUIVALENCE_FROM_SHARES()
        public
        view
    {
        _assertNoAssertionFailure(ASSERTION_GLOBAL_PREVIEW_EQUIVALENCE_FROM_SHARES);
    }

    function invariant_assertion_failure_GLOBAL_PREVIEW_EQUIVALENCE_UNDER_FROM_ASSETS()
        public
        view
    {
        _assertNoAssertionFailure(
            ASSERTION_GLOBAL_PREVIEW_EQUIVALENCE_UNDER_FROM_ASSETS
        );
    }

    function invariant_assertion_failure_GLOBAL_PREVIEW_EQUIVALENCE_OVER_FROM_ASSETS()
        public
        view
    {
        _assertNoAssertionFailure(
            ASSERTION_GLOBAL_PREVIEW_EQUIVALENCE_OVER_FROM_ASSETS
        );
    }

    function invariant_assertion_failure_GLOBAL_PREVIEW_MINT_GTE_CONVERT_TO_ASSETS()
        public
        view
    {
        _assertNoAssertionFailure(
            ASSERTION_GLOBAL_PREVIEW_MINT_GTE_CONVERT_TO_ASSETS
        );
    }

    function invariant_assertion_failure_GLOBAL_CONVERT_TO_SHARES_GTE_PREVIEW_DEPOSIT()
        public
        view
    {
        _assertNoAssertionFailure(
            ASSERTION_GLOBAL_CONVERT_TO_SHARES_GTE_PREVIEW_DEPOSIT
        );
    }

    function invariant_assertion_failure_ERC7540_4_DEPOSIT() public view {
        _assertNoAssertionFailure(ASSERTION_ERC7540_4_DEPOSIT);
    }

    function invariant_assertion_failure_ERC7540_4_MINT() public view {
        _assertNoAssertionFailure(ASSERTION_ERC7540_4_MINT);
    }

    function invariant_assertion_failure_ERC7540_4_WITHDRAW() public view {
        _assertNoAssertionFailure(ASSERTION_ERC7540_4_WITHDRAW);
    }

    function invariant_assertion_failure_ERC7540_4_REDEEM() public view {
        _assertNoAssertionFailure(ASSERTION_ERC7540_4_REDEEM);
    }

    function invariant_assertion_failure_ERC7540_5() public view {
        _assertNoAssertionFailure(ASSERTION_ERC7540_5);
    }

    function invariant_assertion_failure_ERC7540_7_WITHDRAW() public view {
        _assertNoAssertionFailure(ASSERTION_ERC7540_7_WITHDRAW);
    }

    function invariant_assertion_failure_ERC7540_7_REDEEM() public view {
        _assertNoAssertionFailure(ASSERTION_ERC7540_7_REDEEM);
    }

    function invariant_assertion_failure_CANARY()
        public
        view
    {
        assertTrue(
            !assertionFailures[ASSERTION_CANARY],
            ASSERTION_CANARY
        );
    }

    function invariant_noop() public view {}
}
