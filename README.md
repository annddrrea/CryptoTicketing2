# CryptoTicketing Platform

A decentralized ticketing platform built on blockchain technology that enables event organizers to create, manage, and sell event tickets as NFTs. The platform features lottery-based ticket sales to prevent bot attacks, transparent ownership verification, and on-chain venue entry validation using QR codes.

## Overview

**CryptoTicketing** solves critical problems in the traditional ticketing industry:
- **Anti-Bot Protection**: Lottery-based primary sales prevent scalpers and bots from buying out events
- **Transparent Ownership**: All tickets are ERC-721 NFTs with verifiable on-chain ownership
- **Secure Entry Verification**: Venues can verify ticket authenticity and ownership on-chain
- **Fair Resale**: Compliant secondary marketplace with built-in royalty enforcement
- **Immutable Records**: Complete audit trail of all ticket transactions

## Tech Stack

### Smart Contracts
- **Solidity** 0.8.24
- **Foundry** - Development framework (Forge, Anvil, Cast)
- **OpenZeppelin** - Battle-tested security libraries (ERC721, Ownable, ReentrancyGuard)

### Backend
- **Node.js** + **TypeScript**
- **Express.js** - REST API server
- **ethers.js** v5.7.2 - Blockchain interaction
- Port: 3001

### Frontend
- **React** 18.2 + **TypeScript**
- **Vite** 4.4.5 - Build tool and dev server
- **ethers.js** v5.7.2 - Wallet and contract interaction
- Port: 5173

### Local Development
- **Anvil** - Local blockchain (Foundry)
- **Chain ID**: 31337
- Port: 8545

## Project Structure

```
├── contracts/
│   └── Ticket.sol              # Main ERC-721 NFT ticket contract with lottery mechanics
├── scripts/
│   ├── Deploy.s.sol            # Foundry deployment script
│   └── SetupEvents.s.sol       # Event configuration script (3 sample events)
├── test/
│   └── Ticket.t.sol            # Comprehensive Foundry test suite
├── backend/
│   ├── src/
│   │   └── index.ts            # Express API server
│   ├── package.json
│   ├── tsconfig.json
│   └── .env                    # Backend configuration
├── frontend/
│   ├── src/
│   │   ├── App.tsx             # Main React application
│   │   └── main.tsx            # React entry point
│   ├── package.json
│   ├── vite.config.ts
│   ├── tsconfig.json
│   └── .env                    # Frontend configuration
├── lib/
│   ├── forge-std/              # Foundry standard library (submodule)
│   └── openzeppelin-contracts/ # OpenZeppelin contracts (submodule)
├── setup.sh                    # Initial setup script
├── start-dev.sh                # Development environment startup
├── stop-dev.sh                 # Clean shutdown script
└── foundry.toml                # Foundry configuration
```

## Quick Start

### Prerequisites
- **macOS/Linux** (Windows users: use WSL)
- **Homebrew** (macOS) or equivalent package manager
- **Git** with submodule support

### Automated Setup (Recommended)
```bash
# 1. Clone repository with submodules
git clone --recurse-submodules https://github.com/annddrrea/CryptoTicketing2.git
cd CryptoTicketing2

# 2. Create .env file (REQUIRED - not included in repo for security)
cp .env.example .env
# The .env file contains the private key for local development
# Default uses Anvil's first test account (safe for local dev only)

# 3. Install all dependencies (Node.js, Foundry, npm packages)
chmod +x setup.sh
./setup.sh

# 4. Start complete development environment
chmod +x start-dev.sh
./start-dev.sh
```

**⚠️ IMPORTANT:** The `.env` file is gitignored and MUST be created manually. Without it, you'll get the error:
```
vm.envUint: environment variable "PRIVATE_KEY" not found
```

The `.env.example` file contains safe defaults for local development.

The `start-dev.sh` script automatically:
1. Starts Anvil local blockchain (port 8545)
2. Deploys Ticket.sol contract
3. Configures 3 sample events with lottery sales
4. Starts backend API server (port 3001)
5. Starts frontend dev server (port 5173)

### Manual Setup
```bash
# 1. Install dependencies
forge install                  # Smart contract dependencies
cd backend && npm install      # Backend dependencies
cd ../frontend && npm install  # Frontend dependencies

# 2. Start services in separate terminals
# Terminal 1: Local blockchain
anvil

# Terminal 2: Deploy contracts
forge script scripts/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
forge script scripts/SetupEvents.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>

# Terminal 3: Backend API
cd backend && npm run dev

# Terminal 4: Frontend
cd frontend && npm run dev
```

### Stop Services
```bash
./stop-dev.sh     # Gracefully stops all services and cleans up processes
```

