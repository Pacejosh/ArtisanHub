# ArtisanHub - Decentralized NFT Marketplace

A blockchain-based NFT marketplace built on Stacks that empowers digital artists to mint, list, and sell their artwork while providing collectors with a curated platform to discover unique digital art.

## Features

- **Artist Registration**: Artists can register and manage their collections
- **NFT Listings**: Create and manage artwork listings with custom pricing and royalties
- **Secure Purchases**: Blockchain-verified transactions with automatic fee distribution
- **Category System**: Organized artwork categories for better discovery
- **Earnings Management**: Artists can track and claim their earnings
- **Marketplace Fees**: Transparent fee structure with admin controls

## Smart Contract Functions

### Artist Functions
- `register-artist`: Register as an artist with collection preferences
- `update-collections`: Modify artist collection categories
- `pause-sales`/`resume-sales`: Control artwork availability

### Listing Functions
- `create-art-listing`: List new artwork for sale
- `pause-listing`/`resume-listing`: Control individual listing availability
- `update-listing-price`: Modify artwork pricing

### Purchase Functions
- `purchase-artwork`: Buy listed artwork
- `claim-earnings`: Withdraw earned STX from sales

### Admin Functions
- `add-category`: Add new artwork categories
- `set-marketplace-fee`: Adjust marketplace commission

## Getting Started

1. Deploy the smart contract to Stacks blockchain
2. Initialize artwork categories through admin functions
3. Artists register and create listings
4. Collectors browse and purchase artwork

## License

MIT License
\`\`\`

```clarity file="project-2-lending-protocol/contracts/lending-protocol.clar"
;; CreditFlow - A decentralized lending and borrowing protocol
;; Users can lend assets to earn interest or borrow against collateral

;; Data storage
(define-map lender-accounts principal {
  active: bool,
  asset-types: (list 10 uint),
  interest-earned: uint,
  last-withdrawal: uint,
  loan-count: uint
})

(define-map loan-offers uint {
  lender: principal,
  collateral-amount: uint,
  interest-rate: uint,
  available: bool,
  asset-type: uint,
  total-borrowers: uint,
  created-at: uint
})

(define-map borrow-records {borrower: principal, offer-id: uint} {
  timestamp: uint,
  repaid: bool
})

(define-map collateral-types uint (string-ascii 64))

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PARAMS (err u101))
(define-constant ERR_LENDER_NOT_FOUND (err u102))
(define-constant ERR_OFFER_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_ALREADY_REGISTERED (err u105))
(define-constant ERR_ALREADY_BORROWED (err u106))
(define-constant ERR_INVALID_PRINCIPAL (err u107))
(define-constant ERR_INVALID_VALUE (err u108))
(define-constant ERR_ASSET_NOT_FOUND (err u109))

(define-constant ZERO_ADDRESS 'SP000000000000000000002Q6VF78)
(define-constant MIN_INTEREST_RATE u1)
(define-constant MAX_INTEREST_RATE u1000)
(define-constant MIN_COLLATERAL_AMOUNT u1000)
(define-constant MAX_ASSET_ID u1000)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-offer-id uint u1)
(define-data-var protocol-fee-percent uint u5) ;; 5% fee
(define-data-var protocol-treasury uint u0)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner ZERO_ADDRESS)) ERR_INVALID_PRINCIPAL)
    (ok (var-set contract-owner new-owner))))

(define-public (set-protocol-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (&lt;= new-fee u20) ERR_INVALID_PARAMS) ;; Max 20% fee
    (ok (var-set protocol-fee-percent new-fee))))

(define-public (add-asset-type (asset-id uint) (asset-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len asset-name) u0) ERR_INVALID_PARAMS)
    (asserts! (&lt; asset-id MAX_ASSET_ID) ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? collateral-types asset-id)) ERR_ALREADY_REGISTERED)
    (ok (map-set collateral-types asset-id asset-name))))

;; Lender functions
(define-public (register-lender (asset-types (list 10 uint)))
  (begin
    (asserts! (is-none (map-get? lender-accounts tx-sender)) ERR_ALREADY_REGISTERED)
    (asserts! (validate-asset-types asset-types) ERR_INVALID_PARAMS)
    (ok (map-set lender-accounts tx-sender {
      active: true,
      asset-types: asset-types,
      interest-earned: u0,
      last-withdrawal: u0,
      loan-count: u0
    }))))

