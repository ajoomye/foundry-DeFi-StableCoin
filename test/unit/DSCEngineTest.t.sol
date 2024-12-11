// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {Test} from "forge-std/Test.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DSCEngineTest is Test {
    DeployDSC deployDSC;
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    HelperConfig config;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, dscEngine, config) = deployDSC.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, , ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    //// CONSTRUCTOR TESTS ////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfTokenLengthDoesNotMatchPriceFeedLength() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //// PRICE TESTS ////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dscEngine.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 30000e18;
        uint256 expectedTokenAmount = 15e18;
        uint256 actualTokenAmount = dscEngine.getTokenAmountinUsd(weth, usdAmount);
        assertEq(actualTokenAmount, expectedTokenAmount);
    }

    //// DEPOSIT COLLATERAL TESTS ////

    function testRevertIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NotMorethanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, 1000e18);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotSupported.selector);
        dscEngine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 collateral, uint256 dscMinted) = dscEngine.getAccountInfo(USER);
        uint256 expectedMinted = 0;
        uint256 expectedCollateralValue = dscEngine.getTokenAmountinUsd(weth, collateral);
        assertEq(expectedCollateralValue, AMOUNT_COLLATERAL);
        assertEq(dscMinted, expectedMinted);
    }

    //// MINT DSC TESTS ////

    function testRevertIfMintingZeroDsc() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotMorethanZero.selector);
        dscEngine.mintDsc(0);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositCollateral {
        uint256 mintAmount = 5 ether; // Safe minting amount
        vm.startPrank(USER);
        dscEngine.mintDsc(mintAmount);
        vm.stopPrank();

        (uint256 collateral, uint256 userMintedDsc) = dscEngine.getAccountInfo(USER);
        assertEq(userMintedDsc, mintAmount);

    }

    //// LIQUIDATION TESTS ////

    //// REDEEM COLLATERAL TESTS ////

    function testRevertIfRedeemingZeroCollateral() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotMorethanZero.selector);
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }


}
