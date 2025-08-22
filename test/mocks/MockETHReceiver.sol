// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title MockETHReceiver
/// @author Superform Labs
/// @notice Simple contract to receive and track ETH for testing
contract MockETHReceiver {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Total ETH received
    uint256 public totalReceived;
    
    /// @notice Number of times ETH was received
    uint256 public receiveCount;
    
    /// @notice Event emitted when ETH is received
    event ETHReceived(address sender, uint256 amount, uint256 totalReceived);
    
    /// @notice Event emitted when execute function is called
    event ExecuteCalled(address indexed sender, uint256 value);

    IERC20 public immutable USDC;
    
    constructor(address usdc_) {
        USDC = IERC20(usdc_);
    }

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Simple execute function that can be called by hooks
    function execute() external payable {
        emit ExecuteCalled(msg.sender, msg.value);
        
        // Simulate yield generation by transferring USDC to the caller
        // Transfer an amount proportional to the ETH received
        if (msg.value > 0) {
            uint256 usdcAmount = msg.value / 1e12; // Convert from 18 decimals (ETH) to 6 decimals (USDC)
            if (USDC.balanceOf(address(this)) >= usdcAmount) {
                USDC.transfer(msg.sender, usdcAmount);
            }
            totalReceived += msg.value;
            receiveCount++;
        }
    }
    
    /// @notice Execute function with data parameter
    function executeWithData(bytes calldata) external payable {
        emit ExecuteCalled(msg.sender, msg.value);
        if (msg.value > 0) {
            totalReceived += msg.value;
            receiveCount++;
        }
    }
    
    /// @notice Reset counters for testing
    function reset() external {
        totalReceived = 0;
        receiveCount = 0;
    }
    
    /// @notice Withdraw all ETH (for cleanup)
    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTION
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Allows the contract to receive ETH
    receive() external payable {
        totalReceived += msg.value;
        receiveCount++;
        emit ETHReceived(msg.sender, msg.value, totalReceived);
    }
}
