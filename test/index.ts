import { expect } from "chai";
import { ethers } from "hardhat";
import { DepositorCoin } from "../typechain";
import { StableCoin } from "../typechain";

describe("StableCoin", () => {
  let ethUsdPrice: number, feeRatePercentage: number;
  let StableCoin: StableCoin;

  beforeEach(async () => {
    feeRatePercentage = 3;
    ethUsdPrice = 4000;

    const OracleFactory = await ethers.getContractFactory("Oracle");
    const ethUsdOracle = await OracleFactory.deploy();
    await ethUsdOracle.setPrice(ethUsdPrice);

    const StableCoinFactory = await ethers.getContractFactory("StableCoin");
    StableCoin = await StableCoinFactory.deploy(
      feeRatePercentage,
      ethUsdOracle.address
    );
    await StableCoin.deployed();
  });

  it("Should set fee rate percentage", async () => {
    expect(await StableCoin.feeRatePercentage()).to.equal(feeRatePercentage);
  });

  it("Should allow minting", async () => {
    const ethAmount = 1;
    const expectedMintAmount = ethAmount * ethUsdPrice;
    await StableCoin.mint({
      value: ethers.utils.parseEther(ethAmount.toString()),
    });

    expect(await StableCoin.totalSupply()).to.equal(
      ethers.utils.parseEther(expectedMintAmount.toString())
    );
  });

  describe("With minted tokens", () => {
    let mintAmount: number;
    beforeEach(async () => {
      const ethAmount = 1;
      mintAmount = ethAmount * ethUsdPrice;
      await StableCoin.mint({
        value: ethers.utils.parseEther(ethAmount.toString()),
      });
    });

    it("Should allow burning", async () => {
      const remainingStableCoinAmount = 100;
      await StableCoin.burn(
        ethers.utils.parseEther(
          (mintAmount - remainingStableCoinAmount).toString()
        )
      );

      expect(await StableCoin.totalSupply()).to.equal(
        ethers.utils.parseEther(remainingStableCoinAmount.toString())
      );
    });

    it("Should prevent depositing collateral buffer below mininum", async () => {
      const expectedMinimumAmount = 0.1;
      const stableCoinCollateralBuffer = 0.05;

      await expect(
        StableCoin.depositCollatoralBuffer({
          value: ethers.utils.parseEther(stableCoinCollateralBuffer.toString()),
        })
      ).to.be.revertedWith(
        `custom error 'InitialCollateralRatioError("Initial collateral ratio not met, minimum is ", ` +
          ethers.utils.parseEther(expectedMinimumAmount.toString()) +
          ")'"
      );
    });

    it("Should allow depositing collateral buffer", async () => {
      const stableCoinCollateralBuffer = 0.5;

      await StableCoin.depositCollatoralBuffer({
        value: ethers.utils.parseEther(stableCoinCollateralBuffer.toString()),
      });

      const DepositorCoinFactory = await ethers.getContractFactory(
        "DepositorCoin"
      );
      const DepositorCoin = await DepositorCoinFactory.attach(
        await StableCoin.depositorCoin()
      );

      const newInitialSurplusInUsd = stableCoinCollateralBuffer * ethUsdPrice;
      expect(await DepositorCoin.totalSupply()).to.equal(
        ethers.utils.parseEther(newInitialSurplusInUsd.toString())
      );
    });

    describe("With deposited collateral buffer", () => {
      let stableCoinCollateralBuffer: number;
      let DepositorCoin: DepositorCoin;

      beforeEach(async () => {
        stableCoinCollateralBuffer = 0.5;
        await StableCoin.depositCollatoralBuffer({
          value: ethers.utils.parseEther(stableCoinCollateralBuffer.toString()),
        });

        const DepositorCoinFactory = await ethers.getContractFactory(
          "DepositorCoin"
        );
        DepositorCoin = await DepositorCoinFactory.attach(
          await StableCoin.depositorCoin()
        );
      });

      it("Should allow withdrawing collateral buffer", async () => {
        const newDepositorTotalSupply =
          stableCoinCollateralBuffer * ethUsdPrice;
        const stableCoinCollateralBurnAmount = newDepositorTotalSupply * 0.2;
        await StableCoin.withdrawCollateralBuffer(
          ethers.utils.parseEther(stableCoinCollateralBurnAmount.toString())
        );

        expect(await DepositorCoin.totalSupply()).to.equal(
          ethers.utils.parseEther(
            (
              newDepositorTotalSupply - stableCoinCollateralBurnAmount
            ).toString()
          )
        );
      });
    });
  });
});
