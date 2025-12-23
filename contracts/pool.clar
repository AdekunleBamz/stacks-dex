;; ============================================================================
;; STACKS DEX - Constant Product AMM Pool Contract (Clarity 3)
;; ============================================================================
;; 
;; This contract implements a minimal constant-product AMM (x · y = k) for
;; swapping between two SIP-010 fungible tokens on Stacks (Bitcoin L2).
;;
;; Key Features:
;; - Single swap direction: Token X → Token Y
;; - 0.30% fee deducted from input, sent to fee-recipient (set at init)
;; - Slippage protection via min-dy parameter
;; - Deadline protection via block-height check
;; - No admin functions, no upgradability
;;
;; AMM Formula:
;; Given reserves (x, y) and input dx:
;;   fee = dx * 30 / 10000
;;   dx_to_pool = dx - fee
;;   dy = (y * dx_to_pool) / (x + dx_to_pool)
;;
;; The fee (0.30%) is sent to the fee recipient (whoever initializes the pool).
;; ============================================================================

;; ============================================================================
;; TRAITS
;; ============================================================================

;; SIP-010 Fungible Token Trait
(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; ============================================================================
;; CONSTANTS
;; ============================================================================

;; Fee configuration: 30 basis points = 0.30%
(define-constant FEE_BPS u30)
(define-constant BPS_DENOM u10000)

;; Error codes
(define-constant ERR_ZERO_INPUT (err u100))
(define-constant ERR_ZERO_RESERVES (err u101))
(define-constant ERR_DEADLINE_EXPIRED (err u102))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u103))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u104))
(define-constant ERR_TRANSFER_X_FAILED (err u105))
(define-constant ERR_TRANSFER_Y_FAILED (err u106))
(define-constant ERR_FEE_TRANSFER_FAILED (err u107))
(define-constant ERR_ALREADY_INITIALIZED (err u200))
(define-constant ERR_NOT_INITIALIZED (err u201))

;; ============================================================================
;; DATA VARIABLES
;; ============================================================================

;; Fee recipient - set to tx-sender when pool is initialized
;; This is whoever calls initialize-pool first (should be deployer/you)
(define-data-var fee-recipient (optional principal) none)

;; Pool reserves - tracks the current balance of each token in the pool
(define-data-var reserve-x uint u0)
(define-data-var reserve-y uint u0)

;; Total fees collected (for tracking)
(define-data-var total-fees-collected uint u0)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Get current pool reserves
(define-read-only (get-reserves)
  {
    x: (var-get reserve-x),
    y: (var-get reserve-y)
  }
)

;; Get fee configuration and recipient
(define-read-only (get-fee-info)
  {
    fee-bps: FEE_BPS,
    denom: BPS_DENOM,
    recipient: (var-get fee-recipient)
  }
)

;; Get total fees collected
(define-read-only (get-total-fees)
  (var-get total-fees-collected)
)

;; Quote: Calculate output amount for a given input
;; 
;; Parameters:
;;   dx: Amount of token X to swap (in smallest units)
;;
;; Returns: Amount of token Y that would be received (ok uint) or error
(define-read-only (quote-x-for-y (dx uint))
  (let
    (
      (rx (var-get reserve-x))
      (ry (var-get reserve-y))
    )
    ;; Validate inputs
    (asserts! (> dx u0) ERR_ZERO_INPUT)
    (asserts! (and (> rx u0) (> ry u0)) ERR_ZERO_RESERVES)
    
    (let
      (
        ;; Calculate fee: fee = dx * 30 / 10000
        (fee (/ (* dx FEE_BPS) BPS_DENOM))
        ;; Amount going to pool after fee
        (dx-to-pool (- dx fee))
        ;; AMM formula: dy = (ry * dx_to_pool) / (rx + dx_to_pool)
        (numerator (* ry dx-to-pool))
        (denominator (+ rx dx-to-pool))
        (dy (/ numerator denominator))
      )
      ;; Ensure we're not draining the pool
      (asserts! (< dy ry) ERR_INSUFFICIENT_LIQUIDITY)
      (ok dy)
    )
  )
)

;; Calculate the fee amount for a given input
(define-read-only (calculate-fee (dx uint))
  (/ (* dx FEE_BPS) BPS_DENOM)
)

;; ============================================================================
;; PUBLIC FUNCTIONS
;; ============================================================================

