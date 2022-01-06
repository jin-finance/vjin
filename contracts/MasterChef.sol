// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./VJinToken.sol";


// MasterChef is the master of vJin. He can make vJin and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once JIN is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of VJINs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accVJinPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accVJinPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. VJINs to distribute per block.
        uint256 lastRewardBlock; // Last block number that VJINs distribution occurs.
        uint256 accVJinPerShare; // Accumulated VJINs per share, times 1e12. See below.
    }
    // The VJIN TOKEN!
    VJinToken public vjin;
    // Dev address.
    address public devaddr;
    // Block number when bonus VJIN period ends.
    uint256 public bonusEndBlock;
    // VJIN tokens created per block.
    uint256 public vjinPerBlock;
    // Bonus muliplier for early stakers.
    uint256 public BONUS_MULTIPLIER = 3;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when VJIN mining starts.
    uint256 public startBlock;
    // Value to prompt ending of the pool farm
    bool public isFinish;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        VJinToken _vjin,
        address _devaddr,
        uint256 _vjinPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        vjin = _vjin;
        devaddr = _devaddr;
        vjinPerBlock = _vjinPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        require(multiplierNumber <= 3, "Max of 3x multiplier");
        require(multiplierNumber >= 1, "Cannot be lower than 1");
        require(multiplierNumber <= BONUS_MULTIPLIER, "Can only decrease");

        BONUS_MULTIPLIER = multiplierNumber;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accVJinPerShare: 0
            })
        );
    }

    // Update the given pool's VJIN allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        if (poolInfo[_pid].allocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
                _allocPoint
            );
            poolInfo[_pid].allocPoint = _allocPoint;
        }
    }


    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending VJINs on frontend.
    function pendingVJin(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accVJinPerShare = pool.accVJinPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 vjinReward = multiplier.mul(vjinPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accVJinPerShare = accVJinPerShare.add(vjinReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accVJinPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 vjinReward = multiplier.mul(vjinPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        vjin.mint(devaddr, vjinReward.div(10));
        vjin.mint(address(this), vjinReward);
        pool.accVJinPerShare = pool.accVJinPerShare.add(vjinReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
        updateBlockReward();
    }

    // Deposit LP tokens to MasterChef for VJIN allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVJinPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeVJinTransfer(msg.sender, pending);
            }
        }
        
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);

        user.rewardDebt = user.amount.mul(pool.accVJinPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accVJinPerShare).div(1e12).sub(user.rewardDebt);
        
        safeVJinTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accVJinPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    //Update scaling of per block reward
    function updateBlockReward() internal {
        uint256 lpSupply = poolInfo[0].lpToken.balanceOf(address(this));
        if (isFinish) {
            vjinPerBlock = 0;
        } else if (lpSupply <= 1e24) {
            vjinPerBlock = 237823440000000000;
        } else if (lpSupply >= 5e24) {
            vjinPerBlock = 356735160000000000;
        } else if (lpSupply > 1e24 && lpSupply < 5e24) {
            uint256 max = 5e24;
            vjinPerBlock = max.sub(lpSupply).mul(35).div(max).add(15).mul(3).mul(lpSupply).div(630720000);
        }
    }

    //Finalizes the stopping of the pool rewards
    function finished() public onlyOwner {
        isFinish = true;
    }

    // Safe vjin transfer function, just in case if rounding error causes pool to not have enough VJINs.
    function safeVJinTransfer(address _to, uint256 _amount) internal {
        uint256 vjinBal = vjin.balanceOf(address(this));
        if (_amount > vjinBal) {
            vjin.transfer(_to, vjinBal);
        } else {
            vjin.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}