// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// External dependencies
import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";

// Source dependencies
import {IECDSAPPSOracle} from "src/interfaces/oracles/IECDSAPPSOracle.sol";
import "test/mocks/MockYieldSourceOracle.sol";
import "../mocks/MockERC4626YieldSourceOracle.sol";
import "../mocks/MockERC5115YieldSourceOracle.sol";
import "../mocks/MockERC7540YieldSourceOracle.sol";

// Test suite dependencies
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";

abstract contract OracleTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    function yieldSourceOracle_setValidAsset_clamped() public {
        mockERC4626YieldSourceOracle_setValidAsset(_getAsset(), true);
    }

    function mockERC4626YieldSourceOracle_setValidAsset(
        address asset,
        bool isValid
    ) public asActor {
        MockERC4626YieldSourceOracle(address(erc4626YieldSourceOracle))
            .setValidAsset(asset, isValid);
    }

    function mockERC5115YieldSourceOracle_setValidAsset(
        address asset,
        bool isValid
    ) public asActor {
        MockERC5115YieldSourceOracle(address(erc5115YieldSourceOracle))
            .setValidAsset(asset, isValid);
    }

    function mockERC7540YieldSourceOracle_setValidAsset(
        address asset,
        bool isValid
    ) public asActor {
        MockERC7540YieldSourceOracle(address(erc7540YieldSourceOracle))
            .setValidAsset(asset, isValid);
    }

    function ECDSAPPSOracle_updatePPS_clamped(uint256 pps) public {
        IECDSAPPSOracle.UpdatePPSArgs memory args = IECDSAPPSOracle
            .UpdatePPSArgs({
                strategy: address(superVaultStrategy),
                proofs: new bytes[](0),
                pps: pps,
                ppsStdev: 0,
                validatorSet: 0,
                totalValidators: 0,
                timestamp: block.timestamp
            });

        ECDSAPPSOracle_updatePPS(args);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
    function ECDSAPPSOracle_updatePPS(
        IECDSAPPSOracle.UpdatePPSArgs memory args
    ) public asActor {
        ECDSAPPSOracle.updatePPS(args);
    }

    /// @dev Missing coverage over this for now while there's only one vault triad is okay
    // since ECDSAPPSOracle_updatePPS_clamped already allows updating price for the deployed strategy
    function ECDSAPPSOracle_batchUpdatePPS(
        IECDSAPPSOracle.BatchUpdatePPSArgs memory args
    ) public asActor {
        ECDSAPPSOracle.batchUpdatePPS(args);
    }
}
