// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BundlerRegistry } from "../../../src/BundlerRegistry.sol";
import { IBundlerRegistry } from "../../../src/interfaces/IBundlerRegistry.sol";
import { PeripheryHelpers } from "../../utils/PeripheryHelpers.sol";

contract BundlerRegistryTest is PeripheryHelpers {
    BundlerRegistry public bundlerRegistry;
    address public BUNDLER;
    bytes public constant EXTRA_DATA = "test_data";
    address public constant NEW_BUNDLER_ADDRESS = address(0x456);
    bytes public constant NEW_EXTRA_DATA = "new_test_data";

    event BundlerRegistered(address indexed bundlerAddress);
    event BundlerExtraDataUpdated(address indexed bundlerAddress, bytes extraData);
    event BundlerStatusChanged(address indexed bundlerAddress, bool isActive);

    function setUp() public {
        // Deploy BundlerRegistry with owner as this contract
        bundlerRegistry = new BundlerRegistry(address(this));
        BUNDLER = address(this);
    }

    function test_RegisterBundler() public {
        bundlerRegistry.registerBundler(BUNDLER, EXTRA_DATA);

        // Get the bundler data
        IBundlerRegistry.Bundler memory bundler = bundlerRegistry.getBundler(BUNDLER);

        // Verify registration
        assertTrue(bundlerRegistry.isBundlerRegistered(BUNDLER), "Bundler should be registered");
        assertTrue(bundlerRegistry.isBundlerActive(BUNDLER), "Bundler should be active");
        assertEq(bundler.bundlerAddress, BUNDLER, "Bundler address mismatch");
        assertEq(bundler.extraData, EXTRA_DATA, "Extra data mismatch");
        assertTrue(bundler.isActive, "Bundler should be active");

        vm.stopPrank();
    }

    function test_UpdateBundlerExtraData() public {
        // First register a bundler
        bundlerRegistry.registerBundler(BUNDLER, EXTRA_DATA);

        // Update extra data
        vm.expectEmit(true, false, false, true);
        emit BundlerExtraDataUpdated(BUNDLER, NEW_EXTRA_DATA);

        bundlerRegistry.updateBundlerExtraData(BUNDLER, NEW_EXTRA_DATA);

        // Verify update
        IBundlerRegistry.Bundler memory updatedBundler = bundlerRegistry.getBundler(BUNDLER);
        assertEq(updatedBundler.extraData, NEW_EXTRA_DATA, "Extra data not updated");
    }

    function test_UpdateBundlerStatus() public {
        // First register a bundler
        bundlerRegistry.registerBundler(BUNDLER, EXTRA_DATA);

        // Update status to inactive
        vm.expectEmit(true, false, false, true);
        emit BundlerStatusChanged(BUNDLER, false);

        bundlerRegistry.updateBundlerStatus(BUNDLER, false);

        // Verify update
        assertFalse(bundlerRegistry.isBundlerActive(BUNDLER), "Bundler should be inactive");
        IBundlerRegistry.Bundler memory updatedBundler = bundlerRegistry.getBundler(BUNDLER);
        assertFalse(updatedBundler.isActive, "Bundler status not updated");
    }

    function test_RevertWhen_UnauthorizedRegister() public {
        // Try to register from non-owner address
        address nonOwner = address(0x789);
        vm.prank(nonOwner);
        vm.expectRevert();
        bundlerRegistry.registerBundler(BUNDLER, EXTRA_DATA);
    }

    function test_RevertWhen_UnauthorizedUpdate() public {
        // First register a bundler
        bundlerRegistry.registerBundler(BUNDLER, EXTRA_DATA);

        // Try to update from non-owner address
        address nonOwner = address(0x789);
        vm.startPrank(nonOwner);

        vm.expectRevert();
        bundlerRegistry.updateBundlerExtraData(BUNDLER, NEW_EXTRA_DATA);

        vm.expectRevert();
        bundlerRegistry.updateBundlerStatus(BUNDLER, false);

        vm.stopPrank();
    }

    function test_GetNonExistentBundler() public view {
        // Try to get a non-existent bundler
        IBundlerRegistry.Bundler memory nonExistentBundler = bundlerRegistry.getBundler(address(0x999));
        assertEq(nonExistentBundler.bundlerAddress, address(0), "Non-existent bundler should have zero address");
        assertFalse(nonExistentBundler.isActive, "Non-existent bundler should be inactive");
    }

    function test_RevertWhen_RegisterBundlerWithZeroAddress() public {
        vm.expectRevert(IBundlerRegistry.INVALID_BUNDLER_ADDRESS.selector);
        bundlerRegistry.registerBundler(address(0), EXTRA_DATA);
    }

    function test_RevertWhen_UpdateBundlerExtraDataWithInvalidAddress() public {
        address invalidBundlerAddress = address(0x999);

        vm.expectRevert(IBundlerRegistry.BUNDLER_NOT_FOUND.selector);
        bundlerRegistry.updateBundlerExtraData(invalidBundlerAddress, NEW_EXTRA_DATA);
    }

    function test_RevertWhen_UpdateBundlerStatusWithInvalidAddress() public {
        address invalidBundlerAddress = address(0x999);

        vm.expectRevert(IBundlerRegistry.BUNDLER_NOT_FOUND.selector);
        bundlerRegistry.updateBundlerStatus(invalidBundlerAddress, false);
    }

    function test_RevertWhen_RegisterAlreadyRegisteredBundler() public {
        // First register a bundler
        bundlerRegistry.registerBundler(BUNDLER, EXTRA_DATA);

        // Try to register the same bundler again
        vm.expectRevert(IBundlerRegistry.BUNDLER_ALREADY_REGISTERED.selector);
        bundlerRegistry.registerBundler(BUNDLER, NEW_EXTRA_DATA);
    }
}
