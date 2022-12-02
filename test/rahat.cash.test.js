const { web3 } = require("hardhat");
const exceptions = require("./exceptions");
const RahatDonor = artifacts.require("RahatDonor");
const RahatRegistry = artifacts.require("RahatRegistry");
const RahatERC20 = artifacts.require("RahatERC20");
const Rahat = artifacts.require("Rahat");
const RahatAdmin = artifacts.require("RahatAdmin");
const RahatWallet = artifacts.require("RahatWallet");
const RahatTriggerResponse = artifacts.require("RahatTriggerResponse");
const ERC20 = artifacts.require("ERC20");

describe.only("------ Rahat Donor Tests ------", function () {
  let rahatDonor;
  let rahatRegistry;
  let cashToken;
  let rahatERC20;
  let rahat;
  let rahatTrigger;
  let rahatAdmin;
  let totalCash = 10000;
  let cashTransfered = 9000;
  let projectId = "TestProject";
  let beneficiary = "9801109670";
  let prjAmt = 1000;
  let benAmt = 900;
  let vnd1CashAmt = 600;
  let vnd2CashAmt = 400;
  let projectIdHash = web3.utils.soliditySha3({
    type: "string",
    value: projectId,
  });

  before(async function () {
    [
      deployer,
      donor,
      agency,
      palika,
      rahatTeam,
      server,
      vendor1,
      vendor2,
      beneficiaryWallet,
    ] = await web3.eth.getAccounts();

    rahatDonor = await RahatDonor.new(donor);
    rahatRegistry = await RahatRegistry.new(agency);
    rahatERC20 = await RahatERC20.new("Rahat", "RHT", agency, 0);
    rahatTrigger = await RahatTriggerResponse.new(agency, 2);
    rahat = await Rahat.new(
      rahatERC20.address,
      rahatRegistry.address,
      rahatTrigger.address,
      palika
    );
    rahatAdmin = await RahatAdmin.new(rahatERC20.address, agency);
    await rahatERC20.addOwner(rahatAdmin.address, { from: agency });
    await rahatRegistry.addOwner(rahat.address, { from: agency });
    await rahatTrigger.addAdmin(palika, { from: agency });
    await rahatTrigger.addAdmin(rahatTeam, { from: agency });
    await rahat.addAdmin(rahatTeam, { from: palika });
    await rahat.addServer(server, { from: palika });

    await web3.eth.sendTransaction({
      from: agency,
      to: rahat.address,
      value: web3.utils.toWei("5", "ether"),
    });
  });

  describe.only("test", function () {
    it("Create tracking tokens", async function () {
      // const vAddr = "0x2e38580a0ea254895b3f28f3aa95221124c102df";
      // console.log(web3.utils.fromWei(await web3.eth.getBalance(vAddr)));
      // web3.eth.sendTransaction;
      // await rahat.addVendor(vAddr, { from: palika });
      // console.log(web3.utils.fromWei(await web3.eth.getBalance(vAddr)));
      // console.log(web3.utils.fromWei(await web3.eth.getBalance(rahat.address)));
      // await rahat.withdraw(vAddr, { from: palika });
      // console.log(web3.utils.fromWei(await web3.eth.getBalance(vAddr)));
      // console.log(web3.utils.fromWei(await web3.eth.getBalance(rahat.address)));
      console.log(
        await rahat.projectBalance(projectIdHash, rahatAdmin.address)
      );
    });
  });

  describe("Cash Tracking Token", function () {
    it("Create tracking tokens", async function () {
      let tokenAddress = await rahatDonor.createToken.call(
        "Cash Tracking Token",
        "CTT",
        0,
        { from: donor }
      );
      const res = await rahatDonor.createToken(
        "Cash Tracking Token",
        "CTT",
        0,
        {
          from: donor,
        }
      );
      cashToken = new RahatERC20(tokenAddress);
      await rahatDonor.createToken("Cash Tracking Token2", "CTT2", 0, {
        from: donor,
      });
      let tokenColl = await rahatDonor.listTokens();
      assert.equal(tokenAddress, tokenColl[0]);
      assert.equal(tokenColl.length, 2);
    });

    it("Transfer from donor to agency", async () => {
      await rahatDonor.mintTokenAndApprove(
        cashToken.address,
        rahatAdmin.address,
        totalCash,
        { from: donor }
      );
      // await rahatDonor.approveToken(
      //   cashToken.address,
      //   rahatAdmin.address,
      //   5000,
      //   { from: donor }
      // );
      // await rahatAdmin.claimToken(cashToken.address, rahatDonor.address, 2000, {
      //   from: agency,
      // });
      // let allowance = await cashToken.allowance(
      //   rahatDonor.address,
      //   rahatAdmin.address
      // );
      // await rahatDonor.approveToken(
      //   cashToken.address,
      //   rahatAdmin.address,
      //   allowance + 4000,
      //   { from: donor }
      // );
      await rahatAdmin.claimToken(
        cashToken.address,
        rahatDonor.address,
        totalCash,
        {
          from: agency,
        }
      );
      assert.equal(await cashToken.balanceOf(rahatDonor.address), 0);
      assert.equal(await cashToken.balanceOf(rahatAdmin.address), totalCash);
    });

    it("Transfer from agency to palika", async () => {
      // await rahatAdmin.approveToken(cashToken.address, rahat.address, 5000, {
      //   from: agency,
      // });

      await rahatAdmin.setProjectBudget_ERC20(
        rahat.address,
        projectId,
        prjAmt,
        {
          from: agency,
        }
      );
      await rahat.claimTokenForProject(
        cashToken.address,
        rahatAdmin.address,
        projectIdHash,
        prjAmt,
        {
          from: palika,
        }
      );
      assert.equal(
        await cashToken.balanceOf(rahatAdmin.address),
        totalCash - prjAmt
      );
      assert.equal(await cashToken.balanceOf(rahat.address), prjAmt);
      assert.equal(await rahat.totalProjectErc20Issued(projectIdHash), prjAmt);
      assert.equal(
        await rahat.remainingProjectErc20Balances(projectIdHash),
        prjAmt
      );
    });
  });

  describe("Manage Project", function () {
    it("Activate Project", async () => {
      await rahatTrigger.activateResponse(projectId, { from: agency });
      await rahatTrigger.activateResponse(projectId, { from: rahatTeam });
      assert.equal(await rahatTrigger.isLive(), true);
    });

    it("Issue token to beneficiary", async function () {
      await rahatRegistry.addId2AddressMap(
        web3.utils.soliditySha3({ type: "string", value: beneficiary }),
        beneficiaryWallet,
        {
          from: agency,
        }
      );
      await rahat.issueERC20ToBeneficiary(projectId, beneficiary, benAmt, {
        from: palika,
      });
      assert.equal(await rahat.erc20Balance(beneficiary), benAmt);
      assert.equal(
        await rahat.remainingProjectErc20Balances(projectIdHash),
        prjAmt - benAmt
      );
    });
  });

  describe("Manage Vendors", function () {
    let vnd1WalletAddr, vnd2WalletAddr;
    it("Add Vendor", async () => {
      vnd1WalletAddr = await rahat.addVendor.call(vendor1, {
        from: palika,
      });
      await rahat.addVendor(vendor1, { from: palika });

      vnd2WalletAddr = await rahat.addVendor.call(vendor2, {
        from: palika,
      });
      await rahat.addVendor(vendor2, { from: palika });
    });

    it("Issue token to vendor1", async function () {
      await rahat.approveToken(cashToken.address, vnd1WalletAddr, vnd1CashAmt, {
        from: palika,
      });
      const vendorWallet1 = new RahatWallet(vnd1WalletAddr);
      await vendorWallet1.claimToken(
        cashToken.address,
        rahat.address,
        vnd1CashAmt,
        {
          from: vendor1,
        }
      );
      await assert.equal(
        await cashToken.balanceOf(vnd1WalletAddr),
        vnd1CashAmt
      );
    });

    it("Issue token to vendor2", async function () {
      await rahat.approveToken(cashToken.address, vnd2WalletAddr, vnd2CashAmt, {
        from: palika,
      });
      const vendorWallet2 = new RahatWallet(vnd2WalletAddr);
      await vendorWallet2.claimToken(
        cashToken.address,
        rahat.address,
        vnd2CashAmt,
        {
          from: vendor2,
        }
      );
      await assert.equal(
        await cashToken.balanceOf(vnd2WalletAddr),
        vnd2CashAmt
      );

      assert.equal(
        await cashToken.balanceOf(rahat.address),
        prjAmt - vnd1CashAmt - vnd2CashAmt
      );
    });
  });

  describe("Claim and transfer tokens to vendor", function () {
    const beneficiaryHash = web3.utils.soliditySha3({
      type: "string",
      value: beneficiary.toString(),
    });
    const claimAmt = 500;
    const otp = "9670";
    const otpHash = web3.utils.soliditySha3({ type: "string", value: otp });

    it("Create token claim from vendor to beneficiary", async function () {
      await rahat.createERC20Claim(beneficiary, claimAmt, { from: vendor1 });
      const claim = await rahat.recentERC20Claims(vendor1, beneficiaryHash);
      assert.equal(claim.amount, claimAmt);
      assert.equal(claim.isReleased, false);
    });

    it("Approve erc20 token claim by server", async function () {
      await rahat.approveERC20Claim(vendor1, beneficiary, otpHash, claimAmt, {
        from: server,
      });

      const claim = await rahat.recentERC20Claims(vendor1, beneficiaryHash);
      assert.equal(claim.amount, claimAmt);
      assert.equal(claim.isReleased, true);
    });

    it("should get erc20 tokens from claim made after entering otp set by server", async function () {
      await rahat.getERC20FromClaim(beneficiary, otp, { from: vendor1 });

      const claim = await rahat.recentERC20Claims(vendor1, beneficiaryHash);
      assert.equal(claim.amount, 0);
      assert.equal(claim.isReleased, false);
      const vendorBalance = await rahatERC20.balanceOf(vendor1);
      assert.equal(vendorBalance.toNumber(), claimAmt);
      await assert.equal(await cashToken.balanceOf(vendor1), 0);
      await assert.equal(await cashToken.balanceOf(vendor1), 0);

      const benWallet = await rahatRegistry.id2Address(
        web3.utils.soliditySha3({ type: "string", value: beneficiary })
      );
      await assert.equal(await cashToken.balanceOf(benWallet), claimAmt);

      // const { walletAddress, cashAllowance, cashBalance, tokenBalance } =
      //   await rahat.vendorBalance(vendor1);
      // console.log(
      //   walletAddress,
      //   cashBalance.toNumber(),
      //   tokenBalance.toNumber()
      // );

      const { walletAddress, cashBalance, tokenBalance } =
        await rahat.beneficiaryBalance(beneficiary);
      console.log(
        walletAddress,
        cashBalance.toNumber(),
        tokenBalance.toNumber()
      );
    });
  });
});
