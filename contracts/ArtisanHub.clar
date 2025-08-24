;; ArtisanHub - A decentralized NFT marketplace for digital artists
;; Artists mint and sell NFTs while collectors discover and purchase unique digital art

;; Data storage
(define-map artist-profiles principal {
  verified: bool,
  collections: (list 10 uint),
  earnings: uint,
  last-sale: uint,
  artwork-count: uint
})

(define-map art-listings uint {
  artist: principal,
  price: uint,
  royalty-rate: uint,
  available: bool,
  category-type: uint,
  total-views: uint,
  listed-at: uint
})

(define-map purchase-history {buyer: principal, listing-id: uint} {
  timestamp: uint,
  completed: bool
})

(define-map art-categories uint (string-ascii 64))

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PARAMS (err u101))
(define-constant ERR_ARTIST_NOT_FOUND (err u102))
(define-constant ERR_LISTING_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_ALREADY_REGISTERED (err u105))
(define-constant ERR_ALREADY_PURCHASED (err u106))
(define-constant ERR_INVALID_PRINCIPAL (err u107))
(define-constant ERR_INVALID_VALUE (err u108))
(define-constant ERR_CATEGORY_NOT_FOUND (err u109))

(define-constant ZERO_ADDRESS 'SP000000000000000000002Q6VF78)
(define-constant MIN_ROYALTY_RATE u1)
(define-constant MAX_ROYALTY_RATE u1000)
(define-constant MIN_ARTWORK_PRICE u1000)
(define-constant MAX_CATEGORY_ID u1000)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-listing-id uint u1)
(define-data-var marketplace-fee-percent uint u5) ;; 5% fee
(define-data-var marketplace-balance uint u0)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner ZERO_ADDRESS)) ERR_INVALID_PRINCIPAL)
    (ok (var-set contract-owner new-owner))))

(define-public (set-marketplace-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u20) ERR_INVALID_PARAMS) ;; Max 20% fee
    (ok (var-set marketplace-fee-percent new-fee))))

(define-public (add-category (category-id uint) (category-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len category-name) u0) ERR_INVALID_PARAMS)
    (asserts! (< category-id MAX_CATEGORY_ID) ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? art-categories category-id)) ERR_ALREADY_REGISTERED)
    (ok (map-set art-categories category-id category-name))))

;; Artist functions
(define-public (register-artist (collections (list 10 uint)))
  (begin
    (asserts! (is-none (map-get? artist-profiles tx-sender)) ERR_ALREADY_REGISTERED)
    (asserts! (validate-collections collections) ERR_INVALID_PARAMS)
    (ok (map-set artist-profiles tx-sender {
      verified: true,
      collections: collections,
      earnings: u0,
      last-sale: u0,
      artwork-count: u0
    }))))

(define-public (update-collections (collections (list 10 uint)))
  (let ((artist-profile (unwrap! (map-get? artist-profiles tx-sender) ERR_ARTIST_NOT_FOUND)))
    (asserts! (validate-collections collections) ERR_INVALID_PARAMS)
    (ok (map-set artist-profiles tx-sender (merge artist-profile {collections: collections})))))

(define-public (pause-sales)
  (let ((artist-profile (unwrap! (map-get? artist-profiles tx-sender) ERR_ARTIST_NOT_FOUND)))
    (ok (map-set artist-profiles tx-sender (merge artist-profile {verified: false})))))

(define-public (resume-sales)
  (let ((artist-profile (unwrap! (map-get? artist-profiles tx-sender) ERR_ARTIST_NOT_FOUND)))
    (ok (map-set artist-profiles tx-sender (merge artist-profile {verified: true})))))

;; Listing functions
(define-public (create-art-listing (price uint) (royalty-rate uint) (category-type uint) (stx-amount uint))
  (begin
    (asserts! (>= price MIN_ARTWORK_PRICE) ERR_INVALID_PARAMS)
    (asserts! (and (>= royalty-rate MIN_ROYALTY_RATE) (<= royalty-rate MAX_ROYALTY_RATE)) ERR_INVALID_PARAMS)
    (asserts! (is-some (map-get? art-categories category-type)) ERR_CATEGORY_NOT_FOUND)
    (asserts! (>= stx-amount price) ERR_INSUFFICIENT_FUNDS)
    
    (let ((listing-id (var-get next-listing-id)))
      (map-set art-listings listing-id {
        artist: tx-sender,
        price: price,
        royalty-rate: royalty-rate,
        available: true,
        category-type: category-type,
        total-views: u0,
        listed-at: u0
      })
      
      (var-set next-listing-id (+ listing-id u1))
      (ok listing-id))))

(define-public (pause-listing (listing-id uint))
  (let ((listing (unwrap! (map-get? art-listings listing-id) ERR_LISTING_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get artist listing)) ERR_NOT_AUTHORIZED)
    (ok (map-set art-listings listing-id (merge listing {available: false})))))

(define-public (resume-listing (listing-id uint))
  (let ((listing (unwrap! (map-get? art-listings listing-id) ERR_LISTING_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get artist listing)) ERR_NOT_AUTHORIZED)
    (ok (map-set art-listings listing-id (merge listing {available: true})))))

(define-public (update-listing-price (listing-id uint) (new-price uint))
  (let ((listing (unwrap! (map-get? art-listings listing-id) ERR_LISTING_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get artist listing)) ERR_NOT_AUTHORIZED)
    (asserts! (> new-price u0) ERR_INVALID_PARAMS)
    
    (ok (map-set art-listings listing-id 
      (merge listing {price: new-price})))))

