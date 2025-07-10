// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external

import { Helpers } from "@superform-v2-core/test/utils/Helpers.sol";

import { PeripheryConstants } from "./PeripheryConstants.sol";

abstract contract PeripheryHelpers is PeripheryConstants, Helpers {
    address public SV_MANAGER;
    address public STRATEGIST;
    address public EMERGENCY_ADMIN;
    address public VALIDATOR;

    function deployPeripheryAccounts() public {
        // deploy accounts
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");
        VALIDATOR = _deployAccount(VALIDATOR_KEY, "VALIDATOR");
    }
}
