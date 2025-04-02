;; payment-distribution.clar
;; This contract manages interest and principal payments to investors

(define-data-var contract-owner principal tx-sender)

;; Data structures
(define-map payments
  { payment-id: (string-ascii 36) }
  {
    loan-id: (string-ascii 36),
    amount: uint,
    payment-date: uint,
    payment-type: (string-ascii 10), ;; "interest" or "principal"
    distributed: bool
  }
)

(define-map distributions
  { payment-id: (string-ascii 36), investor: principal }
  {
    amount: uint,
    claimed: bool
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PAYMENT-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-DISTRIBUTED (err u102))
(define-constant ERR-DISTRIBUTION-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-CLAIMED (err u104))

;; Public functions
(define-public (record-payment
  (payment-id (string-ascii 36))
  (loan-id (string-ascii 36))
  (amount uint)
  (payment-date uint)
  (payment-type (string-ascii 10))
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

    (map-set payments
      { payment-id: payment-id }
      {
        loan-id: loan-id,
        amount: amount,
        payment-date: payment-date,
        payment-type: payment-type,
        distributed: false
      }
    )
    (ok true)
  )
)

(define-public (distribute-payment (payment-id (string-ascii 36)))
  (let (
    (payment (unwrap! (map-get? payments { payment-id: payment-id }) ERR-PAYMENT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get distributed payment)) ERR-ALREADY-DISTRIBUTED)

    ;; In a real implementation, this would calculate each investor's share
    ;; based on their token holdings and distribute accordingly
    ;; For simplicity, we're just marking the payment as distributed

    (map-set payments
      { payment-id: payment-id }
      (merge payment { distributed: true })
    )

    (ok true)
  )
)

(define-public (allocate-to-investor
  (payment-id (string-ascii 36))
  (investor principal)
  (amount uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

    (map-set distributions
      { payment-id: payment-id, investor: investor }
      {
        amount: amount,
        claimed: false
      }
    )
    (ok true)
  )
)

(define-public (claim-distribution (payment-id (string-ascii 36)))
  (let (
    (distribution (unwrap! (map-get? distributions { payment-id: payment-id, investor: tx-sender }) ERR-DISTRIBUTION-NOT-FOUND))
  )
    (asserts! (not (get claimed distribution)) ERR-ALREADY-CLAIMED)

    ;; In a real implementation, this would transfer funds to the investor
    ;; For simplicity, we're just marking the distribution as claimed

    (map-set distributions
      { payment-id: payment-id, investor: tx-sender }
      (merge distribution { claimed: true })
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-payment (payment-id (string-ascii 36)))
  (map-get? payments { payment-id: payment-id })
)

(define-read-only (get-distribution (payment-id (string-ascii 36)) (investor principal))
  (map-get? distributions { payment-id: payment-id, investor: investor })
)

(define-read-only (is-payment-distributed (payment-id (string-ascii 36)))
  (match (map-get? payments { payment-id: payment-id })
    payment (get distributed payment)
    false
  )
)
