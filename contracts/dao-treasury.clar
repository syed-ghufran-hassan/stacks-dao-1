;; Treasury contract for DAO-controlled asset management

(define-constant ERR-UNAUTHORIZED u101)
(define-constant ERR-INVALID-AMOUNT u102)
(define-constant ERR-SELF-TRANSFER u103)
(define-constant ERR-INSUFFICIENT-BALANCE u104)
(define-constant DAO-CORE .dao-core-v1)

;; Track proposal IDs that have been executed (prevents replay attacks)
(define-map executed-proposals uint bool)

;; Emit events for transparency
(define-data-var last-executed-block uint u0)

;; Emergency pause functionality
(define-data-var paused bool false)

;; Only the DAO contract can call treasury functions
(define-private (is-dao-caller)
  (is-eq tx-sender DAO-CORE)
)

(define-public (execute-stx-transfer 
  (proposal-id uint) 
  (amount uint) 
  (recipient principal) 
  (memo (optional (string-utf8 140)))
)
  (let (
    ;; Check if contract is paused
    (check-paused (asserts! (not (var-get paused)) (err ERR-UNAUTHORIZED)))
    
    ;; Validate proposal hasn't been executed before (anti-replay)
    (check-proposal (asserts! (not (default-to false (map-get? executed-proposals proposal-id))) (err ERR-UNAUTHORIZED)))
    
    ;; Only DAO can execute transfers
    (check-caller (asserts! (is-dao-caller) (err ERR-UNAUTHORIZED)))
    
    ;; Validate amount is positive
    (check-amount (asserts! (> amount u0) (err ERR-INVALID-AMOUNT)))
    
    ;; Prevent self-transfer to contract itself
    (check-recipient (asserts! (not (is-eq recipient (as-contract tx-sender))) (err ERR-SELF-TRANSFER)))
    
    ;; Check contract has sufficient balance
    (contract-balance (stx-get-balance (as-contract tx-sender)))
    (check-balance (asserts! (>= contract-balance amount) (err ERR-INSUFFICIENT-BALANCE)))
  )
  
  ;; Mark proposal as executed
  (map-set executed-proposals proposal-id true)
  
  ;; Update last executed block
  (var-set last-executed-block block-height)
  
  ;; Execute the transfer
  (try! (as-contract (stx-transfer? amount (as-contract tx-sender) recipient)))
  
  ;; Emit event (if using Clarity 2.x or with custom event system)
  ;; For Clarity 1.x, you can print to console for logging
  (print { event: "stx-transfer-executed", proposal-id: proposal-id, amount: amount, recipient: recipient })
  
  (ok { 
    proposal-id: proposal-id,
    amount: amount, 
    recipient: recipient,
    memo: memo,
    block: block-height
  })
))

;; Emergency pause - only DAO can pause/resume
(define-public (emergency-pause)
  (begin
    (asserts! (is-dao-caller) (err ERR-UNAUTHORIZED))
    (var-set paused true)
    (ok true)
  )
)

(define-public (emergency-resume)
  (begin
    (asserts! (is-dao-caller) (err ERR-UNAUTHORIZED))
    (var-set paused false)
    (ok true)
  )
)

;; View functions for transparency
(define-read-only (get-balance)
  (ok (stx-get-balance (as-contract tx-sender)))
)

(define-read-only (is-proposal-executed (proposal-id uint))
  (ok (default-to false (map-get? executed-proposals proposal-id)))
)

(define-read-only (get-last-executed-block)
  (ok (var-get last-executed-block))
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

;; Allow contract to receive STX (important!)
(define-public (receive-stx)
  (ok true)
)

;; Batch transfer capability
(define-public (execute-batch-stx-transfer
  (proposal-id uint)
  (transfers (list 10 { amount: uint, recipient: principal, memo: (optional (string-utf8 140)) }))
)
  (let (
    (check-paused (asserts! (not (var-get paused)) (err ERR-UNAUTHORIZED)))
    (check-proposal (asserts! (not (default-to false (map-get? executed-proposals proposal-id))) (err ERR-UNAUTHORIZED)))
    (check-caller (asserts! (is-dao-caller) (err ERR-UNAUTHORIZED)))
    
    ;; Calculate total amount needed
    (total-amount (fold sum-transfers transfers u0))
    (contract-balance (stx-get-balance (as-contract tx-sender)))
    (check-balance (asserts! (>= contract-balance total-amount) (err ERR-INSUFFICIENT-BALANCE)))
  )
  
  ;; Mark proposal as executed
  (map-set executed-proposals proposal-id true)
  
  ;; Execute all transfers
  (map execute-transfer transfers)
  
  ;; Update last executed block
  (var-set last-executed-block block-height)
  
  (print { event: "batch-transfer-executed", proposal-id: proposal-id, transfers: (len transfers), total: total-amount })
  
  (ok { 
    proposal-id: proposal-id,
    total-transferred: total-amount,
    transfers: (len transfers),
    block: block-height
  })
)

;; Helper function for batch transfers
(define-private (sum-transfers (total uint) (transfer { amount: uint, recipient: principal, memo: (optional (string-utf8 140)) }))
  (+ total (get amount transfer))
)

(define-private (execute-transfer (transfer { amount: uint, recipient: principal, memo: (optional (string-utf8 140)) }))
  (let (
    (amount (get amount transfer))
    (recipient (get recipient transfer))
  )
  (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
  (asserts! (not (is-eq recipient (as-contract tx-sender))) (err ERR-SELF-TRANSFER))
  (try! (as-contract (stx-transfer? amount (as-contract tx-sender) recipient)))
)
