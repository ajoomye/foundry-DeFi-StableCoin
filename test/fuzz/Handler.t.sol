// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {

    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT = type(uint96).max;
    address[] usersWithCollateralDeposited;
    MockV3Aggregator public ethUsdPriceFeed;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        dsce = _engine;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
    }

    function updateCollateralPrice(uint96 newPrice) public {
        int256 newPriceInt = int256(uint256(newPrice));
        ethUsdPriceFeed.updateAnswer(newPriceInt);
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {

        if(usersWithCollateralDeposited.length == 0){
            return;
        }

        amount = bound(amount, 1, MAX_DEPOSIT);
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUSD) = dsce.getAccountInfo(msg.sender);
        uint256 maxDsctoMint = (collateralValueInUSD / 2) - totalDscMinted;
        if(maxDsctoMint < 0){
            return;
        }

        amount = bound(amount, 0, maxDsctoMint);
        if(amount < 0){
            return;
        }

        vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
    }


    //reddeem collateral
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) 
    public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        usersWithCollateralDeposited.push(msg.sender);
        
    }

    //Helper function
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock){
        if(collateralSeed % 2 == 0){
            return weth;
        }
        return wbtc;
    }
    
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral)
    public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateraltoRedeem = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, maxCollateraltoRedeem); 
        if(amountCollateral == 0){
        return;
        }
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }


}