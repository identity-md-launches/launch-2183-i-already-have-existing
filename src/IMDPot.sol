// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {WeightedTree} from "./libraries/WeightedTree.sol";

interface IGameToken {
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Fresh, non-upgradeable IMD lottery. Block producers can influence the requested blockhash randomness.
/// @dev Privy and other contract/embedded wallets use the same ERC20 approval and entry calls as every player.
contract IMDPot {
    using WeightedTree for WeightedTree.Tree;

    uint256 public constant ROUND_DURATION = 15 minutes;
    uint256 public constant DRAW_DELAY_BLOCKS = 3;
    uint256 public constant BLOCKHASH_WINDOW = 256;
    uint256 public constant CANCEL_DELAY = 1 days;
    uint256 public constant BPS = 10_000;
    uint256 public constant FIRST_PRIZE_BPS = 4000;
    uint256 public constant SECOND_PRIZE_BPS = 2000;
    uint256 public constant THIRD_PRIZE_BPS = 1000;
    uint256 public constant BURN_BPS = 1000;
    uint256 public constant TREASURY_BPS = 500;
    uint256 public constant LOCK_BPS = 1500;
    uint256 public constant WINNER_SLOTS = 3;
    uint256 public constant MAX_TICKETS_PER_PURCHASE = 1_000_000;
    uint256 public constant MULTIPLIER_COST_POINTS = 100;
    uint256 public constant MULTIPLIER_STEP_BPS = 2500;
    uint256 public constant MAX_MULTIPLIER_BONUS_BPS = 10_000;
    uint256 public constant ROUNDS_FOR_MULTIPLIER = 10;
    // This is the intended, irreversible burn destination, never an unset-value placeholder.
    address public constant DEAD_ADDRESS = address(0xdead);

    enum RoundStatus {
        Pending,
        Active,
        Drawing,
        Finalized,
        Cancelled
    }

    // Field order is the existing website's future-blockhash ABI.
    struct Round {
        RoundStatus status;
        uint64 startTime;
        uint64 endTime;
        uint256 pool;
        uint256 totalTickets;
        uint256 participantCount;
        uint256 drawBlock;
        bytes32 drawBlockHash;
        uint256 randomWord;
        address[3] winners;
        uint256[3] prizes;
        uint256 burned;
        uint256 treasuryFee;
        uint256 locked;
    }

    struct Player {
        uint256 points;
        uint256 roundsPlayed;
        uint256 pendingBoostBps;
        uint256 unsettledRound;
    }

    address public owner;
    address public pendingOwner;
    // Fixed fee beneficiary: launch owner, unaffected by later ownership transfers.
    address public TREASURY;
    address public token;
    uint256 public ticketPrice;
    bool public paused;
    uint256 public currentRoundId = 1;
    uint256 public totalLocked;
    uint256 public totalClaimable;
    uint256 public totalRefundable;
    uint256 public pendingBurn;
    uint256 public pendingTreasury;

    mapping(uint256 => Round) private rounds;
    mapping(uint256 => address[]) private participants;
    mapping(uint256 => mapping(address => uint256)) public participantIndex;
    mapping(uint256 => mapping(address => uint256)) public ticketsOf;
    mapping(uint256 => mapping(address => uint256)) public roundBoostBps;
    mapping(uint256 => WeightedTree.Tree) private trees;
    mapping(address => Player) private players;
    mapping(address => uint256) public claimable;
    uint256 private entered = 1;

    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error OwnershipCannotBeRenounced();
    error ZeroAddress();
    error EnforcedPause();
    error ExpectedPause();
    error TokenNotConfigured();
    error TokenAlreadySet();
    error NotAContract(address account);
    error InvalidTokenDecimals();
    error InvalidTicketCount();
    error RoundClosed();
    error UnexpectedRound(uint256 expected, uint256 actual);
    error RoundDrawing();
    error RoundNotActive();
    error RoundNotEnded();
    error DrawNotReady(uint256 drawBlock);
    error DrawExpired(uint256 drawBlock);
    error DrawHashUnavailable(uint256 drawBlock);
    error CancelTooEarly();
    error RoundNotCancelled();
    error NothingToRefund();
    error NothingToClaim();
    error NothingToFlush();
    error CannotRescueGameToken();
    error ReentrancyGuardReentrantCall();
    error SafeERC20FailedOperation(address token);
    error TransferAmountMismatch();
    error InsufficientPoints(uint256 have, uint256 need);
    error InsufficientRoundsPlayed(uint256 have, uint256 need);
    error MultiplierAtMax();

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event TokenSet(address indexed token, uint256 ticketPrice);
    event RoundStarted(uint256 indexed roundId, uint64 startTime, uint64 endTime);
    event TicketsPurchased(
        uint256 indexed roundId, address indexed player, uint256 tickets, uint256 amount, uint256 boostBps
    );
    event DrawCommitted(uint256 indexed roundId, uint256 indexed drawBlock, address indexed caller);
    event RoundFinalized(
        uint256 indexed roundId,
        uint256 randomWord,
        address[3] winners,
        uint256[3] prizes,
        uint256 burned,
        uint256 treasuryFee,
        uint256 locked
    );
    event RoundCancelled(uint256 indexed roundId, uint256 pool, address indexed caller);
    event PrizeClaimed(address indexed player, uint256 amount);
    event Refunded(uint256 indexed roundId, address indexed player, uint256 amount);
    event FeeTransferred(address indexed to, uint256 amount);
    event FeeTransferDeferred(address indexed to, uint256 amount);
    event ForeignTokenRescued(address indexed foreignToken, address indexed to, uint256 amount);
    event PointsCredited(address indexed player, uint256 indexed roundId, uint256 points, uint256 roundsPlayed);
    event MultiplierRedeemed(address indexed player, uint256 pointsSpent, uint256 pendingBoostBps);
    event MultiplierRestored(address indexed player, uint256 indexed roundId, uint256 pendingBoostBps);

    constructor(address owner_) {
        if (owner_ == address(0)) revert OwnableInvalidOwner(owner_);
        owner = owner_;
        TREASURY = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    modifier nonReentrant() {
        if (entered != 1) revert ReentrancyGuardReentrantCall();
        entered = 2;
        _;
        entered = 1;
    }

    function transferOwnership(address newOwner) external onlyOwner nonReentrant {
        if (newOwner == address(0) || newOwner == address(this)) revert OwnableInvalidOwner(newOwner);
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external nonReentrant {
        if (msg.sender != pendingOwner) revert OwnableUnauthorizedAccount(msg.sender);
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    function renounceOwnership() external view onlyOwner {
        revert OwnershipCannotBeRenounced();
    }

    function pause() external onlyOwner nonReentrant {
        if (paused) revert EnforcedPause();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner nonReentrant {
        if (!paused) revert ExpectedPause();
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Set the IMD token once, after reviewing its chain, identity and exact-transfer behavior.
    function setToken(address token_) external onlyOwner nonReentrant {
        if (token != address(0)) revert TokenAlreadySet();
        if (token_ == address(0)) revert ZeroAddress();
        if (token_.code.length == 0) revert NotAContract(token_);
        uint8 decimals = IGameToken(token_).decimals();
        if (decimals == 0 || decimals > 18) revert InvalidTokenDecimals();
        token = token_;
        ticketPrice = 10 ** (decimals - 1); // Website's stated price: 0.1 IMD.
        emit TokenSet(token_, ticketPrice);
    }

    function isConfigured() public view returns (bool) {
        return token != address(0);
    }

    function buyTickets(uint256 count) external nonReentrant {
        _buyTickets(count);
    }

    /// @notice Website entry point: a purchase reviewed for an old round must never enter a new one.
    function buyTicketsForRound(uint256 expectedRoundId, uint256 count) external nonReentrant {
        if (expectedRoundId != currentRoundId) revert UnexpectedRound(expectedRoundId, currentRoundId);
        _buyTickets(count);
    }

    function _buyTickets(uint256 count) private {
        _configured();
        if (paused) revert EnforcedPause();
        if (count == 0 || count > MAX_TICKETS_PER_PURCHASE) revert InvalidTicketCount();
        uint256 id = currentRoundId;
        Round storage round = rounds[id];
        if (round.status == RoundStatus.Drawing) revert RoundDrawing();
        if (round.status == RoundStatus.Active && block.timestamp >= round.endTime) revert RoundClosed();
        if (round.status == RoundStatus.Pending) {
            round.status = RoundStatus.Active;
            round.startTime = uint64(block.timestamp);
            round.endTime = uint64(block.timestamp + ROUND_DURATION);
            emit RoundStarted(id, round.startTime, round.endTime);
        }
        _syncPoints(msg.sender);
        uint256 index = participantIndex[id][msg.sender];
        if (index == 0) {
            participants[id].push(msg.sender);
            index = participants[id].length;
            participantIndex[id][msg.sender] = index;
            round.participantCount++;
            Player storage player = players[msg.sender];
            roundBoostBps[id][msg.sender] = player.pendingBoostBps;
            player.pendingBoostBps = 0;
            player.unsettledRound = id;
            trees[id].append(count * (BPS + roundBoostBps[id][msg.sender]));
        } else {
            trees[id].add(index, count * (BPS + roundBoostBps[id][msg.sender]));
        }
        uint256 amount = count * ticketPrice;
        round.pool += amount;
        round.totalTickets += count;
        ticketsOf[id][msg.sender] += count;
        uint256 beforeBalance = IGameToken(token).balanceOf(address(this));
        _callToken(token, abi.encodeCall(IGameToken.transferFrom, (msg.sender, address(this), amount)));
        if (IGameToken(token).balanceOf(address(this)) != beforeBalance + amount) revert TransferAmountMismatch();
        emit TicketsPurchased(id, msg.sender, count, amount, roundBoostBps[id][msg.sender]);
    }

    /// @notice Call after closing to commit a future block; call again after that block to settle.
    function finalizeRound() external nonReentrant {
        _configured();
        uint256 id = currentRoundId;
        Round storage round = rounds[id];
        if (round.status == RoundStatus.Active) {
            if (paused) revert EnforcedPause();
            if (block.timestamp < round.endTime) revert RoundNotEnded();
            round.status = RoundStatus.Drawing;
            round.drawBlock = block.number + DRAW_DELAY_BLOCKS;
            emit DrawCommitted(id, round.drawBlock, msg.sender);
            return;
        }
        if (round.status != RoundStatus.Drawing) revert RoundNotActive();
        if (block.number <= round.drawBlock) revert DrawNotReady(round.drawBlock);
        if (block.number > round.drawBlock + BLOCKHASH_WINDOW) revert DrawExpired(round.drawBlock);
        bytes32 drawHash = blockhash(round.drawBlock);
        if (drawHash == bytes32(0)) revert DrawHashUnavailable(round.drawBlock);
        round.drawBlockHash = drawHash;
        round.randomWord = uint256(keccak256(abi.encode(drawHash, block.chainid, address(this), id)));
        _settle(id, round);
    }

    function _settle(uint256 id, Round storage round) private {
        uint256 slots = round.totalTickets < WINNER_SLOTS ? round.totalTickets : WINNER_SLOTS;
        uint256[3] memory indexes;
        uint256[3] memory weights;
        for (uint256 i; i < slots; ++i) {
            uint256 position = uint256(keccak256(abi.encode(round.randomWord, i))) % trees[id].total;
            uint256 index = trees[id].find(position);
            address winner = participants[id][index - 1];
            uint256 unit = BPS + roundBoostBps[id][winner];
            indexes[i] = index;
            weights[i] = unit;
            trees[id].remove(index, unit); // One winning ticket removed, not its player's other tickets.
            round.winners[i] = winner;
        }
        // Keep historical weight views stable after settlement.
        for (uint256 i; i < slots; ++i) {
            trees[id].add(indexes[i], weights[i]);
        }

        // Bound each division's error to <1 token base unit; all dust goes to the first prize.
        round.burned = round.pool * BURN_BPS / BPS;
        round.treasuryFee = round.pool * TREASURY_BPS / BPS;
        round.locked = round.pool * LOCK_BPS / BPS;
        uint256 prizePool = round.pool - round.burned - round.treasuryFee - round.locked;
        if (slots > 1) round.prizes[1] = round.pool * SECOND_PRIZE_BPS / BPS;
        if (slots > 2) round.prizes[2] = round.pool * THIRD_PRIZE_BPS / BPS;
        round.prizes[0] = prizePool - round.prizes[1] - round.prizes[2];
        for (uint256 i; i < slots; ++i) {
            claimable[round.winners[i]] += round.prizes[i];
        }
        totalClaimable += prizePool;
        totalLocked += round.locked;
        pendingBurn += round.burned;
        pendingTreasury += round.treasuryFee;
        round.status = RoundStatus.Finalized;
        currentRoundId = id + 1;
        emit RoundFinalized(
            id, round.randomWord, round.winners, round.prizes, round.burned, round.treasuryFee, round.locked
        );
        _flushFees();
    }

    /// @notice Expired blockhash draws refund in full. Paused, uncommitted rounds refund after 24 hours.
    function cancelRound() external nonReentrant {
        Round storage round = rounds[currentRoundId];
        if (round.status == RoundStatus.Drawing) {
            if (block.number <= round.drawBlock + BLOCKHASH_WINDOW) revert CancelTooEarly();
        } else if (round.status == RoundStatus.Active) {
            if (!paused || block.timestamp < uint256(round.endTime) + CANCEL_DELAY) revert CancelTooEarly();
        } else {
            revert RoundNotActive();
        }
        round.status = RoundStatus.Cancelled;
        totalRefundable += round.pool;
        emit RoundCancelled(currentRoundId, round.pool, msg.sender);
        currentRoundId++;
    }

    function refund(uint256 id) external nonReentrant {
        if (rounds[id].status != RoundStatus.Cancelled) revert RoundNotCancelled();
        uint256 count = ticketsOf[id][msg.sender];
        if (count == 0) revert NothingToRefund();
        _syncPoints(msg.sender);
        ticketsOf[id][msg.sender] = 0;
        uint256 amount = count * ticketPrice;
        totalRefundable -= amount;
        _transferExact(token, msg.sender, amount);
        emit Refunded(id, msg.sender, amount);
    }

    function claim() external nonReentrant {
        uint256 amount = claimable[msg.sender];
        if (amount == 0) revert NothingToClaim();
        claimable[msg.sender] = 0;
        totalClaimable -= amount;
        _transferExact(token, msg.sender, amount);
        emit PrizeClaimed(msg.sender, amount);
    }

    function flushPendingFees() external nonReentrant {
        _configured();
        if (pendingBurn + pendingTreasury == 0) revert NothingToFlush();
        _flushFees();
    }

    function _flushFees() private {
        uint256 amount = pendingBurn;
        if (amount != 0) {
            pendingBurn = 0;
            try this.transferFee{gas: 150_000}(DEAD_ADDRESS, amount) {
                emit FeeTransferred(DEAD_ADDRESS, amount);
            } catch {
                pendingBurn = amount;
                emit FeeTransferDeferred(DEAD_ADDRESS, amount);
            }
        }
        amount = pendingTreasury;
        if (amount != 0) {
            pendingTreasury = 0;
            try this.transferFee{gas: 150_000}(TREASURY, amount) {
                emit FeeTransferred(TREASURY, amount);
            } catch {
                pendingTreasury = amount;
                emit FeeTransferDeferred(TREASURY, amount);
            }
        }
    }

    /// @dev Self-call isolation makes a false-return/taxed transfer roll back before it is deferred.
    function transferFee(address to, uint256 amount) external {
        if (msg.sender != address(this)) revert OwnableUnauthorizedAccount(msg.sender);
        _transferExact(token, to, amount);
    }

    function rescueForeignToken(address foreignToken, address to) external onlyOwner nonReentrant {
        if (foreignToken == token) revert CannotRescueGameToken();
        if (to == address(0) || to == address(this)) revert ZeroAddress();
        if (foreignToken.code.length == 0) revert NotAContract(foreignToken);
        uint256 amount = IGameToken(foreignToken).balanceOf(address(this));
        _transferExact(foreignToken, to, amount);
        emit ForeignTokenRescued(foreignToken, to, amount);
    }

    function syncPoints(address account) external nonReentrant {
        _syncPoints(account);
    }

    function _syncPoints(address account) private {
        Player storage player = players[account];
        uint256 id = player.unsettledRound;
        if (id == 0) return;
        if (rounds[id].status == RoundStatus.Finalized) {
            player.unsettledRound = 0;
            uint256 earned = ticketsOf[id][account];
            player.points += earned;
            player.roundsPlayed++;
            emit PointsCredited(account, id, earned, player.roundsPlayed);
        } else if (rounds[id].status == RoundStatus.Cancelled) {
            player.unsettledRound = 0;
            player.pendingBoostBps += roundBoostBps[id][account];
            emit MultiplierRestored(account, id, player.pendingBoostBps);
        }
    }

    function redeemMultiplier() external nonReentrant {
        _syncPoints(msg.sender);
        Player storage player = players[msg.sender];
        if (player.roundsPlayed < ROUNDS_FOR_MULTIPLIER) {
            revert InsufficientRoundsPlayed(player.roundsPlayed, ROUNDS_FOR_MULTIPLIER);
        }
        if (player.points < MULTIPLIER_COST_POINTS) revert InsufficientPoints(player.points, MULTIPLIER_COST_POINTS);
        // Reserve space to restore a live round's boost on cancellation, without losing paid points.
        if (player.pendingBoostBps + _restorableBoost(msg.sender) >= MAX_MULTIPLIER_BONUS_BPS) {
            revert MultiplierAtMax();
        }
        player.points -= MULTIPLIER_COST_POINTS;
        player.pendingBoostBps += MULTIPLIER_STEP_BPS;
        emit MultiplierRedeemed(msg.sender, MULTIPLIER_COST_POINTS, player.pendingBoostBps);
    }

    function _restorableBoost(address account) private view returns (uint256) {
        uint256 id = players[account].unsettledRound;
        RoundStatus status = rounds[id].status;
        return
            id != 0 && (status == RoundStatus.Active || status == RoundStatus.Drawing) ? roundBoostBps[id][account] : 0;
    }

    function getPlayer(address account)
        external
        view
        returns (uint256 points, uint256 roundsPlayed, uint256 pendingBoostBps, bool canRedeem)
    {
        Player memory player = players[account];
        uint256 id = player.unsettledRound;
        if (id != 0 && rounds[id].status == RoundStatus.Finalized) {
            player.points += ticketsOf[id][account];
            player.roundsPlayed++;
        } else if (id != 0 && rounds[id].status == RoundStatus.Cancelled) {
            player.pendingBoostBps += roundBoostBps[id][account];
        }
        points = player.points;
        roundsPlayed = player.roundsPlayed;
        pendingBoostBps = player.pendingBoostBps;
        canRedeem = roundsPlayed >= ROUNDS_FOR_MULTIPLIER && points >= MULTIPLIER_COST_POINTS
            && pendingBoostBps + _restorableBoost(account) < MAX_MULTIPLIER_BONUS_BPS;
    }

    function getRound(uint256 id) external view returns (Round memory) {
        return rounds[id];
    }

    function getParticipants(uint256 id) external view returns (address[] memory) {
        return participants[id];
    }

    function totalWeight(uint256 id) external view returns (uint256) {
        return trees[id].total;
    }

    function weightOf(uint256 id, address account) external view returns (uint256) {
        return ticketsOf[id][account] * (BPS + roundBoostBps[id][account]);
    }

    function timeRemaining() external view returns (uint256) {
        Round storage round = rounds[currentRoundId];
        if (round.status == RoundStatus.Pending) return ROUND_DURATION;
        if (round.status != RoundStatus.Active || block.timestamp >= round.endTime) return 0;
        return round.endTime - block.timestamp;
    }

    function totalObligations() external view returns (uint256) {
        return
            rounds[currentRoundId].pool + totalClaimable + totalRefundable + totalLocked + pendingBurn + pendingTreasury;
    }

    function _configured() private view {
        if (!isConfigured()) revert TokenNotConfigured();
    }

    function _callToken(address asset, bytes memory data) private {
        if (asset.code.length == 0) revert NotAContract(asset);
        (bool ok, bytes memory result) = asset.call(data);
        if (!ok || (result.length != 0 && (result.length != 32 || abi.decode(result, (uint256)) != 1))) {
            revert SafeERC20FailedOperation(asset);
        }
    }

    function _transferExact(address asset, address to, uint256 amount) private {
        uint256 beforeSelf = IGameToken(asset).balanceOf(address(this));
        uint256 beforeTo = IGameToken(asset).balanceOf(to);
        _callToken(asset, abi.encodeCall(IGameToken.transfer, (to, amount)));
        if (
            IGameToken(asset).balanceOf(address(this)) + amount != beforeSelf
                || IGameToken(asset).balanceOf(to) != beforeTo + amount
        ) revert TransferAmountMismatch();
    }
}
