//SPDX-License_Identifier: MIT
pragma solidity ^0.8.28;

import {IRebaseToken} from "src/Interfaces/IRebaseToken.sol";

contract Vault {
    /* Error */
    error Vault_RedeemFailed();

    IRebaseToken private immutable i_RebaseToken;

    /* event */
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_RebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_RebaseToken);
    }

    function deposit() external payable {
        i_RebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external {
        i_RebaseToken.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault_RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }
}
