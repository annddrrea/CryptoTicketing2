#!/bin/bash

echo "🛑 Stopping CryptoTicketing Development Environment"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to kill processes by port
kill_port() {
    local port=$1
    local service_name=$2
    
    local pid=$(lsof -ti:$port)
    if [ ! -z "$pid" ]; then
        echo "Stopping $service_name (port $port, PID: $pid)..."
        kill -TERM $pid 2>/dev/null
        sleep 2
        
        # Force kill if still running
        if kill -0 $pid 2>/dev/null; then
            kill -KILL $pid 2>/dev/null
            print_warning "$service_name force killed"
        else
            print_status "$service_name stopped gracefully"
        fi
    else
        print_status "$service_name was not running"
    fi
}

# Function to kill processes by name
kill_process() {
    local process_name=$1
    local service_name=$2
    
    local pids=$(pgrep -f "$process_name")
    if [ ! -z "$pids" ]; then
        echo "Stopping $service_name processes..."
        for pid in $pids; do
            kill -TERM $pid 2>/dev/null
        done
        sleep 2
        
        # Force kill remaining processes
        local remaining_pids=$(pgrep -f "$process_name")
        if [ ! -z "$remaining_pids" ]; then
            for pid in $remaining_pids; do
                kill -KILL $pid 2>/dev/null
            done
            print_warning "$service_name processes force killed"
        else
            print_status "$service_name processes stopped gracefully"
        fi
    else
        print_status "$service_name was not running"
    fi
}

echo "Stopping services..."
echo ""

# Stop services using PID files if they exist
if [ -f .frontend.pid ]; then
    FRONTEND_PID=$(cat .frontend.pid)
    echo "Stopping Frontend (PID: $FRONTEND_PID)..."
    kill -TERM $FRONTEND_PID 2>/dev/null && print_status "Frontend stopped" || print_warning "Frontend already stopped"
    rm -f .frontend.pid
fi

if [ -f .backend.pid ]; then
    BACKEND_PID=$(cat .backend.pid)
    echo "Stopping Backend (PID: $BACKEND_PID)..."
    kill -TERM $BACKEND_PID 2>/dev/null && print_status "Backend stopped" || print_warning "Backend already stopped"
    rm -f .backend.pid
fi

if [ -f .anvil.pid ]; then
    ANVIL_PID=$(cat .anvil.pid)
    echo "Stopping Anvil (PID: $ANVIL_PID)..."
    kill -TERM $ANVIL_PID 2>/dev/null && print_status "Anvil stopped" || print_warning "Anvil already stopped"
    rm -f .anvil.pid
fi

# Fallback: Stop by port if PID files don't exist
kill_port 5173 "Frontend (Vite)"
kill_port 3001 "Backend (Node.js)"
kill_port 8545 "Anvil (Local Blockchain)"

# Kill any remaining nodemon processes
kill_process "nodemon" "Nodemon processes"

# Kill any remaining vite processes
kill_process "vite" "Vite processes"

# Kill any remaining anvil processes
kill_process "anvil" "Anvil processes"

echo ""
echo "🎯 Verifying all services are stopped..."

# Check if ports are still in use
for port in 5173 3001 8545; do
    if lsof -i:$port > /dev/null 2>&1; then
        print_error "Port $port is still in use"
    else
        print_status "Port $port is free"
    fi
done

echo ""
echo "🧹 Cleaning up background jobs..."
# Kill any background jobs in the current shell
jobs -p | xargs -r kill 2>/dev/null || true

# Clean up log files and PID files
rm -f anvil.log backend.log frontend.log
rm -f .anvil.pid .backend.pid .frontend.pid

echo ""
print_status "CryptoTicketing development environment stopped!"
echo ""
echo "To restart, run: ./start-dev.sh or manually start each service"