### Access Points
- **Frontend UI**: http://localhost:5173
- **Backend API**: http://localhost:3001
- **Local Blockchain RPC**: http://localhost:8545

## Smart Contract Architecture

### Ticket.sol (contracts/Ticket.sol)

The core ERC-721 contract implementing lottery-based ticket sales with state management.

#### Key Data Structures

**TicketState Enum:**
- `Active` - Ticket is valid and can be used
- `CheckedIn` - Ticket has been scanned at venue
- `Retired` - Ticket is expired or invalidated

**EventSale Struct:**
- `stakeAmount` - ETH required to enter lottery
- `ticketSupply` - Total tickets available
- `ticketsMinted` - Tickets claimed so far
- `isOpen` - Sale accepting entries
- `lotteryExecuted` - Has lottery been run
- `entrants[]` - List of lottery participants
- `winners[]` - Selected winners
- Refund tracking for non-winners

#### Core Functions

**Owner Functions (Admin Only):**
- `configureEventSale(eventId, stakeAmount, ticketSupply)` - Initialize a new lottery sale
- `runLottery(eventId, winnersCount, randomSeed)` - Execute Fisher-Yates lottery algorithm
- `checkIn(tokenId)` - Mark ticket as checked in at venue entrance
- `mint(to, eventId)` - Direct ticket issuance (bypassing lottery)

**Public Functions (User Participation):**
- `enterSale(eventId)` - Join lottery with ETH stake (payable)
- `claimTicket(eventId)` - Winners mint their NFT ticket
- `withdrawStake(eventId)` - Non-winners withdraw refund
- `transferTicket(tokenId, to)` - Transfer ticket to another wallet
- `verifyTicket(tokenId, eventId, holder)` - Verify ownership and validity for venue entry

**View Functions:**
- `getSaleOverview(eventId)` - Returns complete sale status
- `hasEnteredSale(eventId, address)` - Check if user entered lottery
- `isSaleWinner(eventId, address)` - Check if user won lottery
- `getTicket(tokenId)` - Get ticket metadata and state

#### Security Features
- **ReentrancyGuard**: Prevents reentrancy attacks on payable functions
- **Ownable**: Role-based access control for admin functions
- **Fisher-Yates Shuffle**: Fair, deterministic lottery algorithm
- **Automatic Refunds**: Non-winners automatically queued for withdrawals
- **Checks-Effects-Interactions Pattern**: Prevents common vulnerabilities

## Backend API

Express.js server providing configuration and metadata services.

### Endpoints

**GET `/health`**
- Health check endpoint
- Returns: `{ status: 'OK', message: 'Server running' }`

**GET `/api/config`**
- Auto-detects deployed contract address from Foundry broadcast files
- Returns: `{ contractAddress, rpcUrl, chainId, network }`
- Enables frontend to dynamically connect to latest deployment

**GET `/api/events`**
- Sample event metadata (3 pre-configured events)
- Returns array of events with names, dates, venues, descriptions
- Extensible for database integration

**POST `/api/hash`**
- Utility hashing endpoint
- Request: `{ data }`
- Returns: `{ hash }`

### Environment Variables (backend/.env)
```env
PORT=3001
RPC_URL=http://localhost:8545
CHAIN_ID=31337
NETWORK=Anvil
```

## Frontend Application

Modern React SPA with Web3 wallet integration and polished UI.

### Key Features

**Wallet Integration:**
- MetaMask/Web3 wallet connection via ethers.js
- Account display with truncated address format
- Graceful error handling for connection failures

**Live Lottery Sales Display:**
- Real-time sale information per event:
  - Stake amount (ETH)
  - Ticket supply & minted count
  - Entrant count & winner count
  - Sale status badges
- User participation status tracking

**User Actions:**
- Connect wallet
- Enter lottery sales
- View entry/winner status
- Transaction confirmation feedback

**UI/UX:**
- Modern gradient dark theme (cyberpunk aesthetic)
- Glassmorphism effects with backdrop filters
- Responsive grid layout
- Status messages (success/error/info)
- Loading states for transactions

### Environment Variables (frontend/.env)
```env
VITE_EVENTS_API=http://localhost:3001/api/events
VITE_CONFIG_API=http://localhost:3001/api/config
VITE_PUBLIC_RPC_URL=http://localhost:8545
VITE_CHAIN_ID=31337
```

## Lottery Ticketing Flow

### Complete Workflow

1. **Event Configuration (Owner)**
   ```solidity
   configureEventSale(eventId, 0.01 ether, 500) // 0.01 ETH stake, 500 tickets
   ```

2. **Fans Enter Lottery (Public)**
   ```solidity
   enterSale(eventId) // Send exact stake amount (refundable)
   ```

