// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IBundlerRegistry {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the bundler address is invalid
    error INVALID_BUNDLER_ADDRESS();
    /// @notice Thrown when the bundler is already registered
    error BUNDLER_ALREADY_REGISTERED();
    /// @notice Thrown when the bundler is not found
    error BUNDLER_NOT_FOUND();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a bundler is registered
    event BundlerRegistered(address indexed bundler);
    /// @notice Emitted when the extra data of a bundler is updated
    event BundlerExtraDataUpdated(address indexed bundler, bytes extraData);
    /// @notice Emitted when the status of a bundler is changed
    event BundlerStatusChanged(address indexed bundler, bool isActive);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Bundler {
        address bundlerAddress; //address of the bundler
        bool isActive; //whether the bundler is active
        bytes extraData; //extra data for off-chain use
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Check if a bundler is registered
    /// @param bundler The address of the bundler
    /// @return True if the bundler is registered, false otherwise
    function isBundlerRegistered(address bundler) external view returns (bool);

    /// @notice Check if a bundler is active
    /// @param bundler The address of the bundler
    /// @return True if the bundler is active, false otherwise
    function isBundlerActive(address bundler) external view returns (bool);

    /// @notice Get a bundler by its address
    /// @param bundler The address of the bundler
    /// @return The bundler
    function getBundler(address bundler) external view returns (Bundler memory);
}
