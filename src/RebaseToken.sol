//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Andry Narson
 * @notice This is a cross-chian rebase token tha recencidevises user to deposit into a vault and gain interest in rewards
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposing
 */
contract RebaseToken is ERC20 {
    /*error*/
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 s_interestRate,
        uint256 _newInterestRate
    );

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;

    /*event*/
    event InterestRareSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    /**
     * @notice Set the interest Rate in the contract
     * @param _newInterestRate the new interest rate to set
     * @dev the new interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external {
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit InterestRareSet(_newInterestRate);
    }

    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdate(_user)) /
            PRECISION_FACTOR;
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp -
            s_userLastUpdatedTimeStamp[_user];
        linearInterest = (PRECISION_FACTOR +
            (s_userInterestRate[_user] * timeElapsed));
    }
    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;

        _mint(_user, balanceIncrease);
    }

    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }
}