(define-public (update-asset-preferences (asset-types (list 10 uint)))
  (let ((lender-account (unwrap! (map-get? lender-accounts tx-sender) ERR_LENDER_NOT_FOUND)))
    (asserts! (validate-asset-types asset-types) ERR_INVALID_PARAMS)
    (ok (map-set lender-accounts tx-sender (merge lender-account {asset-types: asset-types})))))

(define-public (pause-lending)
  (let ((lender-account (unwrap! (map-get? lender-accounts tx-sender) ERR_LENDER_NOT_FOUND)))
    (ok (map-set lender-accounts tx-sender (merge lender-account {active: false})))))

(define-public (resume-lending)
  (let ((lender-account (unwrap! (map-get? lender-accounts tx-sender) ERR_LENDER_NOT_FOUND)))
    (ok (map-set lender-accounts tx-sender (merge lender-account {active: true})))))

;; Loan offer functions
(define-public (create-loan-offer (collateral-amount uint) (interest-rate uint) (asset-type uint) (stx-amount uint))
  (begin
    (asserts! (>= collateral-amount MIN_COLLATERAL_AMOUNT) ERR_INVALID_PARAMS)
    (asserts! (and (>= interest-rate MIN_INTEREST_RATE) (&lt;= interest-rate MAX_INTEREST_RATE)) ERR_INVALID_PARAMS)
    (asserts! (is-some (map-get? collateral-types asset-type)) ERR_ASSET_NOT_FOUND)
    (asserts! (>= stx-amount collateral-amount) ERR_INSUFFICIENT_FUNDS)
    
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    
    (let ((offer-id (var-get next-offer-id)))
      (map-set loan-offers offer-id {
        lender: tx-sender,
        collateral-amount: collateral-amount,
        interest-rate: interest-rate,
        available: true,
        asset-type: asset-type,
        total-borrowers: u0,
        created-at: u0
      })
      
      (var-set next-offer-id (+ offer-id u1))
      (ok offer-id))))

(define-public (pause-offer (offer-id uint))
  (let ((offer (unwrap! (map-get? loan-offers offer-id) ERR_OFFER_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get lender offer)) ERR_NOT_AUTHORIZED)
    (ok (map-set loan-offers offer-id (merge offer {available: false})))))

(define-public (resume-offer (offer-id uint))
  (let ((offer (unwrap! (map-get? loan-offers offer-id) ERR_OFFER_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get lender offer)) ERR_NOT_AUTHORIZED)
    (ok (map-set loan-offers offer-id (merge offer {available: true})))))

