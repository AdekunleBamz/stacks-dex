# Stacks DEX - Minimal AMM

A minimal, production-credible decentralized exchange (DEX) on Stacks (Bitcoin L2) implementing a constant-product AMM (x · y = k).

## Features

- **Constant-Product AMM**: Simple and proven x · y = k formula
- **0.30% Fee**: Deducted from input, retained in pool
- **Slippage Protection**: User-defined minimum output
- **Deadline Protection**: Block height-based expiration
- **Post-Conditions**: Frontend adds safety checks for user protection

## Architecture

```
stacks-dex/
├── contracts/
│   ├── pool.clar              # Main AMM pool contract
│   ├── traits/
│   │   └── sip-010-trait.clar # SIP-010 fungible token trait
│   └── test-tokens/
│       ├── token-x.clar       # Test token X
│       └── token-y.clar       # Test token Y
├── frontend/
│   ├── src/
│   │   ├── app.js            # Main application
│   │   └── styles.css        # Styles
│   ├── index.html            # Entry point
│   └── package.json          # Dependencies
└── Clarinet.toml             # Clarinet configuration
```

## Smart Contract

### pool.clar

The pool contract implements a single-direction swap (X → Y) with:

#### Constants
- `FEE_BPS = 30` (0.30%)
- `BPS_DENOM = 10000`

#### Read-Only Functions

**`get-reserves`**
```clarity
(define-read-only (get-reserves)
  { x: uint, y: uint }
)
```

**`quote-x-for-y (dx uint)`**
```clarity
;; Calculates output amount with fee:
;; dx_after_fee = dx * 9970 / 10000
;; dy = (reserve_y * dx_after_fee) / (reserve_x + dx_after_fee)
```

#### Public Functions

**`swap-x-for-y (token-x, token-y, dx, min-dy, recipient, deadline)`**

Executes swap with:
1. Deadline validation (`block-height <= deadline`)
2. Input validation (`dx > 0`)
3. Fee calculation (0.30% deducted from input)
4. AMM formula application
5. Slippage check (`dy >= min-dy`)
6. Token transfers
7. Reserve updates

### Error Codes

| Code | Description |
|------|-------------|
| u100 | Zero input |
| u101 | Zero reserves |
| u102 | Deadline expired |
| u103 | Slippage exceeded |
| u104 | Insufficient liquidity |
| u105 | Token X transfer failed |
| u106 | Token Y transfer failed |

## Frontend

### Wallet Connection Architecture

REOWN AppKit does **NOT** provide a Stacks-specific SDK. Stacks support is achieved by combining:

```
DEX Frontend
     |
     |  Wallet UI + sessions
     v
REOWN AppKit (chain-agnostic transport + UX)
     |
     |  WalletConnect v2 transport
     v
WalletConnect Stacks JSON-RPC
     |
     |  stx_* methods
     v
Stacks Wallet (Hiro / Xverse / Leather)
```

**Key Points:**
- **REOWN AppKit**: Provides wallet connection UI/UX and WalletConnect v2 transport
- **WalletConnect Universal Provider**: Chain-agnostic session management
- **Stacks JSON-RPC Methods**: `stx_getAddresses`, `stx_signTransaction`, `stx_signMessage`
- **Frontend builds transactions**, wallet only signs them

### Stack
- Vanilla JavaScript (ES Modules)
- Vite for bundling
- @reown/appkit for wallet UI
- @walletconnect/universal-provider for WalletConnect v2
- @stacks/transactions for transaction building

### Features
- Connect/disconnect wallet
- Real-time quote calculation
- Configurable slippage tolerance (default: 0.5%)
- Configurable deadline (default: 20 blocks)
- Fee display
- Price impact calculation

## WalletConnect Stacks JSON-RPC Methods

### stx_getAddresses
Get user's Stacks addresses:
```javascript
const response = await provider.request({
  method: 'stx_getAddresses',
  params: {}
}, 'stacks:2147483648'); // testnet chain ID

// Response: { addresses: [{ address: 'ST...', publicKey: '...' }] }
```

### stx_signTransaction
Sign a Stacks transaction:
```javascript
const signedTx = await provider.request({
  method: 'stx_signTransaction',
  params: {
    transaction: '0x...', // Serialized unsigned tx
    network: 'testnet',
    address: 'ST...'
  }
}, 'stacks:2147483648');
```

### stx_signMessage
Sign an arbitrary message:
```javascript
const signature = await provider.request({
  method: 'stx_signMessage',
  params: {
    message: 'Hello Stacks!',
    address: 'ST...'
  }
}, 'stacks:2147483648');
```

## Development

### Prerequisites
- Node.js 18+
- Clarinet (for contract testing)
- Leather or Xverse wallet browser extension

### Setup

1. **Install Clarinet**
```bash
curl -L https://get.clarinet.dev | bash
```

2. **Test Contracts**
```bash
cd stacks-dex
clarinet check
clarinet test
```

3. **Run Frontend**
```bash
cd frontend
npm install
npm run dev
```

### Deployment

1. **Deploy to Testnet**
```bash
clarinet deployments generate --testnet
clarinet deployments apply -p deployments/testnet.yaml
```

2. **Update Frontend Config**
Update `CONFIG` in `frontend/src/app.js` with deployed contract addresses.

## WalletConnect Integration (Future)

While REOWN AppKit doesn't currently support Stacks, the Stacks ecosystem is working on WalletConnect integration. When available:

```javascript
// Future WalletConnect example
import { createAppKit } from '@reown/appkit';
import { StacksAdapter } from '@reown/appkit-adapter-stacks'; // Not yet available

const appKit = createAppKit({
  projectId: 'YOUR_PROJECT_ID',
  adapters: [new StacksAdapter()],
  networks: [stacksMainnet]
});
```

For now, use `@stacks/connect` for production Stacks dApps.

## REOWN AppKit Integration

The frontend uses REOWN AppKit as the **transport layer** with WalletConnect v2:

```javascript
import { createAppKit } from '@reown/appkit';
import UniversalProvider from '@walletconnect/universal-provider';

// 1. Initialize Universal Provider
const provider = await UniversalProvider.init({
  projectId: 'YOUR_PROJECT_ID',
  metadata: { name: 'Stacks DEX', ... }
});

// 2. Connect with Stacks namespace
const session = await provider.connect({
  namespaces: {
    stacks: {
      methods: ['stx_getAddresses', 'stx_signTransaction', 'stx_signMessage'],
      chains: ['stacks:2147483648'], // testnet
      events: ['accountsChanged']
    }
  }
});

// 3. Use stx_* methods for Stacks operations
const addresses = await provider.request({
  method: 'stx_getAddresses',
  params: {}
}, 'stacks:2147483648');
```

## AMM Math

### Constant Product Formula

Given reserves $(x, y)$ and input $\Delta x$:

$$
\Delta x_{fee} = \Delta x \times \frac{10000 - 30}{10000}
$$

$$
\Delta y = \frac{y \times \Delta x_{fee}}{x + \Delta x_{fee}}
$$

This ensures:
- Fee is deducted from input (stays in pool)
- Product invariant is maintained: $(x + \Delta x_{fee})(y - \Delta y) \geq xy$

### Price Impact

$$
\text{Impact} = 1 - \frac{\Delta y / \Delta x}{y / x}
$$

## Security Considerations

1. **No Admin Functions**: Contract is immutable after deployment
2. **Slippage Protection**: Users set minimum acceptable output
3. **Deadline**: Prevents stale transactions
4. **Post-Conditions**: Frontend adds additional safety checks
5. **Integer Math**: All calculations use uint to prevent overflow/underflow

## License

MIT
