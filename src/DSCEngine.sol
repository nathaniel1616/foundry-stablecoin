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
import {OracleLib} from "./OracleLib.sol";

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
    //////////////////
    /// Libraries  ///
    //////////////////
    using OracleLib for AggregatorV3Interface;

    /////////////////
    /// Errors  ///
    /////////////////
    error DSCEngine__ShouldBeMoreThanZero();
    error DSCEngine__tokenAdressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorBroken(uint256 userHealthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorDidImproved();
    error DSCEngine__UserHasNotDepositedCollateral();
    error DSCEngine__UserDoesNotHaveEnoughCollateral();

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
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    ////////////////////////
    /// Events  ///
    ////////////////////////
    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed fromUser, address indexed toUser, address indexed tokenAddress, uint256 amount
    );

    /////////////////
    /// Modifier  ///
    /////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__ShouldBeMoreThanZero();
        }
        _;
    }

    modifier isAllowToken(address _token) {
        if (s_tokenToPriceFeed[_token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    /////////////////
    /// Function  ///
    /////////////////

    constructor(address[] memory _tokenAdresses, address[] memory _priceFeedAddresses, address _dscAddress) {
        if (_tokenAdresses.length != _priceFeedAddresses.length) {
            revert DSCEngine__tokenAdressesAndPriceFeedAddressesMustBeSameLength();
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

    /**
     *
     * @param tokenCollateralAdress The adddress of the ERC token to be deposited
     * @param amountCollateral The amount of the collaletaral to deposited  in wei
     * @param _amountDSCToMint the amount of DSC to mint in wei
     */
    function depositCollateralAndMintDSC(
        address tokenCollateralAdress,
        uint256 amountCollateral,
        uint256 _amountDSCToMint
    ) external {
        depositCollateral(tokenCollateralAdress, amountCollateral);
        mintDSC(_amountDSCToMint);
    }

    /**
     * @notice follows the CEI standards
     * @param tokenCollateralAdress : The address of the token to deposit as collateral
     * @param amountCollateral : the amount of collateral to Deposit
     * @notice this function will deposit collateral and mint collateral in a single transaction
     */
    function depositCollateral(address tokenCollateralAdress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowToken(tokenCollateralAdress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAdress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAdress, amountCollateral);
        bool success = IERC20(tokenCollateralAdress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDSC(address _tokenAddress, uint256 _amountCollateral, uint256 amountDscToBurn)
        external
        moreThanZero(_amountCollateral)
    {
        burnDSC(amountDscToBurn);
        redeemCollateral(_tokenAddress, _amountCollateral);
        //redeemCollateral already checks for _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice reddeeming collateral  has to check if the user has collateral and no outstanding positions
     * the will automatically liquidaate the collatoral position
     * @param _tokenAddress   the token address of the collateral to redeem
     * @param  _amount   the amount to redeem in wei
     */
    function redeemCollateral(address _tokenAddress, uint256 _amount)
        public
        nonReentrant
        moreThanZero(_amount)
        isAllowToken(_tokenAddress)
    {
        _redeemCollateral(_tokenAddress, msg.sender, msg.sender, _amount);

        _revertIfHealthFactorIsBroken(msg.sender);
    }
    // check if the collateral value > DSC amount . price feed  values

    /**
     *
     * @param _amountDSCToMint  The amoount of Decentralized StableCoin to mint
     * @notice they must have more collateral value than the minimum threshold
     */
    function mintDSC(uint256 _amountDSCToMint) public moreThanZero(_amountDSCToMint) nonReentrant {
        s_DscMinted[msg.sender] += _amountDSCToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, _amountDSCToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    // user should have allowance on dsc to this contact in order to burn
    function burnDSC(uint256 _amount) public moreThanZero(_amount) {
        _burnDSC(msg.sender, msg.sender, _amount);
        _revertIfHealthFactorIsBroken(msg.sender); //this line wiil  not be hit
    }
    /**
     * @notice if someone is almost undercollatoralizsed we will pay you to liquidate them
     * @param collateralTokenAddress The address of the token of the collateral
     * @param user  The address of the user to liquidate
     * @param debtToCover  the amount of DSC you want to burn in wei
     * @notice  you can particially liquadate a user  as long as you improve their health factor
     * @notice you will get a liquidation bonus for taking the users funds
     */

    function liquidate(address collateralTokenAddress, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // gethealthfactor of account
        // if it is undercollatrilized or less than one  , any user can liquidate
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) revert DSCEngine__HealthFactorOk();
        // we want to burn their dsc "debt"
        //  and take their collateral
        // eg bad user $140eth , $100DSC
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralTokenAddress, debtToCover);
        // give them a 10% bonus
        // so  we give the liquidate $110 of WETH for 100DSC
        //  we should implete a feature to liquidate in the event the protocol is insolvent
        uint256 bonusCollatoral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralRedeemed = tokenAmountFromDebtCovered + bonusCollatoral;
        _redeemCollateral(collateralTokenAddress, user, msg.sender, totalCollateralRedeemed);
        // burn the dsc now
        // burnDSC();
        _burnDSC(user, msg.sender, debtToCover);

        uint256 endingUserHealthFactor = _healthFactor(user);

        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorDidImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /////////////////////////////////////////
    /// Private and Internal Function  //////
    /////////////////////////////////////////

    /**
     * @dev low level internal function , do not call unless the function calling it is
     * checking for the health factors being broken
     */
    function _burnDSC(address userToBurnFrom, address userCallingTheBurn, uint256 _amountToBurn) private {
        s_DscMinted[userToBurnFrom] -= _amountToBurn;
        bool success = i_dsc.transferFrom(userCallingTheBurn, address(this), _amountToBurn);
        // this condition may hypotically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(_amountToBurn);
    }

    function _redeemCollateral(address _tokenAddress, address _fromUser, address _toUser, uint256 _amount) private {
        // when user has not deposited collateral
        if (s_collateralDeposited[_fromUser][_tokenAddress] == 0) {
            revert DSCEngine__UserHasNotDepositedCollateral();
        }
        //  when user tries to writhdrawl more than they have
        if (s_collateralDeposited[_fromUser][_tokenAddress] < _amount) {
            revert DSCEngine__UserDoesNotHaveEnoughCollateral();
        }
        s_collateralDeposited[_fromUser][_tokenAddress] -= _amount; // if user tries to withdrawl more than require , the tranasction reverts, solidity complier
        emit CollateralRedeemed(_fromUser, _toUser, _tokenAddress, _amount);
        bool sucess = IERC20(_tokenAddress).transfer(_toUser, _amount);
        if (!sucess) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address _user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DscMinted[_user];
        collateralValueInUsd = getAccountCollateralValueInUsd(_user);
    }

    /**
     * @notice returns how close to liqudation a user is
     * if the a users goers belwow 1 , then they can get liquidated
     * @param _user  address of the user
     */
    function _healthFactor(address _user) internal view returns (uint256 healthFactor) {
        // get total DSC minted for the user
        //  get the entire collateral values

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(_user);

        healthFactor = _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    // calculate healthfactor function

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) {
            // in the case where the user has no collateral and no DSC , the health factor will be 1
            // this is the only time the health factor will be MIN_HEALTH_FACTOR
            // returns the maximum value of uint256
            return type(uint256).max;
        }
        uint256 collateratalAdjustedForThreshold =
            (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateratalAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    ///
    /// @param _user  should be able to get the collatrized position
    ///1. check healthe factor
    /// 2. revert if the dont have the health factor
    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorBroken(userHealthFactor);
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
        (, int256 price,,,) = AggregatorV3Interface(priceFeedAddress).stalePrice();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return (_amount * (uint256(price) * PRICE_PRECISION_CHAINLINK) / PRECISION);
    }

    function getAccountCollateralValueInUsd(address _user) public view returns (uint256 totalCollatralValueInUsd) {
        // loop through each collatoral token , get  amount deposited , and convert it to usd

        for (uint256 i = 0; i < s_tokenAddresses.length; i++) {
            address token = s_tokenAddresses[i];
            uint256 amount = s_collateralDeposited[_user][token];
            totalCollatralValueInUsd += getAmountInUsd(token, amount);
        }
        return totalCollatralValueInUsd;
    }

    /////////////////////////////////////////
    /// Getters and Public Function  ///////
    /////////////////////////////////////////

    function getHealthFactor(address _user) external view returns (uint256) {
        return _healthFactor(_user);
    }

    function calculatedHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }
    /**
     * @notice this function is to covert the USD price of the token to the number of token you
     * can get for it . eg
     * 1 ETH  equals $2500usd
     * how many eth can you get if you have $400 .
     * calculation will be ($400 / $2500)  * 1 ETH
     * @param tokenAddress Address of the token
     * @param usdAmountInWei The USD amount to convert to amount crypto you can have
     */

    function getTokenAmountFromUsd(address tokenAddress, uint256 usdAmountInWei)
        public
        view
        returns (uint256 amountOfToken)
    {
        address priceFeedAddress = s_tokenToPriceFeed[tokenAddress];
        (, int256 price,,,) = AggregatorV3Interface(priceFeedAddress).stalePrice();
        //        eg.    ($10e18 )
        amountOfToken = (usdAmountInWei * PRECISION) / (uint256(price) * PRICE_PRECISION_CHAINLINK);
    }

    /**
     *
     * @param _index of the s_tokenAddress
     * @notice index 0 is weth address
     * @notice index 1 is wbtc address
     */
    function getTokenaddress(uint256 _index) public view returns (address) {
        return s_tokenAddresses[_index];
    }

    function getPriceFeedAddressFromTokenAddress(address token) public view returns (address) {
        return s_tokenToPriceFeed[token];
    }

    function getCollateralDeposited(address _user, address token) public view returns (uint256) {
        return s_collateralDeposited[_user][token];
    }

    function getDscMintedBy(address _user) public view returns (uint256) {
        return s_DscMinted[_user];
    }

    // get Account Information of User
    function getAccountInformation(address _user)
        public
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(_user);
    }

    function getMinimumHealthFactor() public pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getPricePrecisionChainlink() public pure returns (uint256) {
        return PRICE_PRECISION_CHAINLINK;
    }

    function getPrecision() public pure returns (uint256) {
        return PRECISION;
    }

    function getLiquidationThreshold() public pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() public pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() public pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }
}
