// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { IBundlerRegistry } from "./interfaces/IBundlerRegistry.sol";

contract BundlerRegistry is IBundlerRegistry, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address bundlerAddress => Bundler bundlerData) public bundlers;

    constructor(address owner_) Ownable(owner_) { }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IBundlerRegistry
    function isBundlerRegistered(address bundler) external view returns (bool) {
        return bundlers[bundler].bundlerAddress != address(0);
    }

    /// @inheritdoc IBundlerRegistry
    function isBundlerActive(address bundler) external view returns (bool) {
        return bundlers[bundler].isActive;
    }

    /// @inheritdoc IBundlerRegistry
    function getBundler(address bundler) external view returns (Bundler memory) {
        return bundlers[bundler];
    }

    /*//////////////////////////////////////////////////////////////
                                OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Register a new bundler
    /// @param bundlerAddress The address of the bundler
    /// @param _extraData Extra data for off-chain use
    function registerBundler(address bundlerAddress, bytes calldata _extraData) external onlyOwner {
        // Input validation
        if (bundlerAddress == address(0)) revert INVALID_BUNDLER_ADDRESS();
        if (bundlers[bundlerAddress].bundlerAddress != address(0)) revert BUNDLER_ALREADY_REGISTERED();

        IBundlerRegistry.Bundler memory bundler =
            IBundlerRegistry.Bundler({ bundlerAddress: bundlerAddress, isActive: true, extraData: _extraData });

        bundlers[bundlerAddress] = bundler;

        emit BundlerRegistered(bundlerAddress);
    }

    /// @notice Update a bundler's extra data
    /// @param bundlerAddress The address of the bundler
    /// @param _extraData The new extra data for the bundler
    function updateBundlerExtraData(address bundlerAddress, bytes calldata _extraData) external onlyOwner {
        if (bundlers[bundlerAddress].bundlerAddress == address(0)) revert BUNDLER_NOT_FOUND();

        bundlers[bundlerAddress].extraData = _extraData;

        emit BundlerExtraDataUpdated(bundlerAddress, _extraData);
    }

    /// @notice Update a bundler's status
    /// @param bundlerAddress The address of the bundler
    /// @param _isActive The new status of the bundler
    function updateBundlerStatus(address bundlerAddress, bool _isActive) external onlyOwner {
        if (bundlers[bundlerAddress].bundlerAddress == address(0)) revert BUNDLER_NOT_FOUND();

        bundlers[bundlerAddress].isActive = _isActive;

        emit BundlerStatusChanged(bundlerAddress, _isActive);
    }
}