;; Swap Token X for Token Y
;;
;; Executes a swap using the constant-product AMM formula.
;; The fee (0.30%) is sent directly to the fee-recipient (set at initialization).
;;
;; Parameters:
;;   token-x: SIP-010 token contract for input token
;;   token-y: SIP-010 token contract for output token  
;;   dx: Amount of token X to swap (in smallest units)
;;   min-dy: Minimum acceptable output (slippage protection)
;;   recipient: Address to receive output tokens
;;   deadline: Maximum block height for execution
;;
;; Returns: { dx: uint, dy: uint, fee: uint, recipient: principal }
(define-public (swap-x-for-y 
    (token-x <ft-trait>)
    (token-y <ft-trait>)
    (dx uint)
    (min-dy uint)
    (recipient principal)
    (deadline uint))
  (let
    (
      (rx (var-get reserve-x))
      (ry (var-get reserve-y))
      (sender tx-sender)
      (fee-addr (unwrap! (var-get fee-recipient) ERR_NOT_INITIALIZED))
    )
    ;; ========================================
    ;; VALIDATION
    ;; ========================================
    
    ;; Check deadline hasn't passed
    (asserts! (<= stacks-block-height deadline) ERR_DEADLINE_EXPIRED)
    
    ;; Check input is non-zero
    (asserts! (> dx u0) ERR_ZERO_INPUT)
    
    ;; Check pool has liquidity
    (asserts! (and (> rx u0) (> ry u0)) ERR_ZERO_RESERVES)
    
    ;; ========================================
    ;; CALCULATE FEE AND OUTPUT
    ;; ========================================
    (let
      (
        ;; Calculate fee: fee = dx * 30 / 10000 (0.30%)
        (fee (/ (* dx FEE_BPS) BPS_DENOM))
        ;; Amount going to pool after fee deduction
        (dx-to-pool (- dx fee))
        ;; AMM formula: dy = (ry * dx_to_pool) / (rx + dx_to_pool)
        (numerator (* ry dx-to-pool))
        (denominator (+ rx dx-to-pool))
        (dy (/ numerator denominator))
      )
      
      ;; ========================================
      ;; SLIPPAGE CHECK
      ;; ========================================
      
      ;; Ensure output meets minimum requirement
      (asserts! (>= dy min-dy) ERR_SLIPPAGE_EXCEEDED)
      
      ;; Ensure we're not draining the pool
      (asserts! (< dy ry) ERR_INSUFFICIENT_LIQUIDITY)
      
      ;; ========================================
      ;; EXECUTE TRANSFERS
      ;; ========================================
      
      ;; 1. Transfer fee from sender to fee-recipient (your wallet)
      (if (> fee u0)
        (unwrap! 
          (contract-call? token-x transfer fee sender fee-addr none)
          ERR_FEE_TRANSFER_FAILED)
        true
      )
      
      ;; 2. Transfer remaining token X from sender to this contract (pool)
      (unwrap! 
        (contract-call? token-x transfer dx-to-pool sender (as-contract tx-sender) none)
        ERR_TRANSFER_X_FAILED)
      
      ;; 3. Transfer token Y from this contract to recipient
      (unwrap! 
        (as-contract (contract-call? token-y transfer dy tx-sender recipient none))
        ERR_TRANSFER_Y_FAILED)
      
      ;; ========================================
      ;; UPDATE STATE
      ;; ========================================
      
      ;; Update reserves (only dx-to-pool goes into reserves, fee goes to your wallet)
      (var-set reserve-x (+ rx dx-to-pool))
      (var-set reserve-y (- ry dy))
      
      ;; Track total fees collected
      (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
      
      ;; Return swap details including fee
      (ok { dx: dx, dy: dy, fee: fee, recipient: recipient })
    )
  )
)

;; ============================================================================
;; INITIALIZATION
;; ============================================================================

;; Initialize pool with liquidity
;; Can only be called once (when reserves are zero)
;; The caller (tx-sender) becomes the fee recipient for all future swaps
;; Typically called by the deployer to seed initial liquidity
(define-public (initialize-pool 
    (token-x <ft-trait>)
    (token-y <ft-trait>)
    (amount-x uint)
    (amount-y uint))
  (begin
    ;; Only allow initialization once (when reserves are zero)
    (asserts! (and (is-eq (var-get reserve-x) u0) (is-eq (var-get reserve-y) u0)) ERR_ALREADY_INITIALIZED)
    
    ;; Set the fee recipient to whoever initializes the pool (YOU)
    (var-set fee-recipient (some tx-sender))
    
    ;; Transfer initial liquidity from sender to contract
    (unwrap! 
      (contract-call? token-x transfer amount-x tx-sender (as-contract tx-sender) none)
      ERR_TRANSFER_X_FAILED)
    (unwrap! 
      (contract-call? token-y transfer amount-y tx-sender (as-contract tx-sender) none)
      ERR_TRANSFER_Y_FAILED)
    
    ;; Set initial reserves
    (var-set reserve-x amount-x)
    (var-set reserve-y amount-y)
    
    (ok { x: amount-x, y: amount-y, fee-recipient: tx-sender })
  )
)

;; ============================================================================
;; CONTRACT INFO
;; ============================================================================

;; Get contract information
(define-read-only (get-contract-info)
  {
    name: "stacks-dex-pool",
    version: "1.0.0",
    fee-bps: FEE_BPS,
    fee-recipient: (var-get fee-recipient),
    reserve-x: (var-get reserve-x),
    reserve-y: (var-get reserve-y),
    total-fees: (var-get total-fees-collected)
  }
)
