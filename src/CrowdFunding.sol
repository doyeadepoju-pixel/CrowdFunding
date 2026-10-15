// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrowdFunding {
    // ============================================================
    // 1. ENUM: the stages a campaign can be in
    // ============================================================
    enum Status { campaignActive, goalAchieved, goalFailed, campaignEnded }

    // ============================================================
    // 2. STRUCT: everything we store about one campaign
    // ============================================================
    struct Campaign {
        address creator;              // who started it
        uint256 goal;                 // target amount of tokens
        uint256 totalContribution;    // total contributed so far
        uint64  deadline;             // when contributions end (a timestamp)
        bool    campaignEnded;        // true once the creator has withdrawn the funds
        string  campaignDescription;  // what the campaign is for
    }

    // ============================================================
    // 3. STATE VARIABLES
    // ============================================================
    IERC20  public immutable token;                  // the token everyone contributes (mNGN now, Naira stablecoin later)
    uint256 public campaignCount;                    // how many campaigns exist
    uint256 public constant MAX_DURATION = 90 days;  // longest a campaign can run

    // ============================================================
    // 4. MAPPINGS
    // ============================================================
    mapping(uint256 => Campaign) public campaigns;                        // campaign ID => campaign details
    mapping(uint256 => mapping(address => uint256)) public pledgedAmount; // campaign ID => person => amount they contributed

    // ============================================================
    // 5. EVENTS
    // ============================================================
    event CampaignCreated(uint256 indexed id, address indexed creator, uint256 goal, uint64 deadline);
    event Pledged(uint256 indexed id, address indexed contributor, uint256 amount);
    event Withdrawn(uint256 indexed id, address indexed creator, uint256 amount);
    event Refunded(uint256 indexed id, address indexed contributor, uint256 amount);

    // ============================================================
    // 6. ERRORS
    // ============================================================
    error InvalidGoal();            // goal is zero
    error InvalidDuration();        // duration is zero or longer than MAX_DURATION
    error InvalidAmount();          // pledge amount is zero
    error CampaignNotFound();       // no campaign with that ID
    error CampaignNotActive();      // deadline has passed, no more pledges
    error CampaignStillActive();    // deadline hasn't passed yet
    error NotCreator();             // only the creator can withdraw
    error GoalNotAchieved();        // can't withdraw, goal wasn't met
    error GoalWasAchieved();        // can't refund, goal was met
    error CampaignAlreadyEnded();   // creator already withdrew
    error NothingToRefund();        // caller has no pledge to refund
    error TransferFailed();         // the token transfer returned false

    // ============================================================
    // 7. CONSTRUCTOR
    // ============================================================
    constructor(address _token) {
        token = IERC20(_token);
    }

    // ============================================================
    // 8. CREATE CAMPAIGN
    // ============================================================
    function createCampaign(
        uint256 _goal,
        uint256 _duration,
        string calldata _campaignDescription
    ) external returns (uint256 id) {
        if (_goal == 0) revert InvalidGoal();
        if (_duration == 0 || _duration > MAX_DURATION) revert InvalidDuration();

        id = ++campaignCount;
        // Safe: a timestamp + 90 days fits easily in uint64
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 deadline = uint64(block.timestamp + _duration);

        campaigns[id] = Campaign({
            creator: msg.sender,
            goal: _goal,
            totalContribution: 0,
            deadline: deadline,
            campaignEnded: false,
            campaignDescription: _campaignDescription
        });

        emit CampaignCreated(id, msg.sender, _goal, deadline);
    }

    // ============================================================
    // 9. PLEDGE: contribute tokens to an active campaign
    //    The contributor must first call token.approve(thisContract, amount)
    // ============================================================
    function pledge(uint256 _id, uint256 _amount) external {
        if (_amount == 0) revert InvalidAmount();
        if (getStatus(_id) != Status.campaignActive) revert CampaignNotActive();

        // Update records first
        campaigns[_id].totalContribution += _amount;
        pledgedAmount[_id][msg.sender] += _amount;

        // Then pull the tokens from the contributor into this contract
        bool ok = token.transferFrom(msg.sender, address(this), _amount);
        if (!ok) revert TransferFailed();

        emit Pledged(_id, msg.sender, _amount);
    }

    // ============================================================
    // 10. WITHDRAW: creator takes the funds if the goal was met
    // ============================================================
    function withdraw(uint256 _id) external {
        Status status = getStatus(_id);
        Campaign storage c = campaigns[_id];

        if (msg.sender != c.creator) revert NotCreator();
        if (status == Status.campaignActive) revert CampaignStillActive();
        if (status == Status.campaignEnded) revert CampaignAlreadyEnded();
        if (status == Status.goalFailed) revert GoalNotAchieved();

        // Mark as ended BEFORE sending, so it can never be withdrawn twice
        c.campaignEnded = true;

        uint256 amount = c.totalContribution;
        bool ok = token.transfer(c.creator, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawn(_id, c.creator, amount);
    }

    // ============================================================
    // 11. REFUND: contributors get their tokens back if the goal was NOT met
    // ============================================================
    function refund(uint256 _id) external {
        Status status = getStatus(_id);

        if (status == Status.campaignActive) revert CampaignStillActive();
        if (status != Status.goalFailed) revert GoalWasAchieved();

        uint256 amount = pledgedAmount[_id][msg.sender];
        if (amount == 0) revert NothingToRefund();

        // Zero the pledge BEFORE sending, so it can never be refunded twice
        pledgedAmount[_id][msg.sender] = 0;

        bool ok = token.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Refunded(_id, msg.sender, amount);
    }

    // ============================================================
    // 12. GET STATUS: works out the campaign's stage from its data
    // ============================================================
    function getStatus(uint256 _id) public view returns (Status) {
        Campaign storage c = campaigns[_id];
        if (c.creator == address(0)) revert CampaignNotFound();

        if (c.campaignEnded) return Status.campaignEnded;
        if (block.timestamp < c.deadline) return Status.campaignActive;
        if (c.totalContribution >= c.goal) return Status.goalAchieved;
        return Status.goalFailed;
    }
}