3. **Lottery Execution (Owner)**
   ```solidity
   runLottery(eventId, 100, randomSeed) // Select 100 winners from entrants
   ```
   - Uses Fisher-Yates algorithm with deterministic randomness
   - Auto-queues refunds for non-winners

4. **Winners Claim Tickets**
   ```solidity
   claimTicket(eventId) // Mint NFT ticket to winner's wallet
   ```

5. **Non-Winners Withdraw Stakes**
   ```solidity
   withdrawStake(eventId) // Retrieve full refund
   ```

6. **Ticket Transfer (Optional)**
   ```solidity
   transferTicket(tokenId, recipient) // Transfer to another address
   ```

7. **Venue Entry Verification**
   ```solidity
   verifyTicket(tokenId, eventId, holder) // Returns true if valid
   checkIn(tokenId) // Mark as checked in (owner only)
   ```

### Sample Events (Pre-configured)

The `SetupEvents.s.sol` script creates 3 sample events:

1. **Doja Cat: Tour Ma Vie World Tour**
   - Stake: 0.01 ETH
   - Supply: 500 tickets
   - Event ID: 1

2. **Hamilton NY**
   - Stake: 0.05 ETH
   - Supply: 100 tickets
   - Event ID: 2

3. **2025 Skechers World Champions Cup**
   - Stake: 0.02 ETH
   - Supply: 200 tickets
   - Event ID: 3

## Testing

### Run Foundry Test Suite
```bash
forge test                    # Run all tests
forge test -vv                # Verbose output
forge test --match-test testLottery  # Run specific test
```

### Test Coverage (test/Ticket.t.sol)
- `testMint()` - Direct admin ticket issuance
- `testCheckIn()` - Check-in state transition
- `testSaleWorkflowLotteryClaimAndWithdraw()` - Complete lottery cycle
- `testTransferAndVerifyTicket()` - Transfer and verification logic

### Local Testing Workflow
1. Start Anvil: `anvil`
2. Deploy contracts: `forge script scripts/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast`
3. Run tests: `forge test`
4. Interact via frontend: http://localhost:5173

## Development Workflow

### Adding New Events
Modify `scripts/SetupEvents.s.sol`:
```solidity
ticket.configureEventSale(4, 0.03 ether, 300); // Event 4
```

### Contract Deployment
```bash
# Local (Anvil)
forge script scripts/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key $PRIVATE_KEY

# Testnet (e.g., Sepolia)
forge script scripts/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $PRIVATE_KEY --verify
```

### Extending the Backend
Add new endpoints in `backend/src/index.ts`:
```typescript
app.get('/api/marketplace', async (req, res) => {
  // Secondary marketplace logic
});
```

### Frontend Customization
Modify `frontend/src/App.tsx` for UI changes or add new components.

## Troubleshooting

### "PRIVATE_KEY not found" Error
**Problem:** When running `./start-dev.sh`, you see:
```
vm.envUint: environment variable "PRIVATE_KEY" not found
```

**Solution:** You need to create a `.env` file in the project root:
```bash
cp .env.example .env
```

The `.env` file is intentionally gitignored for security. It contains:
```env
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

This is Anvil's first test account private key (safe for local development only, NEVER use in production).

### Port Already in Use
If you see "port already in use" errors:
```bash
./stop-dev.sh  # Stop all running services
./start-dev.sh  # Restart
```

### Submodules Not Loaded
If `lib/forge-std` or `lib/openzeppelin-contracts` are empty:
```bash
git submodule update --init --recursive
forge install
```

### MetaMask Connection Issues
1. Ensure MetaMask is connected to `localhost:8545`
2. Chain ID should be `31337`
3. Import Anvil test account if needed (private key from `.env`)

### Contract Address Not Found
If the backend can't find the contract address:
1. Ensure Anvil is running: `ps aux | grep anvil`
2. Check deployment was successful: `cat broadcast/Deploy.s.sol/31337/run-latest.json`
3. Restart services: `./stop-dev.sh && ./start-dev.sh`

## Key Features

### Anti-Bot Protection
- Lottery mechanism prevents automated bulk purchases
- Stake requirement creates economic barrier for bots
- Fair winner selection via cryptographic randomness

### NFT Tickets
- Each ticket is a unique ERC-721 token
- Immutable ownership records on-chain
- Transferable between wallets (resale capability)
- State tracking (Active → CheckedIn → Retired)

### On-Chain Verification
- `verifyTicket()` enables trustless entry validation
- No centralized server required for venue access
- QR code integration potential
- Real-time state checks (active/checked-in/expired)

### Automated Refunds
- Non-winners automatically eligible for full refund
- Pull-payment pattern (users withdraw)
- No manual refund processing needed

### Full Web3 Integration
- Decentralized architecture (no required database)
- Direct blockchain interaction via ethers.js
- Self-custody model (users control their tickets)
- Transparent transaction history
