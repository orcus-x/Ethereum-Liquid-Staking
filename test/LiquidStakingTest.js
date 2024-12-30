const { expect } = require("chai");
const { ethers } = require("hardhat");
require("dotenv").config();

describe("Liquid Staking System", function () {
  let liquidStaking, stakingDelegate, vethToken, VETHTokenContract;
  let owner, user1, treasuryWallet;
  let provider;

  beforeEach(async function () {
    provider = ethers.provider;
    VETHTokenContract = await ethers.getContractFactory("VETHTokenContract");
    liquidStaking = await ethers.getContractAt("LiquidStaking", process.env.CONTRACT_ADDR);
    stakingDelegate = await ethers.getContractAt("StakingDelegate", process.env.DELEGATE_ADDR);

    // Create a wallet from the private key
    owner = new ethers.Wallet(process.env.OWNER, provider);
    user1 = new ethers.Wallet(process.env.USER1, provider);
    treasuryWallet = new ethers.Wallet(process.env.TREASURY, provider);

    // Get VETH token address
    const settings = await liquidStaking.viewLiquidStakingSettings();
    vethToken = await VETHTokenContract.attach(settings.VETH_identifier);
  });

  describe("User Staking", function () {
    it("Should allow users to stake ETH and receive VETH", async function () {
      const prevVethBalance = await vethToken.balanceOf(owner.address);
      const stakeAmount = ethers.parseEther("0.001");

      let txResponse = await liquidStaking.connect(owner).userStake({ value: stakeAmount });
      await txResponse.wait();

      const vethBalance = await vethToken.balanceOf(owner.address);
      expect(vethBalance).to.equal(prevVethBalance + stakeAmount);
    });
  });

  describe("User Unstaking", function () {
    it("Should allow users to unstake VETH", async function () {
      const prevVethBalance = await vethToken.balanceOf(owner.address);
      const stakeAmount = ethers.parseEther("0.001");

      let txResponse = await liquidStaking.connect(owner).userStake({ value: stakeAmount });
      await txResponse.wait();
      txResponse = await liquidStaking.connect(owner).userUnstake(stakeAmount);
      await txResponse.wait();

      const vethBalance = await vethToken.balanceOf(owner.address);
      expect(vethBalance).to.equal(prevVethBalance);
    });
  });
});
