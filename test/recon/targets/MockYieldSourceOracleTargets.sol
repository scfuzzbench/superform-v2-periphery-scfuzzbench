// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "test/mocks/MockYieldSourceOracle.sol";
import "../mocks/MockERC4626YieldSourceOracle.sol";
import "../mocks/MockERC5115YieldSourceOracle.sol";
import "../mocks/MockERC7540YieldSourceOracle.sol";

abstract contract MockYieldSourceOracleTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    function yieldSourceOracle_setValidAsset_clamped() public {
        yieldSourceOracle_setValidAsset(_getAsset(), true);
    }

    function mockERC4626YieldSourceOracle_setValidAsset(
        address asset,
        bool isValid
    ) public asActor {
        MockERC4626YieldSourceOracle(address(erc4626YieldSourceOracle)).setValidAsset(asset, isValid);
    }

    function mockERC5115YieldSourceOracle_setValidAsset(
        address asset,
        bool isValid
    ) public asActor {
        MockERC5115YieldSourceOracle(address(erc5115YieldSourceOracle)).setValidAsset(asset, isValid);
    }

    function mockERC7540YieldSourceOracle_setValidAsset(
        address asset,
        bool isValid
    ) public asActor {
        MockERC7540YieldSourceOracle(address(erc7540YieldSourceOracle)).setValidAsset(asset, isValid);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function yieldSourceOracle_setPricePerShare(
        uint256 _pricePerShare
    ) public asActor {
        yieldSourceOracle.setPricePerShare(_pricePerShare);
    }

    function yieldSourceOracle_setTVL(uint256 _tvl) public asActor {
        yieldSourceOracle.setTVL(_tvl);
    }

    function yieldSourceOracle_setTVLByOwner(
        uint256 _tvlByOwner
    ) public asActor {
        yieldSourceOracle.setTVLByOwner(_tvlByOwner);
    }

    function yieldSourceOracle_setValidAsset(
        address asset,
        bool isValid
    ) public asActor {
        yieldSourceOracle.setValidAsset(asset, isValid);
    }

    function yieldSourceOracle_setValidity(bool _validity) public asActor {
        yieldSourceOracle.setValidity(_validity);
    }
}
