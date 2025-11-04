(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_AMOUNT (err u201))
(define-constant ERR_INSUFFICIENT_BALANCE (err u202))
(define-constant ERR_LISTING_NOT_FOUND (err u203))
(define-constant ERR_LISTING_EXPIRED (err u204))
(define-constant ERR_CANNOT_BUY_OWN_LISTING (err u205))
(define-constant ERR_INVALID_PRICE (err u206))

(define-data-var next-listing-id uint u1)
(define-data-var marketplace-fee-rate uint u250)

(define-map marketplace-listings
  { listing-id: uint }
  {
    seller: principal,
    amount: uint,
    price-per-unit: uint,
    energy-type: (string-ascii 20),
    created-at: uint,
    expires-at: uint,
    active: bool
  }
)

(define-map seller-stats
  { seller: principal }
  { total-sold: uint, total-earnings: uint, listings-count: uint }
)

(define-read-only (get-listing (listing-id uint))
  (map-get? marketplace-listings { listing-id: listing-id })
)

(define-read-only (get-seller-stats (seller principal))
  (default-to 
    { total-sold: u0, total-earnings: u0, listings-count: u0 }
    (map-get? seller-stats { seller: seller })
  )
)

(define-read-only (get-marketplace-fee-rate)
  (var-get marketplace-fee-rate)
)

(define-read-only (calculate-total-cost (amount uint) (price-per-unit uint))
  (let ((base-cost (* amount price-per-unit)))
    (+ base-cost (/ (* base-cost (var-get marketplace-fee-rate)) u10000))
  )
)

(define-public (create-listing 
  (amount uint)
  (price-per-unit uint)
  (energy-type (string-ascii 20))
  (duration-blocks uint))
  (let
    (
      (listing-id (var-get next-listing-id))
      (expires-at (+ stacks-block-height duration-blocks))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> price-per-unit u0) ERR_INVALID_PRICE)
    (asserts! (>= (contract-call? .Renewable-Energy-Credit-Tokenization get-balance tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (contract-call? .Renewable-Energy-Credit-Tokenization transfer-credits amount (as-contract tx-sender)))
    
    (map-set marketplace-listings
      { listing-id: listing-id }
      {
        seller: tx-sender,
        amount: amount,
        price-per-unit: price-per-unit,
        energy-type: energy-type,
        created-at: stacks-block-height,
        expires-at: expires-at,
        active: true
      }
    )
    
    (let ((current-stats (get-seller-stats tx-sender)))
      (map-set seller-stats
        { seller: tx-sender }
        (merge current-stats { listings-count: (+ (get listings-count current-stats) u1) })
      )
    )
    
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (purchase-credits (listing-id uint) (amount uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR_LISTING_NOT_FOUND))
      (total-cost (calculate-total-cost amount (get price-per-unit listing)))
      (seller-earnings (* amount (get price-per-unit listing)))
    )
    (asserts! (get active listing) ERR_LISTING_NOT_FOUND)
    (asserts! (<= stacks-block-height (get expires-at listing)) ERR_LISTING_EXPIRED)
    (asserts! (not (is-eq tx-sender (get seller listing))) ERR_CANNOT_BUY_OWN_LISTING)
    (asserts! (>= (get amount listing) amount) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? total-cost tx-sender (get seller listing)))
    (try! (as-contract (contract-call? .Renewable-Energy-Credit-Tokenization transfer-credits amount tx-sender)))
    
    (if (is-eq (get amount listing) amount)
      (map-set marketplace-listings
        { listing-id: listing-id }
        (merge listing { active: false })
      )
      (map-set marketplace-listings
        { listing-id: listing-id }
        (merge listing { amount: (- (get amount listing) amount) })
      )
    )
    
    (let ((seller-current-stats (get-seller-stats (get seller listing))))
      (map-set seller-stats
        { seller: (get seller listing) }
        (merge seller-current-stats {
          total-sold: (+ (get total-sold seller-current-stats) amount),
          total-earnings: (+ (get total-earnings seller-current-stats) seller-earnings)
        })
      )
    )
    
    (ok true)
  )
)

(define-public (cancel-listing (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR_LISTING_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get seller listing)) ERR_UNAUTHORIZED)
    (asserts! (get active listing) ERR_LISTING_NOT_FOUND)
    
    (try! (as-contract (contract-call? .Renewable-Energy-Credit-Tokenization transfer-credits (get amount listing) (get seller listing))))
    
    (map-set marketplace-listings
      { listing-id: listing-id }
      (merge listing { active: false })
    )
    (ok true)
  )
)
