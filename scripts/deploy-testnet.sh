#!/bin/bash
# Deploy Authority Ledger to Base Testnet
# 
# Prerequisites:
# 1. Install Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup
# 2. Set environment variables or create .env file
# 3. Get testnet ETH from faucet: https://faucet.circle.com/

set -e

echo "🧱 Authority Ledger Deployment Script"
echo "======================================"

# Check for environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ PRIVATE_KEY not set"
    echo "Please set: export PRIVATE_KEY=your_private_key"
    exit 1
fi

# Set default RPC if not provided
BASE_SEPOLIA_RPC_URL=${BASE_SEPOLIA_RPC_URL:-"https://sepolia.base.org"}

echo "📡 RPC URL: $BASE_SEPOLIA_RPC_URL"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
forge install foundry-rs/forge-std --no-commit || true

# Compile contracts
echo "🔨 Compiling contracts..."
forge build

# Run tests
echo "🧪 Running tests..."
forge test -vv

# Deploy
echo ""
echo "🚀 Deploying to Base Sepolia..."
forge script script/Deploy.s.sol \
    --rpc-url "$BASE_SEPOLIA_RPC_URL" \
    --broadcast \
    --verify \
    -vvvv

echo ""
echo "✅ Deployment complete!"
echo "Check the output above for contract addresses."