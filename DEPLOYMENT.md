# Stacks DEX - Mainnet Deployment Guide

## Prerequisites

1. **Stacks Wallet** with sufficient STX for deployment fees (~1-2 STX)
2. **REOWN Project ID** from https://cloud.reown.com
3. **Token Addresses** - The SIP-010 tokens you want to create a pool for

## Step 1: Deploy the Pool Contract

### Option A: Using Leather/Xverse Wallet + Explorer

1. Go to https://explorer.stacks.co/sandbox/deploy?chain=mainnet
2. Connect your wallet
3. Paste the contents of `contracts/pool.clar`
4. Set contract name: `pool` (or your preferred name)
5. Deploy and confirm transaction
6. Note your deployed contract address: `SP_YOUR_ADDRESS.pool`

### Option B: Using Stacks CLI

```bash
# Install Stacks CLI
npm install -g @stacks/cli

# Deploy (requires wallet private key)
stx deploy_contract contracts/pool.clar pool mainnet \
  --privateKey YOUR_PRIVATE_KEY \
  --fee 0.01
```

## Step 2: Initialize the Pool

After deployment, you need to initialize the pool with liquidity:

```javascript
// Call initialize-pool with initial token amounts
// This must be done ONCE by the deployer

const txOptions = {
  contractAddress: 'SP_YOUR_ADDRESS',
  contractName: 'pool',
  functionName: 'initialize-pool',
  functionArgs: [
    contractPrincipalCV('TOKEN_X_ADDRESS', 'TOKEN_X_NAME'),
    contractPrincipalCV('TOKEN_Y_ADDRESS', 'TOKEN_Y_NAME'),
    uintCV(INITIAL_AMOUNT_X),  // e.g., 1000000000 for 1000 tokens (6 decimals)
    uintCV(INITIAL_AMOUNT_Y)   // e.g., 1000000000 for 1000 tokens (6 decimals)
  ],
  // ... other options
};
```

**Important:** You must have approved/own sufficient amounts of both tokens.

## Step 3: Configure Frontend

Update `frontend/src/app.js`:

```javascript
const CONFIG = {
  network: 'mainnet',
  projectId: 'YOUR_REOWN_PROJECT_ID', // From cloud.reown.com
  
  poolContract: {
    address: 'SP_YOUR_DEPLOYED_ADDRESS',
    name: 'pool'
  },
  tokenX: {
    address: 'TOKEN_X_CONTRACT_ADDRESS',
    name: 'token-x-name',
    symbol: 'SYMBOL',
    decimals: 6,
    assetName: 'asset-name'
  },
  tokenY: {
    address: 'TOKEN_Y_CONTRACT_ADDRESS',
    name: 'token-y-name',
    symbol: 'SYMBOL',
    decimals: 6,
    assetName: 'asset-name'
  },
  // ...
};
```

## Step 4: Get REOWN Project ID

1. Go to https://cloud.reown.com
2. Sign up / Log in
3. Create a new project
4. Copy the Project ID
5. Update `CONFIG.projectId` in app.js

## Step 5: Deploy Frontend

### Vercel (Recommended)

```bash
cd frontend
npm install -g vercel
vercel --prod
```

### Manual Build

```bash
cd frontend
npm run build
# Deploy contents of 'dist' folder to your hosting
```

## Common Mainnet SIP-010 Tokens

| Token | Contract Address | Decimals |
|-------|-----------------|----------|
| STX | Native | 6 |
| ALEX | SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.age000-governance-token | 8 |
| USDA | SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token | 6 |
| xBTC | SP3DX3H4FEYZJZ586MFBS25ZW3HZDMEW92260R2PR.Wrapped-Bitcoin | 8 |
| DIKO | SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-token | 6 |
| MIA | SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2 | 0 |
| NYC | SPSCWDV3RKV5ZRN1FQD84YE1NQFEDJ9R1F4DYQ11.newyorkcitycoin-token-v2 | 0 |

## Security Checklist

- [ ] Contract deployed from secure wallet
- [ ] Initial liquidity amounts verified
- [ ] Frontend config updated with correct addresses
- [ ] REOWN Project ID is valid
- [ ] Tested with small amounts first
- [ ] Post-conditions enabled in frontend

## Mainnet API Endpoints

- **API**: https://api.mainnet.hiro.so
- **Explorer**: https://explorer.stacks.co
- **Contract Verification**: https://explorer.stacks.co/txid/YOUR_TX_ID

## Troubleshooting

### "Contract not found"
- Ensure deployment transaction is confirmed
- Verify contract address in frontend config

### "Insufficient balance"
- Check user has enough tokens
- Verify token contract addresses are correct

### "WalletConnect connection failed"
- Ensure REOWN Project ID is valid
- Check wallet supports WalletConnect (Leather, Xverse)

### "Transaction failed"
- Check reserves are initialized
- Verify slippage tolerance
- Ensure deadline hasn't passed
