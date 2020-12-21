const DaiToken = artifacts.require("DaiToken");
const UsdcToken = artifacts.require("UsdcToken");
const UsdtToken = artifacts.require("UsdtToken");
const CrvToken = artifacts.require('PoolToken');
const RpToken = artifacts.require('RPToken');

const CrvPool = artifacts.require('StableSwap3Pool');
const RoyaleLP = artifacts.require('RoyaleLP');

const RCurve = artifacts.require('rCurve');

const MRoya = artifacts.require('MRoya');
const MRoyaFarm = artifacts.require('MRoyaFarm');

const address = require('../addresses.json');

module.exports = async function (deployer, network, accounts) {
  
  // await deployer.deploy(DaiToken);
  // const daiToken = await DaiToken.deployed();

  // await deployer.deploy(UsdcToken);
  // const usdcToken = await UsdcToken.deployed();

  // await deployer.deploy(UsdtToken);
  // const usdtToken = await UsdtToken.deployed();

  // await deployer.deploy(CrvToken, "Curve Token", "CRV", 18, 0);
  // const crvToken = await CrvToken.deployed();

  // await deployer.deploy(RpToken);
  // const rpToken = await RpToken.deployed();  

  // await deployer.deploy(CrvPool,
  //   accounts[0],
  //   [daiToken.address, usdcToken.address, usdtToken.address],
  //   // [address.mDai, address.mUsdc, address.mUsdt],
  //   crvToken.address,
  //   // address.CRV,
  //   200, 
  //   4000000, 
  //   5000000000,
  // );
  // const crvPool = await CrvPool.deployed();

  // await deployer.deploy(
  //   RoyaleLP, 
  //   // [daiToken.address, usdcToken.address, usdtToken.address],
  //   [address.mDai, address.mUsdc, address.mUsdt],
    
  //   // rpToken.address
  //   address.RPToken
  // );
  // const royaleLP = await RoyaleLP.deployed();

  // await deployer.deploy(
  //   RCurve,
  //   // address.CRV,
  //   crvPool.address,
  //   // [address.mDai, address.mUsdc, address.mUsdt],
  //   [daiToken.address, usdcToken.address, usdtToken.address],
  //   // address.RoyaleLP
  //   royaleLP.address
  // );

  // await deployer.deploy(
  //   MRoya
  // );
  // const mRoya = await MRoya.deployed();

  // await deployer.deploy(
  //   MRoyaFarm,
  //   address.mRoya,
  //   // mRoya.address,
  //   address.RPToken
  //   // rpToken.address
  // );
  // const mRoyaFarm = await MRoyaFarm.deployed();

  // await deployer.deploy(MultiSig);
};