(define-public (add-offer-liquidity (offer-id uint) (additional-amount uint))
  (let ((offer (unwrap! (map-get? loan-offers offer-id) ERR_OFFER_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get lender offer)) ERR_NOT_AUTHORIZED)
    (asserts! (> additional-amount u0) ERR_INVALID_PARAMS)
    
    (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
    
    (ok (map-set loan-offers offer-id 
      (merge offer {collateral-amount: (+ (get collateral-amount offer) additional-amount)})))))

;; Helper function to check if an asset type matches lender preferences
(define-private (check-asset-match (asset-type uint) (asset-types (list 10 uint)))
  (or
    (and (> (len asset-types) u0) (is-eq asset-type (unwrap-panic (element-at asset-types u0))))
    (and (> (len asset-types) u1) (is-eq asset-type (unwrap-panic (element-at asset-types u1))))
    (and (> (len asset-types) u2) (is-eq asset-type (unwrap-panic (element-at asset-types u2))))
    (and (> (len asset-types) u3) (is-eq asset-type (unwrap-panic (element-at asset-types u3))))
    (and (> (len asset-types) u4) (is-eq asset-type (unwrap-panic (element-at asset-types u4))))
    (and (> (len asset-types) u5) (is-eq asset-type (unwrap-panic (element-at asset-types u5))))
    (and (> (len asset-types) u6) (is-eq asset-type (unwrap-panic (element-at asset-types u6))))
    (and (> (len asset-types) u7) (is-eq asset-type (unwrap-panic (element-at asset-types u7))))
    (and (> (len asset-types) u8) (is-eq asset-type (unwrap-panic (element-at asset-types u8))))
    (and (> (len asset-types) u9) (is-eq asset-type (unwrap-panic (element-at asset-types u9))))
  ))

;; Borrowing and interest
(define-public (borrow-from-offer (offer-id uint))
  (let (
    (lender-account (unwrap! (map-get? lender-accounts tx-sender) ERR_LENDER_NOT_FOUND))
    (offer (unwrap! (map-get? loan-offers offer-id) ERR_OFFER_NOT_FOUND))
    (borrow-key {borrower: tx-sender, offer-id: offer-id})
  )
    (asserts! (get active lender-account) ERR_LENDER_NOT_FOUND)
    (asserts! (get available offer) ERR_OFFER_NOT_FOUND)
    (asserts! (is-none (map-get? borrow-records borrow-key)) ERR_ALREADY_BORROWED)
    (asserts! (>= (get collateral-amount offer) (get interest-rate offer)) ERR_INSUFFICIENT_FUNDS)
    (asserts! (check-asset-match (get asset-type offer) (get asset-types lender-account)) ERR_INVALID_PARAMS)
    
    (let (
      (loan-amount (get interest-rate offer))
      (protocol-fee (/ (* loan-amount (var-get protocol-fee-percent)) u100))
      (lender-interest (- loan-amount protocol-fee))
    )
      (map-set borrow-records borrow-key {timestamp: u0, repaid: true})
      
      (map-set loan-offers offer-id (merge offer {
        collateral-amount: (- (get collateral-amount offer) loan-amount),
        total-borrowers: (+ (get total-borrowers offer) u1)
      }))
      
      (map-set lender-accounts tx-sender (merge lender-account {
        interest-earned: (+ (get interest-earned lender-account) lender-interest),
        loan-count: (+ (get loan-count lender-account) u1)
      }))
      
      (var-set protocol-treasury (+ (var-get protocol-treasury) protocol-fee))
      
      (ok lender-interest))))

(define-public (withdraw-interest)
  (let ((lender-account (unwrap! (map-get? lender-accounts tx-sender) ERR_LENDER_NOT_FOUND)))
    (let ((interest (get interest-earned lender-account)))
      (asserts! (> interest u0) ERR_INSUFFICIENT_FUNDS)
      
      (try! (as-contract (stx-transfer? interest tx-sender tx-sender)))
      
      (map-set lender-accounts tx-sender (merge lender-account {
        interest-earned: u0,
        last-withdrawal: u0
      }))
      
      (ok interest))))

(define-public (withdraw-protocol-treasury)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (let ((amount (var-get protocol-treasury)))
      (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
      
      (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
      
      (var-set protocol-treasury u0)
      
      (ok amount))))

;; Helper functions
(define-private (is-valid-asset-type (asset-type uint))
  (is-some (map-get? collateral-types asset-type)))

(define-private (count-valid-asset-types (asset-types (list 10 uint)))
  (+ 
    (if (and (> (len asset-types) u0) (is-valid-asset-type (unwrap-panic (element-at asset-types u0)))) u1 u0)
    (if (and (> (len asset-types) u1) (is-valid-asset-type (unwrap-panic (element-at asset-types u1)))) u1 u0)
    (if (and (> (len asset-types) u2) (is-valid-asset-type (unwrap-panic (element-at asset-types u2)))) u1 u0)
    (if (and (> (len asset-types) u3) (is-valid-asset-type (unwrap-panic (element-at asset-types u3)))) u1 u0)
    (if (and (> (len asset-types) u4) (is-valid-asset-type (unwrap-panic (element-at asset-types u4)))) u1 u0)
    (if (and (> (len asset-types) u5) (is-valid-asset-type (unwrap-panic (element-at asset-types u5)))) u1 u0)
    (if (and (> (len asset-types) u6) (is-valid-asset-type (unwrap-panic (element-at asset-types u6)))) u1 u0)
    (if (and (> (len asset-types) u7) (is-valid-asset-type (unwrap-panic (element-at asset-types u7)))) u1 u0)
    (if (and (> (len asset-types) u8) (is-valid-asset-type (unwrap-panic (element-at asset-types u8)))) u1 u0)
    (if (and (> (len asset-types) u9) (is-valid-asset-type (unwrap-panic (element-at asset-types u9)))) u1 u0)
  ))

(define-private (validate-asset-types (asset-types (list 10 uint)))
  (let ((types-len (len asset-types)))
    (and 
      (> types-len u0)
      (&lt;= types-len u10)
      (is-eq types-len (count-valid-asset-types asset-types)))))

;; Read-only functions
(define-read-only (get-lender-account (lender principal))
  (map-get? lender-accounts lender))

(define-read-only (get-offer (offer-id uint))
  (map-get? loan-offers offer-id))

(define-read-only (get-asset-type (asset-id uint))
  (map-get? collateral-types asset-id))

(define-read-only (get-protocol-fee)
  (var-get protocol-fee-percent))

(define-read-only (get-protocol-treasury)
  (var-get protocol-treasury))

(define-read-only (get-borrow-record (borrower principal) (offer-id uint))
  (map-get? borrow-records {borrower: borrower, offer-id: offer-id}))
