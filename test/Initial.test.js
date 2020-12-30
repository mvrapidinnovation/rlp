const { assert } = require('chai');

const DaiToken = artifacts.require('DaiToken');
const UsdcToken = artifacts.require('UsdcToken');
const UsdtToken = artifacts.require('UsdtToken');
const Crv3Token = artifacts.require('PoolToken');
const RpToken = artifacts.require('RPToken');

const Controller=artifacts.require('rController');
const Pool3DAI=artifacts.require('rDAI3Pool');
const Pool3USDC=artifacts.require('rUSDC3Pool');
const Pool3USDt=artifacts.require('rUSDT3Pool');

const CrvPool = artifacts.require('StableSwap3Pool');
const RoyaleLP = artifacts.require('RoyaleLP');

// const RCurve = artifacts.require('rCurve');


const MRoya = artifacts.require('MRoya');
const MRoyaFarm = artifacts.require('MRoyaFarm');

const RLoan = artifacts.require('rLoan');

const CRVToken = artifacts.require('CRVToken');
const VotingEscrow = artifacts.require('VotingEscrow');
const GaugeController = artifacts.require('Pool3GuageController');
const Minter = artifacts.require('Minter');
const Gauge = artifacts.require('Pool3Gauge');


function toDai(n) {
    return web3.utils.toWei(n, 'ether');
}

function toUsd(n) {
    let result = parseFloat(n) * 1e6;
    return result.toString();
}

