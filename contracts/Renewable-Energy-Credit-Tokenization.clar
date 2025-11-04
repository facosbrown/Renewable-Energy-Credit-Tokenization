(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_PRODUCER (err u103))
(define-constant ERR_CREDIT_NOT_FOUND (err u104))
(define-constant ERR_CREDIT_ALREADY_RETIRED (err u105))
(define-constant ERR_INVALID_ENERGY_TYPE (err u106))
(define-constant ERR_AUDITOR_NOT_FOUND (err u107))
(define-constant ERR_ALREADY_VERIFIED (err u108))
(define-constant ERR_VERIFICATION_FAILED (err u109))
(define-constant ERR_UNAUTHORIZED_AUDITOR (err u110))

(define-constant ERR_CREDIT_EXPIRED (err u111))
(define-constant ERR_INVALID_EXPIRATION_PERIOD (err u112))
(define-constant DEFAULT_EXPIRATION_BLOCKS u144000)

(define-constant ERR_INVALID_STAKE_AMOUNT (err u113))
(define-constant ERR_STAKE_NOT_FOUND (err u114))
(define-constant ERR_STAKE_LOCKED (err u115))
(define-constant ERR_INVALID_LOCK_PERIOD (err u116))

(define-data-var next-stake-id uint u1)
(define-data-var reward-rate-basis-points uint u500)
(define-data-var early-unstake-penalty-rate uint u1000)
(define-data-var total-staked uint u0)

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


(define-map verified-auditors
  { auditor: principal }
  {
    name: (string-ascii 50),
    certification: (string-ascii 30),
    active: bool,
    verifications-count: uint
  }
)

(define-map credit-verifications
  { credit-id: uint }
  {
    verified: bool,
    auditor: (optional principal),
    verification-date: (optional uint),
    verification-hash: (optional (string-ascii 64)),
    notes: (optional (string-ascii 200))
  }
)

(define-map audit-trail
  { audit-id: uint }
  {
    credit-id: uint,
    action: (string-ascii 20),
    actor: principal,
    timestamp: uint,
    details: (string-ascii 100)
  }
)

(define-data-var next-audit-id uint u1)

(define-public (register-auditor 
  (auditor principal)
  (name (string-ascii 50))
  (certification (string-ascii 30)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set verified-auditors
      { auditor: auditor }
      {
        name: name,
        certification: certification,
        active: true,
        verifications-count: u0
      }
    )
    (ok true)
  )
)

(define-public (verify-credit 
  (credit-id uint)
  (verification-hash (string-ascii 64))
  (notes (string-ascii 200)))
  (let
    (
      (auditor-info (unwrap! (map-get? verified-auditors { auditor: tx-sender }) ERR_UNAUTHORIZED_AUDITOR))
      (credit-info (unwrap! (map-get? credit-details { credit-id: credit-id }) ERR_CREDIT_NOT_FOUND))
      (existing-verification (map-get? credit-verifications { credit-id: credit-id }))
    )
    (asserts! (get active auditor-info) ERR_UNAUTHORIZED_AUDITOR)
    (asserts! (is-none existing-verification) ERR_ALREADY_VERIFIED)
    
    (map-set credit-verifications
      { credit-id: credit-id }
      {
        verified: true,
        auditor: (some tx-sender),
        verification-date: (some stacks-block-height),
        verification-hash: (some verification-hash),
        notes: (some notes)
      }
    )
  
    (map-set verified-auditors
      { auditor: tx-sender }
      (merge auditor-info { verifications-count: (+ (get verifications-count auditor-info) u1) })
    )
    
    (let
      (
        (audit-result (record-audit-event credit-id "VERIFIED" tx-sender "Credit verified by auditor"))
      )
      (ok true)
    )
  )
)