;; Helper function to check if a category matches artist collections
(define-private (check-category-match (category-type uint) (collections (list 10 uint)))
  (or
    (and (> (len collections) u0) (is-eq category-type (unwrap-panic (element-at collections u0))))
    (and (> (len collections) u1) (is-eq category-type (unwrap-panic (element-at collections u1))))
    (and (> (len collections) u2) (is-eq category-type (unwrap-panic (element-at collections u2))))
    (and (> (len collections) u3) (is-eq category-type (unwrap-panic (element-at collections u3))))
    (and (> (len collections) u4) (is-eq category-type (unwrap-panic (element-at collections u4))))
    (and (> (len collections) u5) (is-eq category-type (unwrap-panic (element-at collections u5))))
    (and (> (len collections) u6) (is-eq category-type (unwrap-panic (element-at collections u6))))
    (and (> (len collections) u7) (is-eq category-type (unwrap-panic (element-at collections u7))))
    (and (> (len collections) u8) (is-eq category-type (unwrap-panic (element-at collections u8))))
    (and (> (len collections) u9) (is-eq category-type (unwrap-panic (element-at collections u9))))
  ))

;; Purchase and earnings
(define-public (purchase-artwork (listing-id uint))
  (let (
    (artist-profile (unwrap! (map-get? artist-profiles tx-sender) ERR_ARTIST_NOT_FOUND))
    (listing (unwrap! (map-get? art-listings listing-id) ERR_LISTING_NOT_FOUND))
    (purchase-key {buyer: tx-sender, listing-id: listing-id})
  )
    (asserts! (get verified artist-profile) ERR_ARTIST_NOT_FOUND)
    (asserts! (get available listing) ERR_LISTING_NOT_FOUND)
    (asserts! (is-none (map-get? purchase-history purchase-key)) ERR_ALREADY_PURCHASED)
    (asserts! (check-category-match (get category-type listing) (get collections artist-profile)) ERR_INVALID_PARAMS)
    
    (let (
      (artwork-price (get price listing))
      (marketplace-fee (/ (* artwork-price (var-get marketplace-fee-percent)) u100))
      (artist-earnings (- artwork-price marketplace-fee))
    )
      (try! (stx-transfer? artwork-price tx-sender (as-contract tx-sender)))
      
      (map-set purchase-history purchase-key {timestamp: u0, completed: true})
      
      (map-set art-listings listing-id (merge listing {
        available: false,
        total-views: (+ (get total-views listing) u1)
      }))
      
      (map-set artist-profiles tx-sender (merge artist-profile {
        earnings: (+ (get earnings artist-profile) artist-earnings),
        artwork-count: (+ (get artwork-count artist-profile) u1)
      }))
      
      (var-set marketplace-balance (+ (var-get marketplace-balance) marketplace-fee))
      
      (ok artist-earnings))))

(define-public (claim-earnings)
  (let ((artist-profile (unwrap! (map-get? artist-profiles tx-sender) ERR_ARTIST_NOT_FOUND)))
    (let ((earnings (get earnings artist-profile)))
      (asserts! (> earnings u0) ERR_INSUFFICIENT_FUNDS)
      
      (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
      
      (map-set artist-profiles tx-sender (merge artist-profile {
        earnings: u0,
        last-sale: u0
      }))
      
      (ok earnings))))

(define-public (withdraw-marketplace-fees)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (let ((amount (var-get marketplace-balance)))
      (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
      
      (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
      
      (var-set marketplace-balance u0)
      
      (ok amount))))

;; Helper functions
(define-private (is-valid-collection (collection uint))
  (is-some (map-get? art-categories collection)))

(define-private (count-valid-collections (collections (list 10 uint)))
  (+ 
    (if (and (> (len collections) u0) (is-valid-collection (unwrap-panic (element-at collections u0)))) u1 u0)
    (if (and (> (len collections) u1) (is-valid-collection (unwrap-panic (element-at collections u1)))) u1 u0)
    (if (and (> (len collections) u2) (is-valid-collection (unwrap-panic (element-at collections u2)))) u1 u0)
    (if (and (> (len collections) u3) (is-valid-collection (unwrap-panic (element-at collections u3)))) u1 u0)
    (if (and (> (len collections) u4) (is-valid-collection (unwrap-panic (element-at collections u4)))) u1 u0)
    (if (and (> (len collections) u5) (is-valid-collection (unwrap-panic (element-at collections u5)))) u1 u0)
    (if (and (> (len collections) u6) (is-valid-collection (unwrap-panic (element-at collections u6)))) u1 u0)
    (if (and (> (len collections) u7) (is-valid-collection (unwrap-panic (element-at collections u7)))) u1 u0)
    (if (and (> (len collections) u8) (is-valid-collection (unwrap-panic (element-at collections u8)))) u1 u0)
    (if (and (> (len collections) u9) (is-valid-collection (unwrap-panic (element-at collections u9)))) u1 u0)
  ))

(define-private (validate-collections (collections (list 10 uint)))
  (let ((collections-len (len collections)))
    (and 
      (> collections-len u0)
      (<= collections-len u10)
      (is-eq collections-len (count-valid-collections collections)))))

;; Read-only functions
(define-read-only (get-artist-profile (artist principal))
  (map-get? artist-profiles artist))

(define-read-only (get-listing (listing-id uint))
  (map-get? art-listings listing-id))

(define-read-only (get-category (category-id uint))
  (map-get? art-categories category-id))

(define-read-only (get-marketplace-fee)
  (var-get marketplace-fee-percent))

(define-read-only (get-marketplace-balance)
  (var-get marketplace-balance))

(define-read-only (get-purchase-record (buyer principal) (listing-id uint))
  (map-get? purchase-history {buyer: buyer, listing-id: listing-id}))
