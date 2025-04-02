;; default-management.clar
;; This contract handles procedures for non-performing loans

(define-data-var contract-owner principal tx-sender)

;; Data structures
(define-map defaults
  { loan-id: (string-ascii 36) }
  {
    default-date: uint,
    days-past-due: uint,
    outstanding-principal: uint,
    outstanding-interest: uint,
    status: (string-ascii 20), ;; "defaulted", "foreclosure", "resolved"
    resolution-date: (optional uint)
  }
)

(define-map recovery-actions
  { action-id: (string-ascii 36) }
  {
    loan-id: (string-ascii 36),
    action-type: (string-ascii 20), ;; "notice", "negotiation", "foreclosure", "sale"
    action-date: uint,
    description: (string-ascii 100),
    completed: bool
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-LOAN-NOT-FOUND (err u101))
(define-constant ERR-DEFAULT-ALREADY-DECLARED (err u102))
(define-constant ERR-ACTION-NOT-FOUND (err u103))
(define-constant ERR-DEFAULT-NOT-FOUND (err u104))

;; Public functions
(define-public (declare-default
  (loan-id (string-ascii 36))
  (default-date uint)
  (days-past-due uint)
  (outstanding-principal uint)
  (outstanding-interest uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? defaults { loan-id: loan-id })) ERR-DEFAULT-ALREADY-DECLARED)

    (map-set defaults
      { loan-id: loan-id }
      {
        default-date: default-date,
        days-past-due: days-past-due,
        outstanding-principal: outstanding-principal,
        outstanding-interest: outstanding-interest,
        status: "defaulted",
        resolution-date: none
      }
    )
    (ok true)
  )
)

(define-public (create-recovery-action
  (action-id (string-ascii 36))
  (loan-id (string-ascii 36))
  (action-type (string-ascii 20))
  (action-date uint)
  (description (string-ascii 100))
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? defaults { loan-id: loan-id })) ERR-DEFAULT-NOT-FOUND)

    (map-set recovery-actions
      { action-id: action-id }
      {
        loan-id: loan-id,
        action-type: action-type,
        action-date: action-date,
        description: description,
        completed: false
      }
    )
    (ok true)
  )
)

(define-public (complete-recovery-action (action-id (string-ascii 36)))
  (let (
    (action (unwrap! (map-get? recovery-actions { action-id: action-id }) ERR-ACTION-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

    (map-set recovery-actions
      { action-id: action-id }
      (merge action { completed: true })
    )
    (ok true)
  )
)

(define-public (resolve-default (loan-id (string-ascii 36)) (resolution-date uint))
  (let (
    (default-info (unwrap! (map-get? defaults { loan-id: loan-id }) ERR-DEFAULT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

    (map-set defaults
      { loan-id: loan-id }
      (merge default-info {
        status: "resolved",
        resolution-date: (some resolution-date)
      })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-default (loan-id (string-ascii 36)))
  (map-get? defaults { loan-id: loan-id })
)

(define-read-only (get-recovery-action (action-id (string-ascii 36)))
  (map-get? recovery-actions { action-id: action-id })
)

(define-read-only (get-recovery-actions-for-loan (loan-id (string-ascii 36)))
  ;; In a real implementation, this would return all actions for a loan
  ;; For simplicity, we're just returning a placeholder
  (ok true)
)