(define-private (record-audit-event 
  (credit-id uint)
  (action (string-ascii 20))
  (actor principal)
  (details (string-ascii 100)))
  (let
    (
      (audit-id (var-get next-audit-id))
    )
    (map-set audit-trail
      { audit-id: audit-id }
      {
        credit-id: credit-id,
        action: action,
        actor: actor,
        timestamp: stacks-block-height,
        details: details
      }
    )
    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

(define-read-only (get-auditor-info (auditor principal))
  (map-get? verified-auditors { auditor: auditor })
)

(define-read-only (get-credit-verification (credit-id uint))
  (map-get? credit-verifications { credit-id: credit-id })
)

(define-read-only (get-audit-record (audit-id uint))
  (map-get? audit-trail { audit-id: audit-id })
)

(define-read-only (is-credit-verified (credit-id uint))
  (get verified (default-to 
    { verified: false, auditor: none, verification-date: none, verification-hash: none, notes: none }
    (map-get? credit-verifications { credit-id: credit-id })
  ))
)


(define-map expiration-config
  { energy-type: (string-ascii 20) }
  { expiration-blocks: uint }
)

(define-data-var global-expiration-enabled bool true)

(define-public (set-expiration-period 
  (energy-type (string-ascii 20))
  (expiration-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> expiration-blocks u0) ERR_INVALID_EXPIRATION_PERIOD)
    (map-set expiration-config
      { energy-type: energy-type }
      { expiration-blocks: expiration-blocks }
    )
    (ok true)
  )
)

(define-public (toggle-expiration-system (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set global-expiration-enabled enabled)
    (ok true)
  )
)

(define-read-only (get-expiration-period (energy-type (string-ascii 20)))
  (get expiration-blocks 
    (default-to 
      { expiration-blocks: DEFAULT_EXPIRATION_BLOCKS }
      (map-get? expiration-config { energy-type: energy-type })
    )
  )
)

(define-read-only (is-credit-expired (credit-id uint))
  (if (var-get global-expiration-enabled)
    (match (map-get? credit-details { credit-id: credit-id })
      credit-info
      (let
        (
          (expiration-period (get-expiration-period (get energy-type credit-info)))
          (expiration-block (+ (get generation-date credit-info) expiration-period))
        )
        (>= stacks-block-height expiration-block)
      )
      true
    )
    false
  )
)

(define-read-only (get-credit-expiration-block (credit-id uint))
  (match (map-get? credit-details { credit-id: credit-id })
    credit-info
    (let
      (
        (expiration-period (get-expiration-period (get energy-type credit-info)))
      )
      (some (+ (get generation-date credit-info) expiration-period))
    )
    none
  )
)

(define-read-only (get-valid-credit-value (credit-id uint))
  (if (is-credit-expired credit-id)
    u0
    (get-credit-value credit-id)
  )
)

(define-public (validate-credit-transfer (credit-id uint) (amount uint))
  (begin
    (asserts! (not (is-credit-expired credit-id)) ERR_CREDIT_EXPIRED)
    (asserts! (>= (get-valid-credit-value credit-id) amount) ERR_INVALID_AMOUNT)
    (ok true)
  )
)

(define-read-only (is-expiration-enabled)
  (var-get global-expiration-enabled)
)


(define-map portfolio-tracking
  { owner: principal }
  {
    total-acquired: uint,
    total-retired: uint,
    total-spent: uint,
    acquisition-count: uint,
    last-activity-block: uint
  }
)

(define-map energy-type-holdings
  { owner: principal, energy-type: (string-ascii 20) }
  { amount: uint, acquisition-cost: uint }
)

(define-map purchase-history
  { owner: principal, purchase-id: uint }
  {
    amount: uint,
    price-paid: uint,
    energy-type: (string-ascii 20),
    purchased-at: uint,
    from-seller: principal
  }
)

(define-data-var next-purchase-id uint u1)

(define-public (record-portfolio-activity
  (amount uint)
  (price-paid uint)
  (energy-type (string-ascii 20))
  (seller principal))
  (let
    (
      (current-portfolio (default-to
        { total-acquired: u0, total-retired: u0, total-spent: u0, acquisition-count: u0, last-activity-block: u0 }
        (map-get? portfolio-tracking { owner: tx-sender })))
      (current-holdings (default-to
        { amount: u0, acquisition-cost: u0 }
        (map-get? energy-type-holdings { owner: tx-sender, energy-type: energy-type })))
      (purchase-id (var-get next-purchase-id))
    )
    (map-set portfolio-tracking
      { owner: tx-sender }
      {
        total-acquired: (+ (get total-acquired current-portfolio) amount),
        total-retired: (get total-retired current-portfolio),
        total-spent: (+ (get total-spent current-portfolio) price-paid),
        acquisition-count: (+ (get acquisition-count current-portfolio) u1),
        last-activity-block: stacks-block-height
      })
    
    (map-set energy-type-holdings
      { owner: tx-sender, energy-type: energy-type }
      {
        amount: (+ (get amount current-holdings) amount),
        acquisition-cost: (+ (get acquisition-cost current-holdings) price-paid)
      })
    
    (map-set purchase-history
      { owner: tx-sender, purchase-id: purchase-id }
      {
        amount: amount,
        price-paid: price-paid,
        energy-type: energy-type,
        purchased-at: stacks-block-height,
        from-seller: seller
      })
    
    (var-set next-purchase-id (+ purchase-id u1))
    (ok purchase-id)
  )
)

(define-read-only (get-portfolio-summary (owner principal))
  (default-to
    { total-acquired: u0, total-retired: u0, total-spent: u0, acquisition-count: u0, last-activity-block: u0 }
    (map-get? portfolio-tracking { owner: owner }))
)

(define-read-only (get-energy-type-holdings (owner principal) (energy-type (string-ascii 20)))
  (default-to
    { amount: u0, acquisition-cost: u0 }
    (map-get? energy-type-holdings { owner: owner, energy-type: energy-type }))
)

(define-read-only (get-purchase-record (owner principal) (purchase-id uint))
  (map-get? purchase-history { owner: owner, purchase-id: purchase-id })
)

(define-read-only (calculate-average-cost (owner principal))
  (let
    (
      (portfolio (get-portfolio-summary owner))
      (total-acquired (get total-acquired portfolio))
      (total-spent (get total-spent portfolio))
    )
    (if (> total-acquired u0)
      (/ total-spent total-acquired)
      u0
    )
  )
)

(define-read-only (get-portfolio-carbon-impact (owner principal))
  (let
    (
      (portfolio (get-portfolio-summary owner))
      (total-credits (get total-acquired portfolio))
    )
    (calculate-carbon-offset total-credits)
  )
)

(define-map credit-stakes
  { stake-id: uint }
  {
    staker: principal,
    amount: uint,
    stake-start-block: uint,
    lock-period-blocks: uint,
    rewards-claimed: uint,
    active: bool
  }
)

(define-map staker-summary
  { staker: principal }
  { total-staked: uint, active-stakes-count: uint, lifetime-rewards: uint }
)

(define-public (stake-credits (amount uint) (lock-period-blocks uint))
  (let
    (
      (stake-id (var-get next-stake-id))
      (current-balance (ft-get-balance renewable-energy-credit tx-sender))
      (staker-info (default-to
        { total-staked: u0, active-stakes-count: u0, lifetime-rewards: u0 }
        (map-get? staker-summary { staker: tx-sender })))
    )
    (asserts! (> amount u0) ERR_INVALID_STAKE_AMOUNT)
    (asserts! (>= lock-period-blocks u1440) ERR_INVALID_LOCK_PERIOD)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (ft-burn? renewable-energy-credit amount tx-sender))
    
    (map-set credit-stakes
      { stake-id: stake-id }
      {
        staker: tx-sender,
        amount: amount,
        stake-start-block: stacks-block-height,
        lock-period-blocks: lock-period-blocks,
        rewards-claimed: u0,
        active: true
      }
    )
    
    (map-set staker-summary
      { staker: tx-sender }
      {
        total-staked: (+ (get total-staked staker-info) amount),
        active-stakes-count: (+ (get active-stakes-count staker-info) u1),
        lifetime-rewards: (get lifetime-rewards staker-info)
      }
    )
    
    (var-set total-staked (+ (var-get total-staked) amount))
    (var-set next-stake-id (+ stake-id u1))
    (ok stake-id)
  )
)

