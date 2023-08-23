// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {BaseTokenizedStrategy} from "@tokenized-strategy/BaseTokenizedStrategy.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract YearnBaseStrategy is BaseTokenizedStrategy {
    using SafeERC20 for ERC20;

    modifier HealthCheck() {
        _healthCheckPricePerShare();
        _;
    }

    function _healthCheckPricePerShare() internal {
        uint256 pricePerShare = TokenizedStrategy.pricePerShare();
        require(pricePerShare >= lastPricePerShare, "PPS");
        lastPricePerShare = pricePerShare;
    }

    address public constant yChad = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;

    uint256 internal constant MAX_BPS = 10_000;

    uint256 public depositLimit = type(uint256).max;

    bool public paused;

    uint256 public maxWithdrawLoss = 1;

    uint256 public lastPricePerShare;

    constructor(
        address _asset,
        string memory _name
    ) BaseTokenizedStrategy(_asset, _name) {
        lastPricePerShare = TokenizedStrategy.pricePerShare();
    }

    /*//////////////////////////////////////////////////////////////
                NEEDED TO BE OVERRIDEN BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Should deploy up to '_amount' of 'asset' in the yield source.
     *
     * This function is called at the end of a {deposit} or {mint}
     * call. Meaning that unless a whitelist is implemented it will
     * be entirely permsionless and thus can be sandwhiched or otherwise
     * manipulated.
     *
     * @param _amount The amount of 'asset' that the strategy should attemppt
     * to deposit in the yield source.
     */
    function _deployFunds(uint256 _amount) internal override HealthCheck {
        /**
            DEPOSIT LOGIC
         */
    }

    /**
     * @dev Will attempt to free the '_amount' of 'asset'.
     *
     * The amount of 'asset' that is already loose has already
     * been accounted for.
     *
     * This function is called during {withdraw} and {redeem} calls.
     * Meaning that unless a whitelist is implemented it will be
     * entirely permsionless and thus can be sandwhiched or otherwise
     * manipulated.
     *
     * Should not rely on asset.balanceOf(address(this)) calls other than
     * for diff accounting puroposes.
     *
     * Any difference between `_amount` and what is actually freed will be
     * counted as a loss and passed on to the withdrawer. This means
     * care should be taken in times of illiquidity. It may be better to revert
     * if withdraws are simply illiquid so not to realize incorrect losses.
     *
     * @param _amount, The amount of 'asset' to be freed.
     */
    function _freeFunds(uint256 _amount) internal override HealthCheck {
        uint256 balance = ERC20(asset).balanceOf(address(this));

        /**
            WITHDRAW LOGIC
         */

        uint256 freed = ERC20(asset).balanceOf(address(this)) - balance;

        if (freed < _amount) {
            require(freed > _amount * (MAX_BPS - maxWithdrawLoss) / MAX_BPS, "!loss");
        }
    }

    /**
     * @dev Internal function to harvest all rewards, redeploy any idle
     * funds and return an accurate accounting of all funds currently
     * held by the Strategy.
     *
     * This should do any needed harvesting, rewards selling, accrual,
     * redepositing etc. to get the most accurate view of current assets.
     *
     * NOTE: All applicable assets including loose assets should be
     * accounted for in this function.
     *
     * Care should be taken when relying on oracles or swap values rather
     * than actual amounts as all Strategy profit/loss accounting will
     * be done based on this returned value.
     *
     * This can still be called post a shutdown, a strategist can check
     * `TokenizedStrategy.isShutdown()` to decide if funds should be
     * redeployed or simply realize any profits/losses.
     *
     * @return _totalAssets A trusted and accurate account for the total
     * amount of 'asset' the strategy currently holds including idle funds.
     */
    function _harvestAndReport()
        internal
        override
        HealthCheck
        returns (uint256 _totalAssets)
    {
        /**
            HARVEST LOGIC
         */
        _totalAssets = ERC20(asset).balanceOf(address(this));

        
        //NORMAL HEALTCHECK
        //    require(_executeHealthCheck(_totalAsses), "!healthcheck")
        
        // If we have a loss to report within the healthCheck bounds.
        uint256 currentAssets = TokenizedStrategy.totalAssets();
        if (_totalAssets < currentAssets) {
            // Update the price PerShare accordingly since the next call will
            // Be lower than the current amount. Then minus 1 for rounding erros
            lastPricePerShare = lastPricePerShare * _totalAssets / currentAssets - 1; 
        }
    }

    function availableDepositLimit(
        address _owner
    ) public view override returns (uint256) {
        require(TokenizedStrategy.pricePerShare() >= lastPricePerShare, "PPS");

        if (paused) return 0;

        uint256 totalAssets = TokenizedStrategy.totalAssets();

        if (totalAssets > depositLimit) return 0;

        return depositLimit - totalAssets;
    }
    

    function availableWithdrawLimit(
        address _owner
    ) public view override returns (uint256) {
        require(TokenizedStrategy.pricePerShare() >= lastPricePerShare, "PPS");

        if (paused) return 0;

        return type(uint256).max;
    }
    
    function setPaused(bool _paused) external {
        require(msg.sender == yChad, "!ychad");
        paused = _paused;
    }

    function setdepositLimit(uint256 _limit) external {
        require(msg.sender == yChad, "!ychad");
        depositLimit = _limit;
    }

    function updatePPS(uint256 _limit) external {
        require(msg.sender == yChad, "!ychad");
        lastPricePerShare = TokenizedStrategy.pricePerShare();
    }


}
