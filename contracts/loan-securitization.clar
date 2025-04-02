;; loan-securitization.clar
;; This contract converts mortgage debt into tradable tokens

(define-data-var contract-owner principal tx-sender)

;; Define the fungible token
(define-fungible-token debt-token)

;; Data structures
(define-map loans
  { loan-id: (string-ascii 36) }
  {
    property-id: (string-ascii 36),
    principal-amount: uint,
    interest-rate: uint,
    term-length: uint,
    origination-date: uint,
    maturity-date: uint,
    tokenized: bool,
    tokens-minted: uint,
    status: (string-ascii 20)
  }
)

(define-map token-holders
  { holder: principal, loan-id: (string-ascii 36) }
  { amount: uint }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-LOAN-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-TOKENIZED (err u102))
(define-constant ERR-PROPERTY-NOT-VERIFIED (err u103))
(define-constant ERR-INSUFFICIENT-TOKENS (err u104))

;; Contract initialization
(define-private (initialize-contract)
  (begin
    (var-set contract-owner tx-sender)
    (ok true)
  )
)

;; Public functions
(define-public (register-loan
  (loan-id (string-ascii 36))
  (property-id (string-ascii 36))
  (principal-amount uint)
  (interest-rate uint)
  (term-length uint)
  (origination-date uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

    ;; Call property-verification contract to check if property is verified
    ;; In a real implementation, this would use contract-call? to the property-verification contract

    (map-set loans
      { loan-id: loan-id }
      {
        property-id: property-id,
        principal-amount: principal-amount,
        interest-rate: interest-rate,
        term-length: term-length,
        origination-date: origination-date,
        maturity-date: (+ origination-date term-length),
        tokenized: false,
        tokens-minted: u0,
        status: "active"
      }
    )
    (ok true)
  )
)

(define-public (tokenize-loan (loan-id (string-ascii 36)) (token-amount uint))
  (let (
    (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get tokenized loan)) ERR-ALREADY-TOKENIZED)

    ;; Mint tokens
    (try! (ft-mint? debt-token token-amount (var-get contract-owner)))

    ;; Update loan status
    (map-set loans
      { loan-id: loan-id }
      (merge loan {
        tokenized: true,
        tokens-minted: token-amount,
        status: "tokenized"
      })
    )

    (ok true)
  )
)

(define-public (transfer-tokens (recipient principal) (loan-id (string-ascii 36)) (amount uint))
  (let (
    (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
    (sender-balance (default-to { amount: u0 } (map-get? token-holders { holder: tx-sender, loan-id: loan-id })))
    (recipient-balance (default-to { amount: u0 } (map-get? token-holders { holder: recipient, loan-id: loan-id })))
  )
    (asserts! (>= (get amount sender-balance) amount) ERR-INSUFFICIENT-TOKENS)

    ;; Update sender balance
    (map-set token-holders
      { holder: tx-sender, loan-id: loan-id }
      { amount: (- (get amount sender-balance) amount) }
    )

    ;; Update recipient balance
    (map-set token-holders
      { holder: recipient, loan-id: loan-id }
      { amount: (+ (get amount recipient-balance) amount) }
    )

    ;; Transfer tokens
    (try! (ft-transfer? debt-token amount tx-sender recipient))

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-loan (loan-id (string-ascii 36)))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-token-balance (holder principal) (loan-id (string-ascii 36)))
  (default-to { amount: u0 } (map-get? token-holders { holder: holder, loan-id: loan-id }))
)

(define-read-only (get-total-tokens-minted (loan-id (string-ascii 36)))
  (match (map-get? loans { loan-id: loan-id })
    loan (get tokens-minted loan)
    u0
  )
)
