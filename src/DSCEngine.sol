// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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
// view & pure functions

pragma solidity 0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Nathaniel Yeboah
 *
 * the system is designed to be as minimal as possible, and have the tokens maintain a 1token == $1 peg.
 * this stablecon has the properites
 *  - exogenous collateral
 * - dollar pegged
 * -algoritmicall
 *
 * Our DSC system should always be "overcollateralized", there should be more collar
 *
 * it is similar to DAI if DAI had no governace , no feess, and was only back ed by WETH and WBTc
 *
 * @notice This contrct is the conre othe DSC Sustem. It handels all the logic for mining and redeem DSC, as well
 * as deposingg & withdrawing collateral.
 * @notice this contract is VERY lossely based on the MakerDAO DSS(DAI) system
 */
contract DSCEngine is ReentrancyGuard {
    /////////////////
    /// Errors  ///
    /////////////////
    error DSC__ShouldBeMoreThanZero();
    error DSC__tokenAdressesAndPriceFeedAddressesMustBeSameLength();
    error DSC__TokenNotAllowed();
    error DSC__TransferFailed();
    error DSC__HealthFactorBroken(uint256 userHealthFactor);
    error DSC__MintFailed();

    ////////////////////////
    /// State variables  ///
    ////////////////////////
    mapping(address tokenAddress => address priceFeed) private s_tokenToPriceFeed;
    mapping(address user => mapping(address tokenAdress => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;

    address[] private s_tokenAddresses;

    DecentralizedStableCoin private immutable i_dsc;

    uint256 private constant PRICE_PRECISION_CHAINLINK = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    ////////////////////////
    /// Events  ///
    ////////////////////////
    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);

    /////////////////
    /// Modifier  ///
    /////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSC__ShouldBeMoreThanZero();
        }
        _;
    }

    modifier isAllowToken(address _token) {
        if (s_tokenToPriceFeed[_token] == address(0)) {
            revert DSC__TokenNotAllowed();
        }
        _;
    }

    /////////////////
    /// Function  ///
    /////////////////

    constructor(address[] memory _tokenAdresses, address[] memory _priceFeedAddresses, address _dscAddress) {
        if (_tokenAdresses.length != _priceFeedAddresses.length) {
            revert DSC__tokenAdressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < _tokenAdresses.length; i++) {
            s_tokenToPriceFeed[_tokenAdresses[i]] = _priceFeedAddresses[i];
            s_tokenAddresses.push(_tokenAdresses[i]);
        }

        i_dsc = DecentralizedStableCoin(_dscAddress);
    }

    //////////////////////////////
    /// External Function  //////
    ////////////////////////////

    function depositCollateralAndMintDSC() external {}

    /**
     * @notice follows the CEI standards
     * @param tokenCollateralAdress : The address of the token to deposit as collateral
     * @param amountCollateral : the amount of collateral to Deposit
     */
    function depositCollateral(address tokenCollateralAdress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowToken(tokenCollateralAdress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAdress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAdress, amountCollateral);
        bool success = IERC20(tokenCollateralAdress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSC__TransferFailed();
        }
    }

    function redeemCollateralForDSC() external {}

    function redeemCollateral() external {}
    // check if the collateral value > DSC amount . price feed  values

    /**
     *
     * @param _amountDSCToMint  The amoount of Decentralized StableCoin to mint
     * @notice they must have more collateral value than the minimum threshold
     */
    function mintDSC(uint256 _amountDSCToMint) external moreThanZero(_amountDSCToMint) nonReentrant {
        s_DscMinted[msg.sender] += _amountDSCToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, _amountDSCToMint);
        if (!minted) {
            revert DSC__MintFailed();
        }
    }

    function burnDSC() external {}

    function liquidate() external {}

    function get_HealthFactor() external view {}

    /////////////////////////////////////////
    /// Private and Internal Function  //////
    /////////////////////////////////////////
    function _getAccountInformation(address _user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DscMinted[_user];
        collateralValueInUsd = getAccountCollateralValue(_user);
    }

    /**
     * @notice returns how close to liqudation a user is
     * if the a users goers belwow 1 , then they can get liquidated
     * @param _user  address of the user
     */
    function _healthFactor(address _user) internal view returns (uint256) {
        // get total DSC minted for the user
        //  get the entire collateral values

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(_user);
        uint256 collateratalAdjustedForThreshold =
            (collateralValueInUsd * LIQUIDATION_THRESHOLD) * LIQUIDATION_PRECISION;
        return (collateratalAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    ///
    /// @param _user  should be able to get the collatrized position
    ///1. check healthe factor
    /// 2. revert if the dont have the health factor
    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSC__HealthFactorBroken(userHealthFactor);
        }
    }

    /////////////////////////////////////////
    /// Private and Internal Function  //////
    /////////////////////////////////////////

    /**
     * @notice this function  gets the USD equivalant of the collateral
     * @param _tokenAdress , the token address of the collateral
     * @param _amount , the amount of collateral the user has in wei
     * @notice Chainlink Price address will return a value with 8 decimals ,
     * the constant PRICE_PRECISION_CHAINLINK add enough zero to be 1e18
     */
    function getAmountInUsd(address _tokenAdress, uint256 _amount) public view returns (uint256) {
        address priceFeedAddress = s_tokenToPriceFeed[_tokenAdress];
        (, int256 price,,,) = AggregatorV3Interface(priceFeedAddress).latestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return (_amount * (uint256(price) * PRICE_PRECISION_CHAINLINK) / PRECISION);
    }

    function getAccountCollateralValue(address _user) public view returns (uint256 totalCollatralValueInUsd) {
        // loop through each collatoral token , get  amount deposited , and convert it to usd

        for (uint256 i = 0; i < s_tokenAddresses.length; i++) {
            address token = s_tokenAddresses[i];
            uint256 amount = s_collateralDeposited[_user][token];
            totalCollatralValueInUsd += getAmountInUsd(token, amount);
        }
    }

    /////////////////////////////////////////
    /// Getters and Public Function  ///////
    /////////////////////////////////////////

    /**
     *
     * @param _index of the s_tokenAddress
     * @notice index 0 is weth address
     * @notice index 1 is wbtc address
     */
    function getTokenaddress(uint256 _index) public view returns (address) {
        return s_tokenAddresses[_index];
    }

    function getCollateralDeposited(address _user, address token) public view returns (uint256) {
        return s_collateralDeposited[_user][token];
    }
}
