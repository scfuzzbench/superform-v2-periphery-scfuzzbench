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
