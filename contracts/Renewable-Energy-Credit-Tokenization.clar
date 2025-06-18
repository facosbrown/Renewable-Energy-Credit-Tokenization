(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_PRODUCER (err u103))
(define-constant ERR_CREDIT_NOT_FOUND (err u104))
(define-constant ERR_CREDIT_ALREADY_RETIRED (err u105))
(define-constant ERR_INVALID_ENERGY_TYPE (err u106))

(define-fungible-token renewable-energy-credit)

(define-map energy-producers
  { producer: principal }
  {
    name: (string-ascii 50),
    energy-type: (string-ascii 20),
    location: (string-ascii 100),
    certified: bool,
    total-generated: uint
  }
)

(define-map credit-details
  { credit-id: uint }
  {
    producer: principal,
    kwh-amount: uint,
    generation-date: uint,
    energy-type: (string-ascii 20),
    retired: bool,
    retirement-date: (optional uint),
    retired-by: (optional principal)
  }
)

(define-data-var next-credit-id uint u1)
(define-data-var total-credits-issued uint u0)
(define-data-var total-credits-retired uint u0)

(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)

(define-read-only (get-total-supply)
  (ft-get-supply renewable-energy-credit)
)

(define-read-only (get-balance (account principal))
  (ft-get-balance renewable-energy-credit account)
)

(define-read-only (get-producer-info (producer principal))
  (map-get? energy-producers { producer: producer })
)

(define-read-only (get-credit-details (credit-id uint))
  (map-get? credit-details { credit-id: credit-id })
)

(define-read-only (get-next-credit-id)
  (var-get next-credit-id)
)

(define-read-only (get-total-credits-issued)
  (var-get total-credits-issued)
)

(define-read-only (get-total-credits-retired)
  (var-get total-credits-retired)
)

(define-public (register-producer 
  (name (string-ascii 50))
  (energy-type (string-ascii 20))
  (location (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_PRODUCER)
    (asserts! (> (len energy-type) u0) ERR_INVALID_ENERGY_TYPE)
    (map-set energy-producers
      { producer: tx-sender }
      {
        name: name,
        energy-type: energy-type,
        location: location,
        certified: true,
        total-generated: u0
      }
    )
    (ok true)
  )
)

(define-public (certify-producer (producer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? energy-producers { producer: producer })
      producer-data
      (begin
        (map-set energy-producers
          { producer: producer }
          (merge producer-data { certified: true })
        )
        (ok true)
      )
      ERR_INVALID_PRODUCER
    )
  )
)

(define-public (issue-credits
  (producer principal)
  (kwh-amount uint)
  (generation-date uint)
  (energy-type (string-ascii 20)))
  (let
    (
      (credit-id (var-get next-credit-id))
      (producer-info (unwrap! (map-get? energy-producers { producer: producer }) ERR_INVALID_PRODUCER))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> kwh-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get certified producer-info) ERR_UNAUTHORIZED)
    
    (try! (ft-mint? renewable-energy-credit kwh-amount producer))
    
    (map-set credit-details
      { credit-id: credit-id }
      {
        producer: producer,
        kwh-amount: kwh-amount,
        generation-date: generation-date,
        energy-type: energy-type,
        retired: false,
        retirement-date: none,
        retired-by: none
      }
    )
    
    (map-set energy-producers
      { producer: producer }
      (merge producer-info { total-generated: (+ (get total-generated producer-info) kwh-amount) })
    )
    
    (var-set next-credit-id (+ credit-id u1))
    (var-set total-credits-issued (+ (var-get total-credits-issued) kwh-amount))
    
    (ok credit-id)
  )
)

(define-public (transfer-credits (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (ft-get-balance renewable-energy-credit tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
    (ft-transfer? renewable-energy-credit amount tx-sender recipient)
  )
)

(define-public (retire-credits (credit-id uint) (amount uint))
  (let
    (
      (credit-info (unwrap! (map-get? credit-details { credit-id: credit-id }) ERR_CREDIT_NOT_FOUND))
      (user-balance (ft-get-balance renewable-energy-credit tx-sender))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (get retired credit-info)) ERR_CREDIT_ALREADY_RETIRED)
    (asserts! (>= (get kwh-amount credit-info) amount) ERR_INVALID_AMOUNT)
    
    (try! (ft-burn? renewable-energy-credit amount tx-sender))
    
    (if (is-eq (get kwh-amount credit-info) amount)
      (map-set credit-details
        { credit-id: credit-id }
        (merge credit-info {
          retired: true,
          retirement-date: (some stacks-block-height),
          retired-by: (some tx-sender)
        })
      )
      (map-set credit-details
        { credit-id: credit-id }
        (merge credit-info {
          kwh-amount: (- (get kwh-amount credit-info) amount)
        })
      )
    )
    
    (var-set total-credits-retired (+ (var-get total-credits-retired) amount))
    (ok true)
  )
)

(define-public (batch-issue-credits
  (producer principal)
  (credits-data (list 10 { kwh-amount: uint, generation-date: uint, energy-type: (string-ascii 20) })))
  (let
    (
      (producer-info (unwrap! (map-get? energy-producers { producer: producer }) ERR_INVALID_PRODUCER))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get certified producer-info) ERR_UNAUTHORIZED)
    
    (fold process-credit-batch credits-data (ok (list)))
  )
)

(define-private (process-credit-batch
  (credit-data { kwh-amount: uint, generation-date: uint, energy-type: (string-ascii 20) })
  (previous-result (response (list 10 uint) uint)))
  (match previous-result
    success-list
    (match (issue-credits 
             tx-sender 
             (get kwh-amount credit-data)
             (get generation-date credit-data)
             (get energy-type credit-data))
      credit-id (ok (unwrap-panic (as-max-len? (append success-list credit-id) u10)))
      error-val (err error-val)
    )
    error-val (err error-val)
  )
)

(define-read-only (get-producer-credits (producer principal))
  (get total-generated (default-to 
    { name: "", energy-type: "", location: "", certified: false, total-generated: u0 }
    (map-get? energy-producers { producer: producer })
  ))
)

(define-read-only (calculate-carbon-offset (kwh-amount uint))
  (* kwh-amount u453)
)

(define-read-only (get-credit-value (credit-id uint))
  (match (map-get? credit-details { credit-id: credit-id })
    credit-info
    (if (get retired credit-info)
      u0
      (get kwh-amount credit-info)
    )
    u0
  )
)
