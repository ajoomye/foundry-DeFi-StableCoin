// //Invariants:
// // Total number of DSC should be less than the total collateral
// // Getter view functions should never revert

// //NOTE: This test is not complete. It is just a template for the invariants test

// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.28;

// import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
// import {DSCEngine} from "src/DSCEngine.sol";
// import {Test, console} from "forge-std/Test.sol";
// import {DeployDSC} from "script/DeployDSC.s.sol";
// import {HelperConfig} from "script/HelperConfig.s.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract InvariantTests is StdInvariant, Test {
//     DeployDSC public deployDSC;
//     DSCEngine public dscEngine;
//     HelperConfig config;
//     DecentralizedStableCoin public dsc;
//     address weth;
//     address wbtc;

//     function setUp() external {
//         deployDSC = new DeployDSC();
//         (dsc, dscEngine, config) = deployDSC.run();
//         ( , , weth, wbtc, ) = config.activeNetworkConfig();
//         targetContract(address(dscEngine));
//     }

//     function invariant_protocolMustHaveMoreValuethanTotalSupply() public view {
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWeth = IERC20(weth).balanceOf(address(dscEngine));
//         uint256 totalWbtc = IERC20(wbtc).balanceOf(address(dscEngine));

//         uint256 wethValue = dscEngine.getUsdValue(weth, totalWeth);
//         uint256 wbtcValue = dscEngine.getUsdValue(wbtc, totalWbtc);

//         console.log("Total Supply:", totalSupply);
//         console.log("WETH Value:", wethValue);
//         console.log("WBTC Value:", wbtcValue);

//         assert(wethValue + wbtcValue > totalSupply);
//     }



// }