// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Simple Ticket NFT
 * @dev Basic ERC-721 ticket with states
 */
contract Ticket is ERC721, Ownable, ReentrancyGuard {
    enum TicketState { Active, CheckedIn, Retired }

    struct TicketInfo {
        uint256 eventId;
        TicketState state;
        uint256 mintTime;
    }

    struct EventSale {
        uint256 stakeAmount;
        uint256 ticketSupply;
        uint256 ticketsMinted;
        bool isOpen;
        bool lotteryExecuted;
        uint256 winnersCount;
        address[] entrants;
        mapping(address => bool) hasEntered;
        mapping(address => bool) isWinner;
        mapping(address => bool) hasClaimed;
    }

    mapping(uint256 => TicketInfo) public tickets;
    mapping(uint256 => EventSale) private eventSales;
    mapping(uint256 => mapping(address => uint256)) public pendingRefunds;

    uint256 private _nextTokenId;

    event TicketMinted(uint256 indexed tokenId, address indexed to);
    event TicketCheckedIn(uint256 indexed tokenId);
    event SaleConfigured(uint256 indexed eventId, uint256 stakeAmount, uint256 ticketSupply);
    event SaleEntered(uint256 indexed eventId, address indexed participant, uint256 amount);
    event LotteryExecuted(uint256 indexed eventId, uint256 winnersCount, bytes32 randomness);
    event TicketClaimed(uint256 indexed eventId, uint256 indexed tokenId, address indexed winner);
    event StakeWithdrawn(uint256 indexed eventId, address indexed participant, uint256 amount);
    event TicketTransferred(uint256 indexed tokenId, address indexed from, address indexed to);

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    function mint(address to, uint256 eventId) external onlyOwner returns (uint256) {
        return _issueTicket(to, eventId);
    }

    function checkIn(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Ticket does not exist");
        require(tickets[tokenId].state == TicketState.Active, "Ticket not active");

        tickets[tokenId].state = TicketState.CheckedIn;
        emit TicketCheckedIn(tokenId);
    }

    function getTicket(uint256 tokenId) external view returns (TicketInfo memory) {
        require(_ownerOf(tokenId) != address(0), "Ticket does not exist");
        return tickets[tokenId];
    }

    function configureEventSale(uint256 eventId, uint256 stakeAmount, uint256 ticketSupply) external onlyOwner {
        require(stakeAmount > 0, "Stake must be positive");
        require(ticketSupply > 0, "Ticket supply must be positive");

        EventSale storage sale = eventSales[eventId];
        require(!sale.isOpen && sale.entrants.length == 0, "Sale active or populated");

        sale.stakeAmount = stakeAmount;
        sale.ticketSupply = ticketSupply;
        sale.ticketsMinted = 0;
        sale.isOpen = true;
        sale.lotteryExecuted = false;
        sale.winnersCount = 0;

        emit SaleConfigured(eventId, stakeAmount, ticketSupply);
    }

    function getSaleOverview(uint256 eventId)
        external
        view
        returns (
            uint256 stakeAmount,
            uint256 ticketSupply,
            uint256 ticketsMinted,
            bool isOpen,
            bool lotteryExecuted,
            uint256 entrantsCount,
            uint256 winnersCount
        )
    {
        EventSale storage sale = eventSales[eventId];
        return (
            sale.stakeAmount,
            sale.ticketSupply,
            sale.ticketsMinted,
            sale.isOpen,
            sale.lotteryExecuted,
            sale.entrants.length,
            sale.winnersCount
        );
    }

    function hasEnteredSale(uint256 eventId, address participant) external view returns (bool) {
        return eventSales[eventId].hasEntered[participant];
    }

    function isSaleWinner(uint256 eventId, address participant) external view returns (bool) {
        return eventSales[eventId].isWinner[participant];
    }

    function enterSale(uint256 eventId) external payable nonReentrant {
        EventSale storage sale = eventSales[eventId];
        require(sale.isOpen, "Sale not open");
        require(!sale.lotteryExecuted, "Lottery already run");
        require(msg.value == sale.stakeAmount, "Incorrect stake amount");
        require(!sale.hasEntered[msg.sender], "Already entered");

        sale.hasEntered[msg.sender] = true;
        sale.entrants.push(msg.sender);

        emit SaleEntered(eventId, msg.sender, msg.value);
    }

    function runLottery(uint256 eventId, uint256 winnersCount, bytes32 randomSeed) external onlyOwner {
        EventSale storage sale = eventSales[eventId];
        require(sale.isOpen, "Sale not open");
        require(!sale.lotteryExecuted, "Lottery already run");
        require(winnersCount > 0, "No winners requested");
        require(winnersCount <= sale.ticketSupply, "Winners exceed supply");
        require(winnersCount <= sale.entrants.length, "Not enough entrants");

        uint256 entrantsCount = sale.entrants.length;
        address[] memory pool = new address[](entrantsCount);
        for (uint256 i = 0; i < entrantsCount; i++) {
            pool[i] = sale.entrants[i];
        }

        uint256 remaining = entrantsCount;
        uint256 selected = 0;

        while (selected < winnersCount) {
            uint256 idx = uint256(keccak256(abi.encode(randomSeed, selected, remaining))) % remaining;
            address winner = pool[idx];

            sale.isWinner[winner] = true;
            pool[idx] = pool[remaining - 1];
            remaining--;
            selected++;
        }

        for (uint256 i = 0; i < entrantsCount; i++) {
            address participant = sale.entrants[i];
            if (!sale.isWinner[participant]) {
                pendingRefunds[eventId][participant] += sale.stakeAmount;
            }
        }

        sale.lotteryExecuted = true;
        sale.isOpen = false;
        sale.winnersCount = winnersCount;

        emit LotteryExecuted(eventId, winnersCount, randomSeed);
    }

    function claimTicket(uint256 eventId) external nonReentrant returns (uint256) {
        EventSale storage sale = eventSales[eventId];
        require(sale.lotteryExecuted, "Lottery not run");
        require(sale.isWinner[msg.sender], "Not a winner");
        require(!sale.hasClaimed[msg.sender], "Already claimed");
        require(sale.ticketsMinted < sale.ticketSupply, "All tickets claimed");

        sale.hasClaimed[msg.sender] = true;
        sale.ticketsMinted += 1;

        uint256 tokenId = _issueTicket(msg.sender, eventId);
        emit TicketClaimed(eventId, tokenId, msg.sender);
        return tokenId;
    }

    function withdrawStake(uint256 eventId) external nonReentrant {
        uint256 amount = pendingRefunds[eventId][msg.sender];
        require(amount > 0, "Nothing to withdraw");

        pendingRefunds[eventId][msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdraw failed");

        emit StakeWithdrawn(eventId, msg.sender, amount);
    }

    function transferTicket(uint256 tokenId, address to) external {
        require(_ownerOf(tokenId) == msg.sender, "Not ticket owner");
        require(to != address(0), "Invalid recipient");

        _safeTransfer(msg.sender, to, tokenId, "");
        emit TicketTransferred(tokenId, msg.sender, to);
    }

    function verifyTicket(uint256 tokenId, uint256 eventId, address holder) external view returns (bool) {
        if (_ownerOf(tokenId) != holder) {
            return false;
        }
        TicketInfo memory info = tickets[tokenId];
        return info.eventId == eventId && info.state == TicketState.Active;
    }

    function _issueTicket(address to, uint256 eventId) internal returns (uint256) {
        uint256 tokenId = _nextTokenId++;

        tickets[tokenId] = TicketInfo({
            eventId: eventId,
            state: TicketState.Active,
            mintTime: block.timestamp
        });

        _safeMint(to, tokenId);
        emit TicketMinted(tokenId, to);
        return tokenId;
    }
}
