// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {ERC20} from "./ERC20.sol";
import {DepositorCoin} from "./DepositorCoin.sol";
import {Oracle} from "./Oracle.sol";
import {WadLib} from "./WadLib.sol";

contract StableCoin is ERC20 {
    using WadLib for uint256;

    error InitialCollateralRatioError(
        string message,
        uint256 minimumDepositAmount
    );

    DepositorCoin public depositorCoin;

    uint256 public feeRatePercentage;
    Oracle public oracle;
    uint256 public constant INITIAL_COLLATERAL_RATIO_PERCENTAGE = 10;

    constructor(uint256 _feeRatePercentage, Oracle _oracle)
        ERC20("StableCoin", "STBC")
    {
        feeRatePercentage = _feeRatePercentage;
        oracle = _oracle;
    }

    function mint() external payable {
        uint256 fee = _getFee(msg.value);
        uint256 remainingEth = msg.value - fee;
        uint256 mintStableCoinAmount = remainingEth * oracle.getPrice();
        _mint(msg.sender, mintStableCoinAmount);
    }

    function burn(uint256 burnStableCoinAmount) external payable {
        int256 deficitOrSurplus = _getDeficitOrSurplusInContractInUsd();
        require(deficitOrSurplus >= 0, "Cannot burn while in deficit");

        _burn(msg.sender, burnStableCoinAmount);

        uint256 refundingEth = burnStableCoinAmount / oracle.getPrice();
        uint256 fee = _getFee(refundingEth);
        uint256 remainingRefundingEth = refundingEth - fee;
        (bool success, ) = msg.sender.call{value: remainingRefundingEth}("");
        require(success, "Burn transaction failed during refund");
    }

    function _getFee(uint256 ethAmount) private view returns (uint256) {
        bool hasDepositors = address(depositorCoin) != address(0) &&
            depositorCoin.totalSupply() > 0;
        if (!hasDepositors) {
            return 0;
        }
        return (feeRatePercentage * ethAmount) / 100;
    }

    function depositCollatoralBuffer() external payable {
        int256 deficitOrSurplusInUsd = _getDeficitOrSurplusInContractInUsd();
        if (deficitOrSurplusInUsd <= 0) {
            uint256 deficitInUsd = uint256(deficitOrSurplusInUsd * -1);
            uint256 usdInEthPrice = oracle.getPrice();
            uint256 deficitInEth = deficitInUsd / usdInEthPrice;

            uint256 requiredInitialSurplusInUsd = (INITIAL_COLLATERAL_RATIO_PERCENTAGE *
                    totalSupply) / 100;
            uint256 requiredInitialSurplusInEth = requiredInitialSurplusInUsd /
                usdInEthPrice;

            //USE DECLARATIVE WAY WHEN INFORMATION MUST BE THROWN IN ERROR MSG
            // require(
            //     msg.value >= deficitInEth + requiredInitialSurplusInEth,
            //     "Initial collateral ratio not met"
            // );

            // DECLARATIVE WAY OF ERROR MESSAGES
            if (msg.value < deficitInEth + requiredInitialSurplusInEth) {
                uint256 minimumDepositAmount = deficitInEth +
                    requiredInitialSurplusInEth;
                revert InitialCollateralRatioError(
                    "Initial collateral ratio not met, minimum is ",
                    minimumDepositAmount
                );
            }

            uint256 newInitialSurplusInEth = msg.value - deficitInEth;
            uint256 newInitialSurplusInUsd = newInitialSurplusInEth *
                usdInEthPrice;
            depositorCoin = new DepositorCoin();
            uint256 mintSurplusDepositorCoinAmount = newInitialSurplusInUsd;
            depositorCoin.mint(msg.sender, mintSurplusDepositorCoinAmount);
            return;
        }

        uint256 surplusInUsd = uint256(deficitOrSurplusInUsd);
        WadLib.Wad dpcInUsdPrice = _getDPCInUsdPrice(surplusInUsd);
        uint256 mintDepositorCoinAmount = ((msg.value.mulWad(dpcInUsdPrice)) /
            oracle.getPrice());
        depositorCoin.mint(msg.sender, mintDepositorCoinAmount);
    }

    function withdrawCollateralBuffer(uint256 burnDepositorCoinAmount)
        external
    {
        require(
            depositorCoin.balanceOf(msg.sender) >= burnDepositorCoinAmount,
            "Sender has insufficient DPTC funds"
        );

        depositorCoin.burn(msg.sender, burnDepositorCoinAmount);

        int256 deficitOrSurplusInUsd = _getDeficitOrSurplusInContractInUsd();
        require(deficitOrSurplusInUsd > 0, "No funds to withdraw");

        uint256 surplusInUsd = uint256(deficitOrSurplusInUsd);
        WadLib.Wad dpcInUsdPrice = _getDPCInUsdPrice(surplusInUsd);
        uint256 refundingUsd = burnDepositorCoinAmount.divWad(dpcInUsdPrice);
        uint256 refundingEth = refundingUsd / oracle.getPrice();

        (bool success, ) = msg.sender.call{value: refundingEth}("");
        require(success, "Withdraw refund transaction failed");
    }

    function _getDeficitOrSurplusInContractInUsd()
        private
        view
        returns (int256)
    {
        uint256 ethContractBalanceInUsd = (address(this).balance - msg.value) *
            oracle.getPrice();
        uint256 totalStableCoinBalanceInUsd = totalSupply;
        int256 deficitOrSurplus = int256(ethContractBalanceInUsd) -
            int256(totalStableCoinBalanceInUsd);
        return deficitOrSurplus;
    }

    function _getDPCInUsdPrice(uint256 surplusInUsd)
        private
        view
        returns (WadLib.Wad)
    {
        return WadLib.fromFraction(depositorCoin.totalSupply(), surplusInUsd);
    }
}
