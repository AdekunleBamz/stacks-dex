;; ============================================================================
;; SIP-010 Fungible Token Trait (Standard Reference)
;; ============================================================================
;; This is the standard SIP-010 trait that all fungible tokens on Stacks must implement.
;; Reference: https://github.com/stacksgov/sips/blob/main/sips/sip-010/sip-010-fungible-token-standard.md
;; ============================================================================

(define-trait sip-010-trait
  (
    ;; Transfer tokens from sender to recipient
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    
    ;; Get the token name
    (get-name () (response (string-ascii 32) uint))
    
    ;; Get the token symbol
    (get-symbol () (response (string-ascii 32) uint))
    
    ;; Get the number of decimals
    (get-decimals () (response uint uint))
    
    ;; Get the token balance for a principal
    (get-balance (principal) (response uint uint))
    
    ;; Get the total supply
    (get-total-supply () (response uint uint))
    
    ;; Get the token URI (metadata)
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
