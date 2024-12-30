// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./StakingDelegate.sol";
import "./VETHTokenContract.sol";

contract LiquidStaking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // Constant

    // VETH Token
    string private constant VETH_DISPLAY_NAME = "VestaXStakedETH";
    string private constant VETH_TICKER = "VETH";
    uint256 private constant VETH_DECIMALS = 18;
    uint256 private constant ONE_VETH_IN_WEI = 1 ether;

    uint256 private constant ONE_ETH_IN_WEI = 1 ether;
    uint256 private constant MAX_PERCENTAGE = 10000; // 100.00%

    // Delegate
    uint256 private constant DELEGATE_MIN_AMOUNT = 0.01 ether;

    // Unbond
    uint256 private constant MIN_UNBONDING_PERIOD = 10 days;
    uint256 private constant MAX_UNBONDING_PERIOD = 30 days;

    // User withdraw
    uint256 private constant MAX_LOOP_IN_USER_WITHDRAW = 10;

    // Miscellaneous
    uint256 private constant EXPIRATION_BLOCKNUMBER_COUNT = 5; // Not directly applicable, but can be used for similar purposes

    // Error

    string private constant ERROR_ZERO_AMOUNT = "Zero amount";

    // Context

    // Structure representing an individual unstaking pack.
    struct UnstakingPack {
        uint256 amount;
        uint256 timestamp;
    }

    // Structure representing the settings for the liquid staking contract.
    struct LiquidStakingSettings {
        address VETH_identifier;
        address treasuryWallet;
        uint256 fee;
        uint256 unbondingPeriod;
        address[] admins;
        bool userActionAllowed;
        bool managementActionAllowed;
        address autoDelegateAddress;
        address autoUndelegateAddress;
        uint256 poolVETHAmount;
        uint256 poolETHAmount;
        uint256 prestakedETHAmount;
        uint256 preunstakedETHAmount;
        uint256 unbondedETHAmount;
        uint256 pendingRewardETHAmount;
        uint256 VETHPrice;
    }

    // Structure representing the unstaking packs for a specific user.
    struct UserUnstakingPacks {
        address userAddress;
        UnstakingPack[] packs;
    }

    // Common Storage
    VETHTokenContract VETHToken;

    // Treasury Wallet
    address public treasuryWallet;

    // Fee
    uint256 public fee;

    // Unbonding Period
    uint256 public unbondingPeriod;

    // Admins
    mapping(address => bool) public admins;
    address[] public adminList;

    // User Action Allowed
    bool public userActionAllowed;

    // Management Action Allowed
    bool public managementActionAllowed;

    // Whitelisted Staking Provider Addresses
    mapping(address => bool) public whitelistedSpAddresses;

    // Auto Delegate Address
    address public autoDelegateAddress;

    // Auto Undelegate Address
    address public autoUndelegateAddress;

    // Pool Storage

    // Total delegated ETH amount in Delegate SCs (excluding undelegating or undelegated ETH)
    uint256 public poolETHAmount;
    uint256 public poolVETHAmount;

    // PreStake Pool
    // Total prestaked amount
    uint256 public prestakedETHAmount;

    // Total pending reward ETH amount
    uint256 public pendingRewardETHAmount;

    // PreUnstake Pool
    // Total preunstaked ETH amount
    uint256 public preunstakedETHAmount;

    // Unstaking Packs
    mapping(address => UnstakingPack[]) public unstakingPacks;
    mapping(address => bool) public unstakingUsers;
    address[] public unstakingUsersList;

    // Unbonded Pool
    // Total unbonded ETH amount
    uint256 public unbondedETHAmount;

    // Additional Mappers
    // Total undelegated ETH amount
    uint256 public totalUndelegatedETHAmount;

    // Total old preunstaked ETH amount
    uint256 public totalOldPreunstakedETHAmount;

    // Mapping for recent preunstaked ETH amounts
    mapping(uint256 => uint256) public recentPreunstakedETHAmountsMap;
    uint256[] public recentPreunstakedETHAmountsMapKeys;

    // Event

    // User Activities
    event UserStake(address indexed caller, uint256 ETHAmount, uint256 VETHAmount, uint256 timestamp);
    event UserUnstake(address indexed caller, uint256 VETHAmount, uint256 ETHAmount, uint256 timestamp);
    event UserWithdraw(address indexed caller, uint256 ETHAmount, uint256 timestamp);
    event Donate(address indexed caller, uint256 ETHAmount, uint256 timestamp);

    // Admin
    event DelegateToStakingProviderSuccess(address indexed caller, address indexed delegateAddress, uint256 ETHAmount, uint256 timestamp);
    event DelegateToStakingProviderFail(address indexed caller, address indexed delegateAddress, uint256 ETHAmount, uint256 timestamp);
    event UndelegateFromStakingProviderSuccess(address indexed caller, address indexed delegateAddress, uint256 ETHAmount, uint256 timestamp);
    event UndelegateFromStakingProviderFail(address indexed caller, address indexed delegateAddress, uint256 ETHAmount, uint256 timestamp);
    event WithdrawFromStakingProviderSuccess(address indexed caller, address indexed delegateAddress, uint256 ETHAmount, uint256 timestamp);
    event WithdrawFromStakingProviderFail(address indexed caller, address indexed delegateAddress, uint256 timestamp);
    event WithdrawFromPrestaked(address indexed caller, uint256 ETHAmount, uint256 timestamp);

    // Rewards
    event ClaimRewardsFromStakingProviderSuccess(address indexed caller, address indexed delegateAddress, uint256 rewardsETHAmount, uint256 timestamp);
    event ClaimRewardsFromStakingProviderFail(address indexed caller, address indexed delegateAddress, uint256 timestamp);

    // Admin Settings
    event ChangeTreasuryWallet(address indexed caller, address indexed to, uint256 timestamp);
    event ChangeFee(address indexed caller, uint256 fee, uint256 timestamp);

    // Init

    constructor() Ownable(msg.sender) {
        VETHToken = new VETHTokenContract(VETH_DISPLAY_NAME, VETH_TICKER);
    }

    receive() external payable {
        // Allow contract to receive ETH
    }

    // Validation

    function isOwnerOrAdmin(address _address) internal view returns (bool) {
        return _address == owner() || admins[_address];
    }

    // Amm

    // Function to quote VETH based on ETH amount
    function quoteVETH(uint256 ETHAmount) public view returns (uint256) {
        require(poolETHAmount != 0, "pool_ETH_amount is zero");
        return poolVETHAmount.mul(ETHAmount).div(poolETHAmount);
    }

    // Function to quote ETH based on VETH amount
    function quoteETH(uint256 VETHAmount) public view returns (uint256) {
        require(poolVETHAmount != 0, "pool_VETH_amount is zero");
        return poolETHAmount.mul(VETHAmount).div(poolVETHAmount);
    }

    // Config

    function setSettings(
        uint256 _unbondingPeriod,
        address _treasuryWallet,
        uint256 _fee,
        bool _userActionAllowed,
        bool _managementActionAllowed
    ) external onlyOwner {
        setUnbondingPeriod(_unbondingPeriod);
        setTreasuryWallet(_treasuryWallet);
        setFee(_fee);
        setUserActionAllowed(_userActionAllowed);
        setManagementActionAllowed(_managementActionAllowed);
    }

    function setUnbondingPeriod(uint256 _unbondingPeriod) public onlyOwner {
        require(_unbondingPeriod >= MIN_UNBONDING_PERIOD && _unbondingPeriod <= MAX_UNBONDING_PERIOD, "unbonding_period must be in range");
        unbondingPeriod = _unbondingPeriod;
    }

    function setTreasuryWallet(address _treasuryWallet) public onlyOwner {
        require(
            _treasuryWallet != address(0),
            "Zero address"
        );
        treasuryWallet = _treasuryWallet;
        emit ChangeTreasuryWallet(msg.sender, _treasuryWallet, block.timestamp);
    }

    function setFee(uint256 _fee) public onlyOwner {
        require(_fee <= MAX_PERCENTAGE, "fee cannot be higher than 100%.");
        fee = _fee;
        emit ChangeFee(msg.sender, _fee, block.timestamp);
    }

    function addAdmins(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            admins[_addresses[i]] = true;
            adminList.push(_addresses[i]);
        }
    }

    function removeAdmins(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            delete admins[_addresses[i]];
            for(uint256 j = 0; j < adminList.length; j ++) {
                if(adminList[j] == _addresses[i]) {
                    adminList[j] = adminList[adminList.length - 1];
                    adminList.pop();
                    break;
                }
            }
        }
    }

    function addWhitelistedSpAddresses(
        address[] calldata _addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(isSmartContract(_addresses[i]), "Given address is not smart contract");
            whitelistedSpAddresses[_addresses[i]] = true;
        }
    }

    function removeWhitelistedSpAddresses(
        address[] calldata _addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            delete whitelistedSpAddresses[_addresses[i]];
        }
    }

    function setAutoDelegateAddress(address _autoDelegateAddress) external {
        require(isOwnerOrAdmin(msg.sender), "You are not Owner or Admin.");
        require(
            whitelistedSpAddresses[_autoDelegateAddress],
            "Given Staking Provider is not whitelisted"
        );
        autoDelegateAddress = _autoDelegateAddress;
    }

    function removeAutoDelegateAddress() external {
        require(isOwnerOrAdmin(msg.sender), "You are not Owner or Admin.");
        autoDelegateAddress = address(0);
    }

    function setAutoUndelegateAddress(address _autoUndelegateAddress) external {
        require(isOwnerOrAdmin(msg.sender), "You are not Owner or Admin.");
        autoUndelegateAddress = _autoUndelegateAddress;
    }

    function removeAutoUndelegateAddress() external {
        require(isOwnerOrAdmin(msg.sender), "You are not Owner or Admin.");
        autoUndelegateAddress = address(0);
    }

    function setUserActionAllowed(bool _userActionAllowed) public {
        require(isOwnerOrAdmin(msg.sender), "You are not Owner or Admin.");
        userActionAllowed = _userActionAllowed;
    }

    function setManagementActionAllowed(bool _managementActionAllowed) public {
        require(isOwnerOrAdmin(msg.sender), "You are not Owner or Admin.");
        managementActionAllowed = _managementActionAllowed;
    }

    // User

    function userStake() external payable nonReentrant {
        require(userActionAllowed, "User Action is not allowed.");
        require(msg.value > 0, "No ETH sent.");
        require(treasuryWallet != address(0), "Treasury wallet is not set.");
        require(unbondingPeriod >= MIN_UNBONDING_PERIOD && unbondingPeriod <= MAX_UNBONDING_PERIOD, "Unbonding period must be within the specified range.");

        uint256 stakingETHAmount = msg.value;

        uint256 VETHMintAmount;

        if (poolVETHAmount == 0) {
            // When LP Share Pool is empty, mint the same amount of VETH as ETH amount
            VETHMintAmount = stakingETHAmount;
        } else {
            require(poolETHAmount != 0, "Staked ETH amount is zero while staked VETH amount is not zero");
            // VETH : ETH = pool_VETH_amount : pool_ETH_amount
            VETHMintAmount = quoteVETH(stakingETHAmount);
        }

        // Update pools
        prestakedETHAmount = prestakedETHAmount.add(stakingETHAmount);
        poolVETHAmount = poolVETHAmount.add(stakingETHAmount);
        poolETHAmount = poolETHAmount.add(stakingETHAmount);

        VETHToken.mint(msg.sender, VETHMintAmount);

        emit UserStake(msg.sender, stakingETHAmount, VETHMintAmount, block.timestamp);
    }

    function userUnstake(uint256 VETHAmount) external nonReentrant {
        require(userActionAllowed, "User Action is not allowed.");
        require(VETHToken.balanceOf(msg.sender) >= VETHAmount, "No VETH sent.");

        updateOldPreunstakedETHAmount();

        uint256 unstakingETHAmount = quoteETH(VETHAmount);

        poolETHAmount = poolETHAmount.sub(unstakingETHAmount);
        poolVETHAmount = poolVETHAmount.sub(unstakingETHAmount);
        preunstakedETHAmount = preunstakedETHAmount.add(unstakingETHAmount);

        VETHToken.burn(msg.sender, VETHAmount);

        updateRecentPreunstakedETHAmountMap(unstakingETHAmount);

        unstakingUsers[msg.sender] = true;
        unstakingPacks[msg.sender].push(UnstakingPack({
            amount: unstakingETHAmount,
            timestamp: block.timestamp
        }));
        unstakingUsersList.push(msg.sender);

        emit UserUnstake(msg.sender, VETHAmount, unstakingETHAmount, block.timestamp);
    }

    function userWithdraw() external nonReentrant {
        require(userActionAllowed, "User Action is not allowed.");

        uint256 currentTimestamp = block.timestamp;
        uint256 unbondedAmount = 0;
        uint256 unbondedCount = 0;
        UnstakingPack[] storage packs = unstakingPacks[msg.sender];
        for (uint256 i = 0; i < packs.length; i++) {
            if (currentTimestamp >= packs[i].timestamp.add(unbondingPeriod)) {
                unbondedAmount = unbondedAmount.add(packs[i].amount);
                unbondedCount ++;
                if(unbondedCount > MAX_LOOP_IN_USER_WITHDRAW) {
                    break;
                }
            } else {
                break;
            }
        }

        require(unbondedAmount != 0, "No ETH to withdraw.");
        require(unbondedAmount <= unbondedETHAmount, "ETH is not unbonded from delegate providers yet.");
        require(unbondedAmount <= address(this).balance, "Not enough ETH in Smart Contract.");

        for(uint256 i = 0; i < packs.length.sub(unbondedCount); i ++) {
            packs[i] = packs[unbondedCount.add(i)];
        }
        for(uint256 i = 0; i < unbondedCount; i ++) {
            packs.pop();
        }

        if (packs.length == 0 && unstakingUsers[msg.sender]) {
            unstakingUsers[msg.sender] = false;
        }
        unbondedETHAmount = unbondedETHAmount.sub(unbondedAmount);

        bool success = payable(msg.sender).send(unbondedAmount);
        require(success, "Transfer failed");

        emit UserWithdraw(msg.sender, unbondedAmount, block.timestamp);
    }

    function donate() external payable nonReentrant {
        require(userActionAllowed, "User Action is not allowed.");
        require(msg.value > 0, "Donation amount must be greater than 0");

        uint256 stakingETHAmount = msg.value;
        prestakedETHAmount = prestakedETHAmount.add(stakingETHAmount);
        poolETHAmount = poolETHAmount.add(stakingETHAmount);

        emit Donate(msg.sender, stakingETHAmount, block.timestamp);
    }

    // Management

    function delegateToStakingProvider(address delegateAddress, uint256 amount) external payable nonReentrant {
        require(isOwnerOrAdmin(msg.sender), "You are not Owner or Admin.");
        require(managementActionAllowed, "Management Action is not allowed.");

        if(delegateAddress == address(0)) {
            require(autoDelegateAddress != address(0), "auto_delegate_address is empty");
            delegateAddress = autoDelegateAddress;
        }
        
        if(amount > 0) amount = min(amount, prestakedETHAmount);
        else amount = prestakedETHAmount;

        _delegate(delegateAddress, amount);
    }

    function _delegate(address delegateAddress, uint256 amount) internal {
        require(amount >= DELEGATE_MIN_AMOUNT, "delegating_amount cannot be less than 1 ETH.");
        require(amount <= address(this).balance, "Not enough ETH in Smart Contract.");
        require(whitelistedSpAddresses[delegateAddress], "Given Staking Provider is not whitelisted");

        prestakedETHAmount = prestakedETHAmount.sub(amount);

        bool success = StakingDelegate(payable(delegateAddress)).delegate{value: amount}();
        if(success) {
            emit DelegateToStakingProviderSuccess(msg.sender, delegateAddress, amount, block.timestamp);
        } else {
            prestakedETHAmount = prestakedETHAmount.add(amount);
            emit DelegateToStakingProviderFail(msg.sender, delegateAddress, amount, block.timestamp);
            revert("Transaction failed");
        }
    }

    function undelegateToStakingProvider(address undelegateAddress, uint256 amount) external {
        require(managementActionAllowed, "Management Action is not allowed.");
        updateOldPreunstakedETHAmount();
        require(isOwnerOrAdmin(msg.sender) || totalUndelegatedETHAmount < totalOldPreunstakedETHAmount, "Cannot undelegate");

        if(undelegateAddress == address(0)) {
            require(autoUndelegateAddress != address(0), "auto_undelegate_address is empty");
            undelegateAddress = autoUndelegateAddress;
        }
        
        if(amount > 0) amount = min(amount, preunstakedETHAmount);
        else amount = preunstakedETHAmount;

        _undelegate(undelegateAddress, amount);
    }

    function _undelegate(address undelegateAddress, uint256 amount) internal {
        require(isSmartContract(undelegateAddress), "Given address is not smart contract");
        require(amount >= DELEGATE_MIN_AMOUNT, "undelegating_amount cannot be less than 1 ETH.");

        prestakedETHAmount = preunstakedETHAmount.sub(amount);

        bool success = StakingDelegate(payable(undelegateAddress)).undelegate(amount);
        if(success) {
            totalUndelegatedETHAmount = totalUndelegatedETHAmount.add(amount);
            emit UndelegateFromStakingProviderSuccess(msg.sender, undelegateAddress, amount, block.timestamp);
        } else {
            prestakedETHAmount = preunstakedETHAmount.add(amount);
            emit UndelegateFromStakingProviderFail(msg.sender, undelegateAddress, amount, block.timestamp);
            revert("Transaction failed");
        }
    }

    function withdrawFromStakingProvider(address delegateAddress) external payable nonReentrant {
        require(managementActionAllowed, "Management Action is not allowed.");
        require(isSmartContract(delegateAddress), "Given address is not smart contract");

        bool success = StakingDelegate(payable(delegateAddress)).withdraw();
        if(success) {
            uint256 receivedEthAmount = msg.value;
            unbondedETHAmount = unbondedETHAmount.add(receivedEthAmount);
            emit WithdrawFromStakingProviderSuccess(msg.sender, delegateAddress, receivedEthAmount, block.timestamp);
        } else {
            emit WithdrawFromStakingProviderFail(msg.sender, delegateAddress, block.timestamp);
            revert("Transaction failed");
        }
    }

    function claimRewardsFromStakingProvider(address delegateAddress) external payable nonReentrant {
        require(isOwnerOrAdmin(msg.sender), "You are not Owner or Admin.");
        require(managementActionAllowed, "Management Action is not allowed.");
        require(isSmartContract(delegateAddress), "Given address is not smart contract");

        bool success = StakingDelegate(payable(delegateAddress)).claimRewards();
        if(success) {
            uint256 receivedEthAmount = msg.value;
            pendingRewardETHAmount = pendingRewardETHAmount.add(receivedEthAmount);
            emit ClaimRewardsFromStakingProviderSuccess(msg.sender, delegateAddress, receivedEthAmount, block.timestamp);
        } else {
            emit ClaimRewardsFromStakingProviderFail(msg.sender, delegateAddress, block.timestamp);
            revert("Transaction failed");
        }
    }

    function prestakePendingRewards() external payable nonReentrant {
        require(managementActionAllowed, "Management Action is not allowed.");
        uint256 pendingReward = pendingRewardETHAmount;
        pendingRewardETHAmount = 0;
        require(pendingReward > 0, ERROR_ZERO_AMOUNT);

        uint256 feeETH = pendingReward.mul(fee).div(MAX_PERCENTAGE);
        uint256 remainETH = pendingReward.sub(feeETH);

        if(feeETH != 0) {
            bool success = payable(treasuryWallet).send(feeETH);
            require(success, "Transaction failed");
        }

        prestakedETHAmount = prestakedETHAmount.add(remainETH);
        poolETHAmount = poolETHAmount.add(remainETH);
    }

    function withdrawFromPrestaked() external {
        require(managementActionAllowed, "Management Action is not allowed.");
        updateOldPreunstakedETHAmount();
        require(isOwnerOrAdmin(msg.sender) || totalUndelegatedETHAmount < totalOldPreunstakedETHAmount, "Cannot undelegate");

        uint256 availableETHAmount = min(prestakedETHAmount, preunstakedETHAmount);
        require(availableETHAmount > 0, "No ETH for withdraw");

        prestakedETHAmount = prestakedETHAmount.sub(availableETHAmount);
        preunstakedETHAmount = preunstakedETHAmount.sub(availableETHAmount);
        unbondedETHAmount = unbondedETHAmount.add(availableETHAmount);

        totalUndelegatedETHAmount = totalUndelegatedETHAmount.add(availableETHAmount);

        emit WithdrawFromPrestaked(msg.sender, availableETHAmount, block.timestamp);
    }

    function updateOldPreunstakedETHAmount() internal {
        uint256 currentBlock = block.number;
        uint256 removingBlock;
        for(uint256 i = 0; i < recentPreunstakedETHAmountsMapKeys.length; i ++) {
            if(recentPreunstakedETHAmountsMapKeys[i].add(EXPIRATION_BLOCKNUMBER_COUNT) < currentBlock) {
                totalOldPreunstakedETHAmount = totalOldPreunstakedETHAmount.add(recentPreunstakedETHAmountsMap[recentPreunstakedETHAmountsMapKeys[i]]);
                removingBlock = i;
                break;
            }
        }
        for(uint256 i = 0; i < recentPreunstakedETHAmountsMapKeys.length - removingBlock; i ++) {
            recentPreunstakedETHAmountsMapKeys[i] = recentPreunstakedETHAmountsMapKeys[i + removingBlock];
            delete recentPreunstakedETHAmountsMap[recentPreunstakedETHAmountsMapKeys[i]];
        }
        for(uint256 i = 0; i < removingBlock; i ++) recentPreunstakedETHAmountsMapKeys.pop();
    }

    function updateRecentPreunstakedETHAmountMap(uint256 amount) internal {
        uint256 currentBlock = block.number;
        if(recentPreunstakedETHAmountsMapKeys.length != 0) {
            if(recentPreunstakedETHAmountsMapKeys[recentPreunstakedETHAmountsMapKeys.length - 1] != currentBlock) {
                recentPreunstakedETHAmountsMapKeys.push(currentBlock);
                recentPreunstakedETHAmountsMap[currentBlock] = 0;
            }
        } else recentPreunstakedETHAmountsMapKeys.push(currentBlock);
        recentPreunstakedETHAmountsMap[currentBlock] = recentPreunstakedETHAmountsMap[currentBlock].add(amount);
    }

    // View

    function getVETHPrice() public view returns (uint256) {
        return quoteETH(ONE_VETH_IN_WEI);
    }

    function getETHPrice() public view returns (uint256) {
        return quoteETH(ONE_ETH_IN_WEI);
    }

    function viewLiquidStakingSettings() public view returns (LiquidStakingSettings memory) {
        return LiquidStakingSettings({
            VETH_identifier: address(VETHToken),
            treasuryWallet: treasuryWallet,
            fee: fee,
            unbondingPeriod: unbondingPeriod,
            admins: adminList,
            userActionAllowed: userActionAllowed,
            managementActionAllowed: managementActionAllowed,
            autoDelegateAddress: autoDelegateAddress,
            autoUndelegateAddress: autoUndelegateAddress,
            poolVETHAmount: poolVETHAmount,
            poolETHAmount: poolETHAmount,
            prestakedETHAmount: prestakedETHAmount,
            preunstakedETHAmount: preunstakedETHAmount,
            unbondedETHAmount: unbondedETHAmount,
            pendingRewardETHAmount: pendingRewardETHAmount,
            VETHPrice: poolVETHAmount > 0 ? getVETHPrice() : 0
        });
    }

    function viewUserUnstakingPacks() public view returns (UserUnstakingPacks[] memory) {
        UserUnstakingPacks[] memory userUnstakingPacks = new UserUnstakingPacks[](unstakingUsersList.length);
        for (uint256 i = 0; i < unstakingUsersList.length; i++) {
            address user = unstakingUsersList[i];
            UnstakingPack[] memory packs = unstakingPacks[user];
            userUnstakingPacks[i] = UserUnstakingPacks({
                userAddress: user,
                packs: packs
            });
        }
        return userUnstakingPacks;
    }

    function isSmartContract(address _address) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_address)
        }
        return size > 0;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
