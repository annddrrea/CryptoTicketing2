#!/bin/bash

echo "🚀 Starting CryptoTicketing Development Environment"
echo "=================================================="

# Check if all dependencies are installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please run ./setup.sh first"
    exit 1
fi

if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Please run ./setup.sh first"
    exit 1
fi

echo "✅ All dependencies found!"
echo ""

echo "🔧 Starting services..."
echo ""

echo "1. Starting local blockchain (Anvil)..."
anvil > anvil.log 2>&1 &
ANVIL_PID=$!
echo "   Anvil started (PID: $ANVIL_PID)"
sleep 3

echo "2. Starting backend server..."
cd backend
npm run dev > ../backend.log 2>&1 &
BACKEND_PID=$!
echo "   Backend started (PID: $BACKEND_PID)"
cd ..
sleep 2

echo "3. Starting frontend development server..."
cd frontend
npm run dev > ../frontend.log 2>&1 &
FRONTEND_PID=$!
echo "   Frontend started (PID: $FRONTEND_PID)"
cd ..
sleep 3

echo "4. Deploying smart contracts..."
sleep 3  # Wait for anvil to start
forge script scripts/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

echo "5. Configuring event sales..."
sleep 2  # Wait for deployment to complete

# Extract the contract address from the latest broadcast file
if [ -f "broadcast/Deploy.s.sol/31337/run-latest.json" ]; then
    CONTRACT_ADDRESS=$(node -e "
        const fs = require('fs');
        const data = JSON.parse(fs.readFileSync('broadcast/Deploy.s.sol/31337/run-latest.json', 'utf8'));
        const tx = data.transactions.find(t => t.contractName === 'Ticket' && t.transactionType === 'CREATE');
        console.log(tx ? tx.contractAddress : '');
    ")
    
    if [ -n "$CONTRACT_ADDRESS" ]; then
        echo "   Using detected contract address: $CONTRACT_ADDRESS"
        TICKET_CONTRACT_ADDRESS=$CONTRACT_ADDRESS forge script scripts/SetupEvents.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    else
        echo "   ⚠️  Could not detect contract address, skipping event setup"
    fi
else
    echo "   ⚠️  Broadcast file not found, skipping event setup"
fi

# Store PIDs for cleanup
echo $ANVIL_PID > .anvil.pid
echo $BACKEND_PID > .backend.pid
echo $FRONTEND_PID > .frontend.pid

echo ""
echo "🎉 Development environment started!"
echo ""
echo "📱 Frontend: http://localhost:5173"
echo "🔧 Backend:  http://localhost:3001"
echo "⛓️  Blockchain: http://localhost:8545"
echo ""
echo "View logs:"
echo "  Anvil: tail -f anvil.log"
echo "  Backend: tail -f backend.log"
echo "  Frontend: tail -f frontend.log"
echo ""
echo "To stop all services, run: ./stop-dev.sh"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping services..."
    kill $ANVIL_PID $BACKEND_PID $FRONTEND_PID 2>/dev/null
    rm -f .anvil.pid .backend.pid .frontend.pid
    exit 0
}

trap cleanup SIGINT SIGTERM

echo "Press Ctrl+C to stop all services"

# Keep script running
while true; do
    sleep 1
done