contract('RoyaleLP', ([owner, signeeOne, signeeTwo, gamer,gamer2, investorOne, investorTwo,investorThree]) => {

    let daiToken, usdcToken, usdtToken, crvToken, crvPool;
    let royaleLP, rpToken;
    let mRoya, mRoyaFarm, rLoan;
    let controller, usdcpool, usdtpool, daipool, daipool2;
    let CRVtoken, veCRV, gaugeController, minter, gauge;

    before(async() => {
        // Deploying Tokens
        daiToken = await DaiToken.new();
        usdcToken = await UsdcToken.new();
        usdtToken = await UsdtToken.new();

        crvToken = await Crv3Token.new("Curve Token", "CRV", 18, 0);
        CRVtoken = await CRVToken.new("Curve DAO Token", "CRV", 18);
        veCRV = await VotingEscrow.new(CRVtoken.address, "Vote-escrowed CRV", "veCRV", "veCRV_1.0.0");

        rpToken = await RpToken.new();
        mRoya = await MRoya.new();

        // Deploying Curve 3Pool
        crvPool = await CrvPool.new(
            owner,
            [daiToken.address, usdcToken.address, usdtToken.address],
            crvToken.address,
            200, 
            4000000, 
            5000000000, 
        );

        gaugeController = await GaugeController.new(CRVtoken.address, veCRV.address);
        minter = await Minter.new(CRVtoken.address, gaugeController.address);
        gauge = await Gauge.new(crvToken.address, minter.address);



        // Deploying RoyaleLP contract
        royaleLP = await RoyaleLP.new(
            // crvPool.address, 
            [daiToken.address, usdcToken.address, usdtToken.address],
            // crvToken.address,
            rpToken.address
        );

        // rController
        controller=await Controller.new(
            [daiToken.address, usdcToken.address, usdtToken.address],
            royaleLP.address
        );
        
        // Deploying Strategies

        daipool=await Pool3DAI.new(
            controller.address,
            crvPool.address,
            daiToken.address,
            crvToken.address,
            royaleLP.address,
            gauge.address
        );

        daipool2=await Pool3DAI.new(
            controller.address,
            crvPool.address,
            daiToken.address,
            crvToken.address,
            royaleLP.address,
            gauge.address
        );

        usdcpool=await Pool3USDC.new(
            controller.address,
            crvPool.address,
            usdcToken.address,
            crvToken.address,
            royaleLP.address,
            gauge.address
        );

        usdtpool=await Pool3USDt.new(
            controller.address,
            crvPool.address,
            usdtToken.address,
            crvToken.address,
            royaleLP.address,
            gauge.address
        );

        // rCurve = await RCurve.new(
        //     crvToken.address,
        //     [daiToken.address, usdcToken.address, usdtToken.address],
        //     royaleLP.address
        // );

        mRoyaFarm = await MRoyaFarm.new(
            rpToken.address,
            mRoya.address
        );

        rLoan = await RLoan.new(
            [daiToken.address, usdcToken.address, usdtToken.address],
            royaleLP.address
        );
    });

    describe('Setting Up Pool and tokens', async() => {
        describe('DaiToken deployment', async() => {
            it('has a name', async() => {
                result= await daiToken.name();
                assert.equal(result, "Mock DAI Token");
            });
        });
    
        describe('UsdcToken deployment', async() => {
            it('has a name', async() => {
                result= await usdcToken.name();
                assert.equal(result, "Mock USDC Token");
            });
        });
    
        describe('UsdtToken deployment', async() => {
            it('has a name', async() => {
                result= await usdtToken.name();
                assert.equal(result, "Mock USDT Token");
            });
        });
    
        describe('Curve Tokens deployment', async() => {
            it('3CRV', async() => {
                result= await crvToken.name();
                assert.equal(result, "Curve Token");
            });
    
            it('has set minter', async() => {
                await crvToken.set_minter(crvPool.address); 
    
                result = await crvToken.minter();
                assert.equal(result.toString(), crvPool.address);
            });

            it('CRV', async() => {
                result= await CRVtoken.name();
                assert.equal(result, "Curve DAO Token");
            });

            it('veCRV', async() => {
                result= await veCRV.name();
                assert.equal(result, "Vote-escrowed CRV");
            });

        });
        
        describe('CrvPool deployment', async() => {
            it('has initial liquidity', async() => {
                await daiToken.approve(crvPool.address, toDai('50000'));
                await usdcToken.approve(crvPool.address, toUsd('20000'));
                await usdtToken.approve(crvPool.address, toUsd('20000'));
    
                const amounts = [toDai("50000"), toUsd("20000"), toUsd("20000")];
                await crvPool.add_liquidity(amounts, toDai("20000"), { from: owner });
    
                mintAmount = await crvPool.calc_token_amount(amounts, 1);
                supply = await crvToken.totalSupply();
                console.log(supply.toString());
                assert.equal(mintAmount.toString(), supply.toString());
            });
        })

        describe('Guage Controller deployment', async() => {
            it('has CRV address', async() => {
                result = await gaugeController.token();
                assert.equal(result, CRVtoken.address);
            });
        });

        describe('Minter Deployment', async() => {
            it('has CRV address', async() => {
                result = await minter.token();
                assert.equal(result, CRVtoken.address);
            });

            it('has controller address', async() => {
                result = await minter.controller();
                assert.equal(result, gaugeController.address);
            });
        });

        describe('Guage Deployment', async() => {
            it('has curvePool address', async() => {
                result = await gauge.lp_token();
                assert.equal(result, crvToken.address);
            });

            it('has controller address', async() => {
                result = await gauge.minter();
                assert.equal(result, minter.address);
            });

            it('add guage', async() => {
                gaugeController.add_gauge(gauge.address, 1);
            });
        });

        describe('RPToken deployment', async() => {
            it('RPT has a name', async() => {
                x = await rpToken.name();
                assert.equal(x, "Royale Protocol");
            });

            it('has set minter for RPT token', async() => {
                await rpToken.setCaller(royaleLP.address);

                x = await rpToken.caller();
                assert(x, royaleLP.address);
            });
        });

        describe('Set Loan Contract in RoyaleLP', async() => {
            it(' set loan contract', async() => {
                await royaleLP.setLoanContract(rLoan.address);
               
            });
        });

        describe('MRoya deployment', async() => {
            it('MROYA has a name', async() => {
                let result= await mRoya.name();
                assert.equal(result, "mRoya Token");
            });

            it('has set minter of MROYA Token', async() => {
                await mRoya.addMinter(mRoyaFarm.address);

                result = await mRoya.minter(mRoyaFarm.address);
                assert(result, false);
            });
        });
    });

    describe('Setting up Controller', async() => {
        it('has set strategies for all 3 tokens', async() => {
            controller.setStrategy(daipool. address, 0);
            controller.setStrategy(usdcpool.address, 1);
            controller.setStrategy(usdtpool.address, 2);
        });
    });

    describe('Initial Set Up', async() => {

        it('Supply each of 1000 tokens to investorOne', async() => {
            await daiToken.transfer(investorOne, toDai('5000'), { from: owner });
            await usdcToken.transfer(investorOne, toUsd('5000'), { from: owner });
            await usdtToken.transfer(investorOne, toUsd('5000'), { from: owner });

            result = await daiToken.balanceOf(investorOne);
            assert.equal(result, toDai('5000'));

            result = await usdcToken.balanceOf(investorOne);
            assert.equal(result, toUsd('5000'));

            result = await usdtToken.balanceOf(investorOne);
            assert.equal(result, toUsd('5000'));
        });

        it('Supply each of 1000 tokens to investorTwo', async() => {
            await daiToken.transfer(investorTwo, toDai('5000'), { from: owner });
            await usdcToken.transfer(investorTwo, toUsd('5000'), { from: owner });
            await usdtToken.transfer(investorTwo, toUsd('5000'), { from: owner });

            result = await daiToken.balanceOf(investorTwo);
            assert.equal(result, toDai('5000'));

            result = await usdcToken.balanceOf(investorTwo);
            assert.equal(result, toUsd('5000'));

            result = await usdtToken.balanceOf(investorTwo);
            assert.equal(result, toUsd('5000'));
        });

        it('Supply each of 1000 tokens to investorThree', async() => {
            await daiToken.transfer(investorThree, toDai('5000'), { from: owner });
            await usdcToken.transfer(investorThree, toUsd('5000'), { from: owner });
            await usdtToken.transfer(investorThree, toUsd('5000'), { from: owner });

            result = await daiToken.balanceOf(investorThree);
            assert.equal(result, toDai('5000'));

            result = await usdcToken.balanceOf(investorThree);
            assert.equal(result, toUsd('5000'));

            result = await usdtToken.balanceOf(investorThree);
            assert.equal(result, toUsd('5000'));
        });

        it('Supply each of 1000 tokens to RoyaleLP', async() => {
            await daiToken.transfer(royaleLP.address, toDai('1000'), { from: owner });
            await usdcToken.transfer(royaleLP.address, toUsd('1000'), { from: owner });
            await usdtToken.transfer(royaleLP.address, toUsd('1000'), { from: owner });

            result = await daiToken.balanceOf(royaleLP.address);
            assert.equal(result, toDai('1000'));

            result = await usdcToken.balanceOf(royaleLP.address);
            assert.equal(result, toUsd('1000'));

            result = await usdtToken.balanceOf(royaleLP.address);
            assert.equal(result, toUsd('1000'));

            await royaleLP.setInitialDeposit();
        });

        it('initial RPT mint', async() => {
                await rpToken.mint(royaleLP.address, toDai('300'));
        })
            
       /*  it('set up curve address in rCurve', async() => {
            await rCurve.setPool(crvPool.address);
        }); */

        it('set up Controller in RoyaleLP', async() => {
            await royaleLP.setController(controller.address);
        });

    });

    describe('RoyaleLP Testing', async() => {

        describe('Deposit Test', async() => {
            it('investorOne added funds to RoyaleLP', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('1000'), { from: investorOne });
                await usdcToken.approve(
                    royaleLP.address, toUsd('1000'), { from: investorOne });
                await usdtToken.approve(
                    royaleLP.address, toUsd('1000'), { from: investorOne }); 
                
                await royaleLP.supply(
                    [toDai('1000'), toUsd('0'), toUsd('0')], 
                    { from: investorOne }
                );
                await royaleLP.supply(
                    [toDai('0'), toUsd('1000'), toUsd('0')], 
                    { from: investorOne }
                );
                await royaleLP.supply(
                    [toDai('0'),  toUsd('0'),toUsd('1000')], 
                    { from: investorOne }
                );

                // Check balances of RoyaleLP
                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('2000'));
    
                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('2000'));
    
                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('2000'));
                
                // Check balances of InvestorOne
                result = await daiToken.balanceOf(investorOne);
                assert.equal(result.toString(), toDai('4000'));
    
                result = await usdcToken.balanceOf(investorOne);
                assert.equal(result.toString(), toUsd('4000'));
    
                result = await usdtToken.balanceOf(investorOne);
                assert.equal(result.toString(), toUsd('4000'));
            });

            it('investorTwo added funds to RoyaleLP', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('2000'), { from: investorTwo });
                // await usdcToken.approve(
                //     royaleLP.address, toUsd('500'), { from: investorTwo });
                // await usdtToken.approve(
                //     royaleLP.address, toUsd('500'), { from: investorTwo }); 
                
                await royaleLP.supply(
                    [toDai('2000'), toUsd('0'), toUsd('0')], 
                    { from: investorTwo }
                );

                // Check balances of RoyaleLP
                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('4000'));
    
                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('2000'));
    
                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('2000'));
                
                // Check balances of InvestorTwo
                result = await daiToken.balanceOf(investorTwo);
                assert.equal(result.toString(), toDai('3000'));
    
                result = await usdcToken.balanceOf(investorTwo);
                assert.equal(result.toString(), toUsd('5000'));
    
                result = await usdtToken.balanceOf(investorTwo);
                assert.equal(result.toString(), toUsd('5000'));
            });
            it('investorThree added funds to RoyaleLP', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('2000'), { from: investorThree });
                 await usdcToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorThree });
                 await usdtToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorThree }); 
                
                await royaleLP.supply(
                    [toDai('0'), toUsd('2000'), toUsd('0')], 
                    { from: investorThree }
                );

                // Check balances of RoyaleLP
                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('4000'));
    
                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
    
                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('2000'));
                
                // Check balances of InvestorTwo
                result = await daiToken.balanceOf(investorThree);
                assert.equal(result.toString(), toDai('5000'));
    
                result = await usdcToken.balanceOf(investorThree);
                assert.equal(result.toString(), toUsd('3000'));
    
                result = await usdtToken.balanceOf(investorThree);
                assert.equal(result.toString(), toUsd('5000'));
            });
            it('investorTwo added funds to RoyaleLP again USDC', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('2000'), { from: investorTwo });
                 await usdcToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorTwo });
                 await usdtToken.approve(
                   royaleLP.address, toUsd('2000'), { from: investorTwo }); 
                
                await royaleLP.supply(
                    [toDai('0'), toUsd('0'), toUsd('2000')], 
                    { from: investorTwo }
                );

                // Check balances of RoyaleLP
                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('4000'));
    
                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
    
                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
                
                // Check balances of InvestorTwo
                result = await daiToken.balanceOf(investorTwo);
                assert.equal(result.toString(), toDai('3000'));
    
                result = await usdcToken.balanceOf(investorTwo);
                assert.equal(result.toString(), toUsd('5000'));
    
                result = await usdtToken.balanceOf(investorTwo);
                assert.equal(result.toString(), toUsd('3000'));
            });
            it('investorThree added funds to RoyaleLP', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('2000'), { from: investorThree });
                 await usdcToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorThree });
                 await usdtToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorThree }); 
                
                await royaleLP.supply(
                    [toDai('0'), toUsd('2000'), toUsd('0')], 
                    { from: investorThree }
                );

                // Check balances of RoyaleLP
                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('4000'));
    
                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
    
                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('2000'));
                
                // Check balances of InvestorTwo
                result = await daiToken.balanceOf(investorThree);
                assert.equal(result.toString(), toDai('5000'));
    
                result = await usdcToken.balanceOf(investorThree);
                assert.equal(result.toString(), toUsd('3000'));
    
                result = await usdtToken.balanceOf(investorThree);
                assert.equal(result.toString(), toUsd('5000'));
            });
            it('investorTwo added funds to RoyaleLP again USDC', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('2000'), { from: investorTwo });
                 await usdcToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorTwo });
                 await usdtToken.approve(
                   royaleLP.address, toUsd('2000'), { from: investorTwo }); 
                
                await royaleLP.supply(
                    [toDai('0'), toUsd('0'), toUsd('2000')], 
                    { from: investorTwo }
                );

                // Check balances of RoyaleLP
                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('4000'));
    
                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
    
                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
                
                // Check balances of InvestorTwo
                result = await daiToken.balanceOf(investorTwo);
                assert.equal(result.toString(), toDai('3000'));
    
                result = await usdcToken.balanceOf(investorTwo);
                assert.equal(result.toString(), toUsd('5000'));
    
                result = await usdtToken.balanceOf(investorTwo);
                assert.equal(result.toString(), toUsd('3000'));
            });

            it('investorThree added funds to RoyaleLP', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('2000'), { from: investorThree });
                 await usdcToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorThree });
                 await usdtToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorThree }); 
                
                await royaleLP.supply(
                    [toDai('2000'), toUsd('0'), toUsd('0')], 
                    { from: investorThree }
                );

                // Check balances of RoyaleLP
                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('6000'));
    
                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
    
                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
                
                // Check balances of InvestorTwo
                result = await daiToken.balanceOf(investorThree);
                assert.equal(result.toString(), toDai('3000'));
    
                result = await usdcToken.balanceOf(investorThree);
                assert.equal(result.toString(), toUsd('3000'));
    
                result = await usdtToken.balanceOf(investorThree);
                assert.equal(result.toString(), toUsd('5000'));
            });


            it('investorThree added funds to RoyaleLP', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('2000'), { from: investorThree });
                 await usdcToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorThree });
                 await usdtToken.approve(
                     royaleLP.address, toUsd('2000'), { from: investorThree }); 
                
                await royaleLP.supply(
                    [toDai('2000'), toUsd('0'), toUsd('0')], 
                    { from: investorThree }
                );

                // Check balances of RoyaleLP
                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('6000'));
    
                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
    
                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('4000'));
                
                // Check balances of InvestorTwo
                result = await daiToken.balanceOf(investorThree);
                assert.equal(result.toString(), toDai('3000'));
    
                result = await usdcToken.balanceOf(investorThree);
                assert.equal(result.toString(), toUsd('3000'));
    
                result = await usdtToken.balanceOf(investorThree);
                assert.equal(result.toString(), toUsd('5000'));
            });


            it('investorOne recieved RPT', async() => {
                result = await rpToken.balanceOf(investorOne);
                console.log(result.toString());

                // result = await royaleLP.totalRPT();
                // console.log(result.toString());
            });

            it('investor has staked his RPT', async() => {
                await rpToken.approve(mRoyaFarm.address, toDai('2'), {from: investorOne})
                
                await mRoyaFarm.stakeTokens(toDai('2'), {from: investorOne});
    
                result = await mRoyaFarm.staker(investorOne);
                console.log(result['0'].toString());
                console.log(result['1'].toString());
                console.log(result['2'].toString());
    
            });
            
            it('investorTwo recieved RPT', async() => {
                result = await rpToken.balanceOf(investorTwo);
                console.log(result.toString());

                // result = await royaleLP.totalRPT();
                // console.log(result.toString());
            });
            it('investorThree recieved RPT', async() => {
                result = await rpToken.balanceOf(investorThree);
                console.log(result.toString());

                // result = await royaleLP.totalRPT();
                // console.log(result.toString());
            });

            it('Supplied funds to 3pool', async() => {
                await royaleLP.deposit();
                
                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('300'));
    
                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('200'));
    
                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('200'));
                
                lpCRV = await crvToken.balanceOf(daipool.address);
                console.log(`DaiPool CRV balance: ${lpCRV / 1e18}`);
                lpCRV = await crvToken.balanceOf(usdcpool.address);
                console.log(`USDCPool CRV balance: ${lpCRV / 1e18}`);
                lpCRV = await crvToken.balanceOf(usdtpool.address);
                console.log(`USDTPool CRV balance: ${lpCRV / 1e18}`);
                lpCRV = await crvToken.balanceOf(daipool2.address);
                console.log(`DaiPool2 CRV balance: ${lpCRV / 1e18}`);
            });
        });

        describe('Change strategy test', async() => {
            it('has new strategy', async() => {
                await controller.changeStrategy(daipool2.address, 0);

                lpCRV = await crvToken.balanceOf(daipool2.address);
                console.log(`DaiPool2 CRV balance: ${lpCRV / 1e18}`);
                
                lpCRV = await crvToken.balanceOf(daipool.address);
                console.log(`DaiPool CRV balance: ${lpCRV / 1e18}`);
            });
        });

        describe('MultiSig Initiation', async() => {
            // it('set LP contract', async() => {
            //     await royaleLP.setRoyaleLPAddress(royaleLP.address);
            // });

            it('Add first Signee', async() => {
                await rLoan.addSignee(signeeOne);

                result = await rLoan.signees(1);
                assert.equal(result, signeeOne);
            });

            it('Add second Signee', async() => {
                await rLoan.addSignee(signeeTwo);

                result = await rLoan.signees(2);
                assert.equal(result, signeeTwo);
            });

            it('set required signee', async() => {
                await rLoan.setRequiredSignee(2);

                result = await rLoan.required();
                assert.equal(result, 2);
            });
        });

        describe('Loan withdraw test', async() => {

            let id;

            it('gamer requests for loan', async() => {
                amtToWithdraw = [toDai('500'), toUsd('300'), toUsd('200')];
                
                await rLoan.requestLoan(
                    amtToWithdraw, { from: gamer });
                
                id = await rLoan.transactionCount();
                console.log("Loan ID: ", id.toString());

                result = await rLoan.transactionCount();
                assert.equal(result.toString(), "1");
                
                // result = await royaleLP.getTransactionDetail(id.toString());
                // console.log("Before Approval: ", result);
            });

            it('signeeOne signs', async() => {
                // id = await rLoan.transactionCount();
                await rLoan.confirmLoan(id.toString(), { from: signeeOne });
            });

            it('signeeTwo signs', async() => {
                // id = await rLoan.transactionCount();
                await rLoan.confirmLoan(id.toString(), { from: signeeTwo });
            });

            it('gamer signs', async() => {
                // id = await rLoan.transactionCount();
                await rLoan.signTransaction(id.toString(), { from: gamer });
            });

            it('loan approved', async() => {
                // id = await rLoan.transactionCount();

                result = await rLoan.checkLoanApproved(id.toString());
                assert.equal(result, true);

                // result = await royaleLP.getTransactionDetail(id.toString());
                // console.log("After approval: ", result);
            });
           
            

            it('loan withdrawn', async() => {
                amtToWithdraw = [toDai('50'), toUsd('50'), toUsd('50')];
                 //id = await rLoan.transactionCount();
                await rLoan.withdrawLoan(amtToWithdraw, id.toString(), { from: gamer });

                result = await daiToken.balanceOf(gamer);
                assert.equal(result.toString(), toDai('50'));

                result = await usdcToken.balanceOf(gamer);
                assert.equal(result.toString(), toUsd('50'));

                result = await usdtToken.balanceOf(gamer);
                assert.equal(result.toString(), toUsd('50'));
            

            });

            it('Loan repayed', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('100'), { from: gamer });
                await usdcToken.approve(
                    royaleLP.address, toUsd('100'), { from: gamer });
                await usdtToken.approve(
                    royaleLP.address, toUsd('100'), { from: gamer }); 
                    console.log("\nBalance Before repayment\n");
                    result = await daiToken.balanceOf(gamer);
                    console.log(result.toString());
                    result = await usdcToken.balanceOf(gamer);
                    console.log(result.toString());
                    result = await usdtToken.balanceOf(gamer);
                    console.log(result.toString());
                    

                amountToRepay = [toDai('50'), toUsd('50'), toUsd('50')];
                 id = await rLoan.transactionCount();
                rLoan.repayLoan(amountToRepay, id.toString(), { from: gamer });
 
                console.log("\nBalance After repayment\n");
                    result = await daiToken.balanceOf(gamer);
                    console.log(result.toString());
                    result = await usdcToken.balanceOf(gamer);
                    console.log(result.toString());
                    result = await usdtToken.balanceOf(gamer);
                    console.log(result.toString());
                result = await daiToken.balanceOf(gamer);
                assert.equal(result.toString(), toDai('0'));

                result = await usdcToken.balanceOf(gamer);
                assert.equal(result.toString(), toUsd('0'));

                result = await usdtToken.balanceOf(gamer);
                assert.equal(result.toString(), toUsd('0'));
            });
            it("Withdraw Loan again",async()=>{
                amtToWithdraw = [toDai('50'), toUsd('50'), toUsd('50')];
                id = await rLoan.transactionCount();
                await rLoan.withdrawLoan(amtToWithdraw, id.toString(), { from: gamer });

                result = await daiToken.balanceOf(gamer);
                assert.equal(result.toString(), toDai('50'));

                result = await usdcToken.balanceOf(gamer);
                assert.equal(result.toString(), toUsd('50'));

                result = await usdtToken.balanceOf(gamer);
                assert.equal(result.toString(), toUsd('50'));
            });
            it('Loan repayed again', async() => {
                await daiToken.approve(
                    royaleLP.address, toDai('100'), { from: gamer });
                await usdcToken.approve(
                    royaleLP.address, toUsd('100'), { from: gamer });
                await usdtToken.approve(
                    royaleLP.address, toUsd('100'), { from: gamer }); 
                    console.log("\nBalance Before repayment\n");
                    result = await daiToken.balanceOf(gamer);
                    console.log(result.toString());
                    result = await usdcToken.balanceOf(gamer);
                    console.log(result.toString());
                    result = await usdtToken.balanceOf(gamer);
                    console.log(result.toString());
                    

                amountToRepay = [toDai('50'), toUsd('50'), toUsd('50')];
                 id = await rLoan.transactionCount();
                rLoan.repayLoan(amountToRepay, id.toString(), { from: gamer });
 
                console.log("\nBalance After repayment\n");
                    result = await daiToken.balanceOf(gamer);
                    console.log(result.toString());
                    result = await usdcToken.balanceOf(gamer);
                    console.log(result.toString());
                    result = await usdtToken.balanceOf(gamer);
                    console.log(result.toString());
                result = await daiToken.balanceOf(gamer);
                assert.equal(result.toString(), toDai('0'));

                result = await usdcToken.balanceOf(gamer);
                assert.equal(result.toString(), toUsd('0'));

                result = await usdtToken.balanceOf(gamer);
                assert.equal(result.toString(), toUsd('0'));
            });
            it('gamer2 requests for loan', async() => {
                amtToWithdraw = [toDai('800'), toUsd('600'), toUsd('650')];
                
                await rLoan.requestLoan(
                    amtToWithdraw, { from: gamer2 });
                
                id = await rLoan.transactionCount();
                console.log("Loan ID: ", id.toString());

                result = await rLoan.transactionCount();
                assert.equal(result.toString(), "2");
                
                // result = await royaleLP.getTransactionDetail(id.toString());
                // console.log("Before Approval: ", result);
            });
            it('signeeOne signs', async() => {
                // id = await rLoan.transactionCount();
                await rLoan.confirmLoan(id.toString(), { from: signeeOne });
            });

            it('signeeTwo signs', async() => {
                // id = await rLoan.transactionCount();
                await rLoan.confirmLoan(id.toString(), { from: signeeTwo });
            });

            it('gamer signs', async() => {
                // id = await rLoan.transactionCount();
                await rLoan.signTransaction(id.toString(), { from: gamer2 });
            });

            it('loan approved', async() => {
                // id = await rLoan.transactionCount();

                result = await rLoan.checkLoanApproved(id.toString());
                assert.equal(result, true);

                // result = await royaleLP.getTransactionDetail(id.toString());
                // console.log("After approval: ", result);
            });
           
        });

        describe('Withdraw Test', async() => {

            it('Drop a withdraw request', async() => {
                amounts = [toDai('400'), toUsd('0'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorOne });

                amounts = [toDai('0'), toUsd('0'), toUsd('300')];
                await royaleLP.requestWithdraw(amounts, { from: investorTwo });

                amounts = [toDai('0'), toUsd('370'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorThree });
                
                result = await royaleLP.isInQ(investorOne);
                assert.equal(result, true);

                console.log("Balance of investor one before withdraw request fulfilling\n")

                

                console.log("Balance of investor one before withdraw request fulfilling\n")
                result = await daiToken.balanceOf(investorOne);
                console.log(result.toString());
                result = await usdtToken.balanceOf(investorTwo);
                console.log(result.toString());
                result = await usdcToken.balanceOf(investorThree);
                console.log(result.toString());
                

                result = await royaleLP.totalWithdraw(0);
                assert.equal(result.toString(), toDai('400'));

                result = await royaleLP.totalWithdraw(1);
                assert.equal(result.toString(), toUsd('370'));

                result = await royaleLP.totalWithdraw(2);
                assert.equal(result.toString(), toUsd('300'));
            });

            it('Withdraw from 3pool and fulfill withdraw request', async() => {
                console.log("\n balance given to yield pool before\n");

                result=await royaleLP.YieldPoolBalance(0);
                console.log(result.toString());

                await royaleLP.withdraw();
                console.log("\n balance remaining to yield pool After\n");

                result=await royaleLP.YieldPoolBalance(0);
                console.log(result.toString());

                console.log("Balance of investor one before withdraw request fulfilling\n")


                result = await daiToken.balanceOf(investorOne);
                console.log(result.toString());
                result = await usdtToken.balanceOf(investorTwo);
                console.log(result.toString());
                result = await usdcToken.balanceOf(investorThree);
                console.log(result.toString());

                result = await rpToken.balanceOf(investorOne);
                console.log(result.toString());

                result = await daiToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toDai('401'));

                result = await usdcToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('300.925'));

                result = await usdtToken.balanceOf(royaleLP.address);
                assert.equal(result.toString(), toUsd('300.75'));

                lpCRV = await crvToken.balanceOf(daipool.address);
                console.log(`DaiPool CRV balance: ${lpCRV / 1e18}`);
                lpCRV = await crvToken.balanceOf(usdcpool.address);
                console.log(`USDCPool CRV balance: ${lpCRV / 1e18}`);
                lpCRV = await crvToken.balanceOf(usdtpool.address);
                console.log(`USDTPool CRV balance: ${lpCRV / 1e18}`);
                lpCRV = await crvToken.balanceOf(daipool2.address);
                console.log(`DaiPool2 CRV balance: ${lpCRV / 1e18}`);
            });
       
            it('Again Drop a withdraw request', async() => {
                amounts = [toDai('0'), toUsd('220'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorOne });

                // result = await royaleLP.isInQ(investorOne);
                // assert.equal(result, true);

                result = await daiToken.balanceOf(investorOne);
                console.log(result.toString());
                result = await usdcToken.balanceOf(investorOne);
                console.log(result.toString());
                result = await usdtToken.balanceOf(investorOne);
                console.log(result.toString());

                // result = await royaleLP.totalWithdraw(0);
                // assert.equal(result.toString(), toDai('400'));

                // result = await royaleLP.totalWithdraw(1);
                // assert.equal(result.toString(), toUsd('400'));

                // result = await royaleLP.totalWithdraw(2);
                // assert.equal(result.toString(), toUsd('400'));
            });
            it('loan withdrawn for gamer2', async() => {
                amtToWithdraw = [toDai('250'), toUsd('250'), toUsd('0')];
                 id = await rLoan.transactionCount();
                await rLoan.withdrawLoan(amtToWithdraw, id.toString(), { from: gamer2 });

                result = await daiToken.balanceOf(gamer2);
                assert.equal(result.toString(), toDai('250'));

                result = await usdcToken.balanceOf(gamer2);
                assert.equal(result.toString(), toUsd('250'));

                result = await usdtToken.balanceOf(gamer2);
                assert.equal(result.toString(), toUsd('0'));
            

            });

            it('Again Drop a withdraw request 2', async() => {
                amounts = [toDai('200'), toUsd('0'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorOne});
                
            });

            it('Again Drop a withdraw request 3', async() => {
                amounts = [toDai('250'), toUsd('0'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorTwo});
                amounts = [toDai('0'), toUsd('500'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorThree});

                console.log("\n withdraw of i2,i3  250,0,0  and 0,500,0 before......................................................")
                result = await royaleLP.totalWithdraw(0);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(1);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(2);
                console.log(result.toString());
                console.log("\n queue results withdraw of i2,i3  250,0,0  and 0,500,0 before......................................................")

                result = await royaleLP.isInQ(investorOne);
               console.log(result);

               result = await royaleLP.isInQ(investorTwo);
               console.log(result);

               result = await royaleLP.isInQ(investorThree);
               console.log(result);

                await royaleLP.withdraw();

                console.log("\n withdraw of i2,i3  250,0,0  and 0,500,0 After......................................................")
                result = await royaleLP.totalWithdraw(0);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(1);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(2);
                console.log(result.toString());

                console.log("\n queue results withdraw of  i2,i3  250,0,0  and 0,500,0 After......................................................")

                result = await royaleLP.isInQ(investorOne);
               console.log(result);

               result = await royaleLP.isInQ(investorTwo);
               console.log(result);

               result = await royaleLP.isInQ(investorThree);
               console.log(result);
            });

            it('Again Drop a withdraw request 4', async() => {
            
                amounts = [toDai('500'), toUsd('0'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorThree});

                console.log("\n withdraw of i3   500,00,0 before......................................................")
                result = await royaleLP.totalWithdraw(0);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(1);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(2);
                console.log(result.toString());
                console.log("\n queue results withdraw of i3 500,0,0 before......................................................")

                result = await royaleLP.isInQ(investorOne);
               console.log(result);

               result = await royaleLP.isInQ(investorTwo);
               console.log(result);

               result = await royaleLP.isInQ(investorThree);
               console.log(result);

                await royaleLP.withdraw();

                console.log("\n withdraw of i3 500,0,0 After......................................................")
                result = await royaleLP.totalWithdraw(0);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(1);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(2);
                console.log(result.toString());

                console.log("\n queue results withdraw of  i3  500,0,0 After......................................................")

                result = await royaleLP.isInQ(investorOne);
               console.log(result);

               result = await royaleLP.isInQ(investorTwo);
               console.log(result);

               result = await royaleLP.isInQ(investorThree);
               console.log(result);
            });
            it('Again Drop a withdraw request 5', async() => {
                amounts = [toDai('450'), toUsd('0'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorTwo});
                amounts = [toDai('0'), toUsd('350'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorThree});

                console.log("\n withdraw of i2,i3  450,0,0  and 0,350 before......................................................")
                result = await royaleLP.totalWithdraw(0);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(1);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(2);
                console.log(result.toString());
                console.log("\n queue results withdraw of i2,i3 450,0,0  and 0,350 before......................................................")

                result = await royaleLP.isInQ(investorOne);
               console.log(result);

               result = await royaleLP.isInQ(investorTwo);
               console.log(result);

               result = await royaleLP.isInQ(investorThree);
               console.log(result);

                await royaleLP.withdraw();

                console.log("\n withdraw of i2,i3  450,0,0  and 0,350 After......................................................")
                result = await royaleLP.totalWithdraw(0);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(1);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(2);
                console.log(result.toString());

                console.log("\n queue results withdraw of  i2,i3  450,0,0  and 0,350 After......................................................")

                result = await royaleLP.isInQ(investorOne);
               console.log(result);

               result = await royaleLP.isInQ(investorTwo);
               console.log(result);

               result = await royaleLP.isInQ(investorThree);
               console.log(result);
            });

            it('Again Drop a withdraw request 6', async() => {
                amounts = [toDai('0'), toUsd('450'), toUsd('0')];
                await royaleLP.requestWithdraw(amounts, { from: investorOne});
                amounts = [toDai('0'), toUsd('0'), toUsd('350')];
                await royaleLP.requestWithdraw(amounts, { from: investorTwo});

                console.log("\n withdraw of i1,i2  0,450,0  and 0,350 before......................................................")
                result = await royaleLP.totalWithdraw(0);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(1);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(2);
                console.log(result.toString());
                console.log("\n queue results withdraw of i1,i2  0,450,0  and 0,350 before......................................................")

                result = await royaleLP.isInQ(investorOne);
               console.log(result);

               result = await royaleLP.isInQ(investorTwo);
               console.log(result);

               result = await royaleLP.isInQ(investorThree);
               console.log(result);

                await royaleLP.withdraw();

                console.log("\n withdraw ofi1,i2  0,450,0  and 0,350  After......................................................")
                result = await royaleLP.totalWithdraw(0);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(1);
                console.log(result.toString());

                result = await royaleLP.totalWithdraw(2);
                console.log(result.toString());

                console.log("\n queue results withdraw of  i1,i2  0,450,0  and 0,350 After......................................................")

                result = await royaleLP.isInQ(investorOne);
               console.log(result);

               result = await royaleLP.isInQ(investorTwo);
               console.log(result);

               result = await royaleLP.isInQ(investorThree);
               console.log(result);
            });

           

            it('Rebalancing Of Tokens', async() => {

                console.log("\nTotal balance of pool\n");

                result=await royaleLP.selfBalance(0);
                console.log(result.toString());

                result=await royaleLP.selfBalance(1);
                console.log(result.toString());

                result=await royaleLP.selfBalance(2);
                console.log(result.toString());

                console.log("\nCurrent balance of royalepool\n");

                result = await daiToken.balanceOf(royaleLP.address);
                console.log(result.toString());
        
                result = await usdcToken.balanceOf(royaleLP.address);
                console.log(result.toString());
        
                result = await usdtToken.balanceOf(royaleLP.address);
                console.log(result.toString());

                console.log("\n balance given to yield pool\n");

                result=await royaleLP.YieldPoolBalance(0);
                console.log(result.toString());

                result=await royaleLP.YieldPoolBalance(1);
                console.log(result.toString());

                result=await royaleLP.YieldPoolBalance(2);
                console.log(result.toString());
        
                
                
                    
                console.log("\n balance After balancing of royalepool\n");
                
        
                result = await daiToken.balanceOf(royaleLP.address);
                console.log(result.toString());
        
                result = await usdcToken.balanceOf(royaleLP.address);
                console.log(result.toString());
        
                result = await usdtToken.balanceOf(royaleLP.address);
                console.log(result.toString());

                console.log("\n balance of Investors\n");
                result = await daiToken.balanceOf(investorOne);
                console.log(result.toString());
        
                result = await usdcToken.balanceOf(investorOne);
                console.log(result.toString());
        
                result = await usdtToken.balanceOf(investorOne);
                console.log(result.toString());

                result = await daiToken.balanceOf(investorTwo);
                console.log(result.toString());
        
                result = await usdcToken.balanceOf(investorTwo);
                console.log(result.toString());
        
                result = await usdtToken.balanceOf(investorTwo);
                console.log(result.toString());

                result = await daiToken.balanceOf(investorThree);
                console.log(result.toString());
        
                result = await usdcToken.balanceOf(investorThree);
                console.log(result.toString());
        
                result = await usdtToken.balanceOf(investorThree);
                console.log(result.toString());

                await royaleLP.rebalance({ from: owner });
            });
       
        });

        describe('LP tokens staking/unstaking', async() => {

            it('has staked 3CRV', async() => {
                lpCRV = await crvToken.balanceOf(usdcpool.address);
                console.log(`USDCPool CRV balance: ${lpCRV / 1e18}`);

                await controller.stakeLPtokens(1);

                lpCRV = await crvToken.balanceOf(usdcpool.address);
                console.log(`USDCPool CRV balance: ${lpCRV / 1e18}`);

                await controller.stakeLPtokens(1);

                lpCRV = await crvToken.balanceOf(usdcpool.address);
                console.log(`USDCPool CRV balance: ${lpCRV / 1e18}`);
            });

            it('has unstaked 3CRV', async() => {
                await controller.unstakeLPtokens(1,toDai('200'));

                lpCRV = await crvToken.balanceOf(usdcpool.address);
                console.log(`USDCPool CRV balance: ${lpCRV / 1e18}`);
            });

        });

    });

    describe('mRoyaFarm Testing', async() => {

        it('mRoyaFarm is initiated', async() => {
            result = await mRoyaFarm.mRoya();
            assert.equal(result, mRoya.address);

            result = await mRoyaFarm.rpToken();
            assert.equal(result, rpToken.address);
        });

        it('investor got reward', async() => {
            result = await mRoyaFarm.calculateMRoya(investorOne);
            console.log((result / 1e18).toString());
        });

    });

   

});