(define-public (unstake-credits (stake-id uint))
  (let
    (
      (stake-info (unwrap! (map-get? credit-stakes { stake-id: stake-id }) ERR_STAKE_NOT_FOUND))
      (unlock-block (+ (get stake-start-block stake-info) (get lock-period-blocks stake-info)))
      (is-locked (< stacks-block-height unlock-block))
      (rewards (calculate-stake-rewards stake-id))
      (staker-info (unwrap! (map-get? staker-summary { staker: tx-sender }) ERR_STAKE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get staker stake-info)) ERR_UNAUTHORIZED)
    (asserts! (get active stake-info) ERR_STAKE_NOT_FOUND)
    
    (let
      (
        (penalty (if is-locked (/ (* (get amount stake-info) (var-get early-unstake-penalty-rate)) u10000) u0))
        (return-amount (+ (- (get amount stake-info) penalty) rewards))
      )
      (try! (ft-mint? renewable-energy-credit return-amount tx-sender))
      
      (map-set credit-stakes
        { stake-id: stake-id }
        (merge stake-info { active: false, rewards-claimed: rewards })
      )
      
      (map-set staker-summary
        { staker: tx-sender }
        (merge staker-info {
          active-stakes-count: (- (get active-stakes-count staker-info) u1),
          lifetime-rewards: (+ (get lifetime-rewards staker-info) rewards)
        })
      )
      
      (var-set total-staked (- (var-get total-staked) (get amount stake-info)))
      (ok return-amount)
    )
  )
)

(define-read-only (calculate-stake-rewards (stake-id uint))
  (match (map-get? credit-stakes { stake-id: stake-id })
    stake-info
    (let
      (
        (blocks-staked (- stacks-block-height (get stake-start-block stake-info)))
        (reward-multiplier (/ (* blocks-staked (var-get reward-rate-basis-points)) u10000))
      )
      (/ (* (get amount stake-info) reward-multiplier) u1440)
    )
    u0
  )
)

(define-read-only (get-stake-info (stake-id uint))
  (map-get? credit-stakes { stake-id: stake-id })
)

(define-read-only (get-staker-summary (staker principal))
  (default-to
    { total-staked: u0, active-stakes-count: u0, lifetime-rewards: u0 }
    (map-get? staker-summary { staker: staker })
  )
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (is-stake-unlocked (stake-id uint))
  (match (map-get? credit-stakes { stake-id: stake-id })
    stake-info
    (>= stacks-block-height (+ (get stake-start-block stake-info) (get lock-period-blocks stake-info)))
    false
  )
)