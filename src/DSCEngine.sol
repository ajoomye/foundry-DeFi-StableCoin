//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "src/libraries/OracleLib.sol";

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

/**
    * @title DSEngine
    * @author Abdurraheem Joomye
    * @dev A logic contract for a StableCoin using Solidity 
    * @notice This contract is the logic for a StableCoin that is decentralized and anchored to the value of the US Dollar
    * This system is designed to be minimal and be pegged to 1 USD
    * It is backed by wETH and wBTC
    * This contract Very loosely based on the MakerDAO DSS (DAI) system
    * Our DSC system should be overcottarelized
 */

contract DSCEngine is ReentrancyGuard {

    ////ERRORS////
    error DSCEngine__NotMorethanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
    error DSCEngine__TokenNotSupported();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorBelowThreshold(uint256 userHealthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOkay(uint256 userHealthFactor);
    error DSCEngine__HealthFactorNotImproved(uint256 endingHealthFactor);

    ////TYPE////
    using OracleLib for AggregatorV3Interface;

    ////STATE VARIABLES////
    uint256 private constant ADDITIONAL_PRICEFEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MINHEALTHFACTOR = 1e18;
    uint256 private constant LIQUIDATOR_BONUS = 10;
    

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;
    
    ////EVENTS////
    event CollateralDeposited(address indexed user, address indexed tokenCollateral, uint256 amountCollateral);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed tokenCollateral, uint256 amountCollateral);

    ////MODIFIERS////
    modifier MoreThanZero(uint256 amount){
        if(amount == 0){
            revert DSCEngine__NotMorethanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenCollateral){
        if(s_priceFeeds[tokenCollateral] == address(0)){
            revert DSCEngine__TokenNotSupported();
        }
        _;

    }

    ////FUNCTIONS////
    constructor(address[] memory tokenAddresses, 
    address[] memory priceFeedAddresses,
    address dscAddress
    ){
        // USD Price Feeds needed
        if (tokenAddresses.length != priceFeedAddresses.length){
            revert DSCEngine__TokenAddressAndPriceFeedAddressMustBeSameLength();
        }

        for (uint i = 0; i < tokenAddresses.length; i++){
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
        
    }

    //EXTERNAL FUNCTIONS//

    /*
     * @param tokenCollateralAddress: The address of the deposit Token
     * @param amountCollateral: The amount of collateral to deposit
     * @param amountDsctomint: The amount of Dsc to mint
     * @notice This function is a convenience function to deposit collateral and mint Dsc
     */
    function depositCollateralandMintDsc(address tokenCollateralAddress, 
    uint256 amountCollateral, uint256 amountDsctomint) external {

        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDsctomint);
    }


    /*
     * @Following CEI pattern
     * @param tokenCollateral: The address of the deposit Token
     * @param amountCollateral: The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) 
    public MoreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress)
    nonReentrant {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        
    }

    /*
     * @param tokenCollateralAddress: The address of the deposit Token
     * @param amountCollateral: The amount of collateral to redeem
     * @param amountDsctoburn: The amount of Dsc to burn
     * @notice This function is a convenience function to redeem collateral and burn Dsc
     */
    function redeemCollateralforDsc(address tokenCollateralAddress,
    uint256 amountCollateral, uint256 amountDsctoburn) external {
        burnDsc(amountDsctoburn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        //Redeem collateral already checks health factor
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
    public MoreThanZero(amountCollateral) nonReentrant {
        //Health Factor must be above 1
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);

        _revertIfHealthFactorIsBroken(msg.sender);

    }

    /*
     * @Following CEI pattern
     * @param amountDscToMint: The amount of Dsc to mint
     * @notice they must have more collateral than the minimum threshold
     */
    function mintDsc(uint256 amountDsctomint) 
    public MoreThanZero(amountDsctomint) nonReentrant {
        s_DscMinted[msg.sender] += amountDsctomint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDsctomint);
        if (!minted){
            revert DSCEngine__MintFailed();
        }
    }
   

    function burnDsc(uint256 amount) public MoreThanZero(amount) {

        _burnDsc(amount, msg.sender, msg.sender);        
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @param collateral: The address of the collateral token
     * @param user: The address of the user to liquidate. Their health factor must be below 1
     * @param debttoCover: The amount of debt to cover
     * @notice You can partially liquidate a user
     * @notice You will get the collateral at a discount
     */
    function liquidate(address collateral, address user, uint256 debttoCover) external
    MoreThanZero(debttoCover) nonReentrant {
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= MINHEALTHFACTOR){
            revert DSCEngine__HealthFactorOkay(startingHealthFactor);
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountinUsd(collateral, debttoCover);

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATOR_BONUS) / LIQUIDATION_PRECISION;
        uint256 collateralToSeize = tokenAmountFromDebtCovered + bonusCollateral;
        
        _redeemCollateral(collateral, collateralToSeize, user, msg.sender);

        _burnDsc(debttoCover, user, msg.sender);

        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= startingHealthFactor){
            revert DSCEngine__HealthFactorNotImproved(endingHealthFactor);
        }

        _revertIfHealthFactorIsBroken(msg.sender);


    }

    function getHealthFactor() external view {}

    //PRIVATE AND INTERNAL FUNCTIONS//

    function _getAccountInformation(address user) private view returns (uint256 collateralValueInUsd, uint256 dscValueMinted) {
        dscValueMinted = s_DscMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
        return (collateralValueInUsd, dscValueMinted);
    }

    // Returns how close to Liquidation the user is
    function _healthFactor(address user) private view returns (uint256) {
        //1. Get the value of the collateral
        //2. Get the value of the DSC 
        (uint256 collateralValueInUsd, uint256 dscValueMinted) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / dscValueMinted;

    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        //1. Check Health Factor
        //2. Revert if they do not have enough collateral
        uint256 userhealthFactor = _healthFactor(user);
        if (userhealthFactor < MINHEALTHFACTOR){
            revert DSCEngine__HealthFactorBelowThreshold(userhealthFactor);
        }

    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to) internal {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function _burnDsc(uint256 amountDsctoburn, address onBehalOf, address dscFrom) private {
        s_DscMinted[onBehalOf] -= amountDsctoburn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDsctoburn);
        if (!success){
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDsctoburn);

    }

    //VIEW AND PURE FUNCTIONS//

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.staleCheckLatestPrice();
        return (amount * (uint256(price) * ADDITIONAL_PRICEFEED_PRECISION)) / PRECISION;

    }
    
    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalcollateralValue) {
        // Loop through all the collateral tokens, get the value of the collateral 
        // and map to the price
        for (uint i = 0; i < s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalcollateralValue += getUsdValue(token, amount);
        }
        return totalcollateralValue;
        
    }

    function getTokenAmountinUsd(address token, uint256 amountinWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.staleCheckLatestPrice();
        return((amountinWei * PRECISION)/(uint256(price) * ADDITIONAL_PRICEFEED_PRECISION));

    }

    function getAccountInfo(address user) public view returns (uint256 collateralValueInUsd, uint256 dscValueMinted) {
        (collateralValueInUsd, dscValueMinted) =  _getAccountInformation(user);
    }

    function getHealthFactor(address user) public view returns (uint256) {
        return _healthFactor(user); 
}

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }




}