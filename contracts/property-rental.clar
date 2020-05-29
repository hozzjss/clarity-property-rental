;; Property token
(define-non-fungible-token property (buff 50))

;; Contract parties
(define-constant renter 'ST4FXHP5KEGYRQWVJ68KHB44W6645KJBCD8G0V0E)
(define-constant owner 'ST1JX27D915SK2W2YF8WVKSV4S39ZMEFHWA45NQ59)

(define-constant property-rental-contract (as-contract tx-sender))

;; Different types of property types
(define-constant electronics u1)
(define-constant properties u2)
(define-constant other u3)



(define-constant is-not-a-party 1)
(define-constant transfer-failed 2)
(define-constant is-not-allowed-for-renter 3)
(define-constant is-not-allowed-for-owner 4)
(define-constant is-not-allowed-for-anyone 5)

;; Property constant details
(define-constant name "Hozz's computer")
(define-constant id u1)
(define-constant type electronics)
;; 15 days of grace period till renter pays rent
;; after that, it would be considered breach of contract
;; except if owner decides to extend that grace periid
(define-data-var grace-period uint u15)


;; contract monetary details
;; both renter and owner can negotiate these
;; through negotiate
(define-data-var rent uint u100)
(define-data-var deposit uint u100)

;; contract would be valid for 12 months initially
(define-data-var contract-duration uint u12)

;; this would hold the time the contract was signed
(define-data-var contract-in-effect-since uint u0)

;; Contract can be signed once and only once
;; then it can be renewed or expired
(define-data-var is-contract-signed bool false)
(define-data-var is-contract-valid bool true)

;; this represents a signature of both renter and owner
;; if one of them renegotiated after the other accepted
;; these signatures would then be nullified
(define-data-var owner-accepted-terms bool false)
(define-data-var renter-accepted-terms bool false)

;; Contract cancellation requests here
(define-data-var owner-requested-cancellation bool false)
(define-data-var renter-requested-cancellation bool false)


;; Rent managemnet storage
;; This is the time of the next rent-payment
;; it would be extended to another month 
;; if the renter payed the rent 
(define-map latest-unpaid-month ((index uint)) ((month uint) (year uint)))
;; month and year are required for cross year rents
;; Paid is for renter whether they have paid or not
;; and withdrawn is for owner whether they have withdrawn rent or not
(define-map paid-months ((month uint) (year uint)) ((paid bool) (withdrawn bool)))



;; Contract states

;; this should indicate if the contract is in effect
;; and has not been breached
(define-private (is-contract-in-effect) 
  (and 
  (var-get is-contract-valid)
  (var-get is-contract-signed)
  (> (+ (var-get contract-in-effect-since) (* (var-get contract-duration) u60 u60 u24 u30)) (get-current-time))))


;; Rental details getter
(define-public (get-details) 
  (ok 
    {
      name: name, 
      type: type, 
      id: id,
      owner: owner, 
      rent: (var-get rent), 
      deposit: (var-get deposit),
      contract-duration: (var-get contract-duration)
    }))


;; Contract Negotiations
;; Owner and renter can negotiate terms through this function
;; only if contract is valid and not in effect
;; this means that only contracts that have not been
;; deliberately expired or have not been signed yet
;; only in negotiations will terms be changeable
(define-public (negotiate-rent (new-rent uint) (new-contract-duration uint) (new-deposit uint)) 
  (if 
    (can-negotiate)
      (begin 
          (reset-terms-agreements)
          (ok 
            (begin 
                (var-set rent new-rent)
                (var-set deposit new-deposit)
                (var-set contract-duration new-contract-duration)
                )))
    (err is-not-a-party)))




;; Both renter and owner can accept terms
;; if contract is valid and is not yet in effect
(define-public (accept-terms) 
  (if (can-negotiate)
    (begin 
        (if (is-owner) 
          (var-set owner-accepted-terms true) 
          (var-set renter-accepted-terms true))
          (if (check-parties-agreements) 
              (ok (seal-contract)) 
              (ok false)))
    (err is-not-a-party)))

;; util
(define-private (is-owner) (is-eq tx-sender owner))

(define-private (is-renter) (is-eq tx-sender renter))
(define-private (can-negotiate) 
  (and 
    (var-get is-contract-valid)
    (not (is-contract-in-effect))
    (is-a-party)))

(define-private (is-a-party) (or (is-renter) (is-owner)))



(define-private (reset-terms-agreements) 
  (begin
    (var-set owner-accepted-terms false)
    (var-set renter-accepted-terms false)))

(define-private (check-parties-agreements) 
  (and 
    (var-get renter-accepted-terms) 
    (var-get owner-accepted-terms)))


;; Contract seal
;; This acts as a sealing function
;; After this function is executed successfully
;; contract would be valid until the end of the duration
;; or until the renter breaches contract
;; this function is only called when both parties 
;; accept the negotiated contract terms

(define-private (set-last-unpaid-month (month uint) (year uint)) 
  (map-set latest-unpaid-month ((index u0)) ((month month) (year year))))

(define-private (seal-contract) 
  (begin
    (let 
      ((deposit-transfer-successful (transfer-deposit)) 
      (rent-transfer-successful (transfer-first-month-rent)))
      (if (and deposit-transfer-successful rent-transfer-successful) 
          (begin
            (var-set contract-in-effect-since (get-current-time))
            (var-set is-contract-signed true)
            (reset-terms-agreements)
            (set-last-unpaid-month (get-next-month) (get-next-month-year (get-current-month)))
            ;; until the end of the contract 
            ;; as long as the contract is 
            ;; the property is owned by the contract
            (nft-transfer? property name owner property-rental-contract) true) false))))
;;; Payment handling
(define-private (transfer-funds (amount uint) (recipient principal) (sender principal))
  (unwrap-panic (stx-transfer? amount recipient sender)))

;;; Payment handlers
;; deposit does not go to either party
;; rather it stays in the contract
(define-private (transfer-deposit)
  (transfer-funds (var-get deposit) property-rental-contract renter))

;; First month would be transferred directly to owner
(define-private (transfer-first-month-rent)
  (transfer-funds (var-get rent) owner renter))


;; Rent management

;; A renter can deposit rent for the next month
;; Money is stored in the contract until the owner requests them
;; The money would be frozen until the beginning of the next month
(define-public (deposit-rent)
  (if 
    (and 
      (is-contract-in-effect)
      (is-renter))
      (begin
        (let 
          ((transferred-rent (handle-deposit-rent)))
          (if transferred-rent 
              (if
                (not (is-current-month-paid))
                (ok (set-current-month-paid true))
                (ok (set-next-month-paid true)))
            (err transfer-failed))))
      (err is-not-allowed-for-owner)))

(define-private (set-month-payment (month uint) (year uint) (paid bool) (withdrawn bool)) 
  (map-set paid-months ((month month) (year year)) ((paid paid) (withdrawn withdrawn))))

(define-private (set-current-month-paid (paid bool))
  (set-month-payment (get-current-month) (get-current-year) paid false))

(define-private (set-next-month-paid (paid bool)) 
  (set-month-payment (get-next-month) (get-next-month-year (get-current-month)) paid false))

(define-private (is-month-paid (month uint) (year uint)) 
  (default-to false (get paid (map-get? paid-months ((month (get-next-month)) (year year))))))

(define-private (is-month-withdrawn (month uint) (year uint)) 
  (default-to false (get withdrawn (map-get? paid-months ((month (get-next-month)) (year year))))))

(define-private (is-next-month-paid) 
  (is-month-paid (get-next-month) (get-next-month-year (get-current-month))))

(define-private (is-current-month-paid)
  (is-month-paid (get-current-month) (get-current-year)))


(define-private (get-next-month) 
  (let ((current-month (get-current-month)))
    (if (< current-month u12) 
      (+ current-month u1)
    u1)))


;; a renter can refund next month rent deposit
;; before the beginning of the month
(define-public (refund-next-month-funds) 
    (if 
    (and 
      (is-contract-in-effect)
      (is-renter))
      (if 
        (and 
          (is-next-month-paid)
          (is-current-month-paid))
        (let 
          ((transferred-rent (handle-withdraw-rent)))
          (if transferred-rent
            (ok (set-next-month-paid false))
            (err transfer-failed)))
        (err transfer-failed))
      (err is-not-allowed-for-owner)))

;; A method for owner to withdraw their rent funds
(define-public (withdraw-month-rent (month uint) (year uint)) 
  (if (and 
    (not (and (is-eq (get-current-month) month) (is-eq (get-current-year) year)))
    (is-month-paid month year)
    (not (is-month-withdrawn month year)))
  (let ((transferred (handle-withdraw-rent)))
    (if transferred 
      (ok (set-month-withdrawn month year))
      (err transfer-failed)))
  (err transfer-failed)))

(define-private (set-month-withdrawn (month uint) (year uint)) 
  (set-month-payment month year true true))

;; it's a simple operation but I rather keeping it this way
;; shall the need rise to make complex stuff or something
;; Developer insecurity I guess xD
(define-private (get-next-month-year (current-month uint))
  (if (< current-month u12)
    (get-current-year)
    (+ u1 (get-current-year))))


;; Rent will always be held by the contract until owner requests
;; a withdrawal of rent money
(define-private (handle-deposit-rent)
  (transfer-funds (var-get rent) property-rental-contract renter))

(define-private (handle-withdraw-rent) 
  (transfer-funds (var-get rent) tx-sender property-rental-contract))


;;; Contract validation
;; What would constitute a breach of contract
;; would be only if renter fails to pay month's rent
;; before `grace-peried` passes
(define-public (is-renter-in-breach-of-contract)
  (ok (is-past-grace-period)))

(define-public (extend-grace-period (extension uint))
  (if (is-owner)
    (ok 
      (var-set grace-period 
        (+ (var-get grace-period) extension)))
    (err is-not-allowed-for-renter)))

;; Only for good merciful landlords
;; Thank you for your humanity
;; unlike this unforgiving contract
;; The renter might waive the rent of any month whatsoever
(define-public (waive-rent (month uint) (year uint)) 
  (if (is-a-party)
    (if (is-owner)
      (if (is-contract-in-effect)
        (ok (set-month-withdrawn month year))
      (err is-not-allowed-for-anyone))
    (err is-not-allowed-for-renter))
  (err is-not-a-party)))


(define-private (is-past-grace-period) 
  (and 
  (not (is-current-month-paid))
  (> (get-current-day) (var-get grace-period))))

;; This contract knows no mercy
(define-public (end-contract-on-grounds-of-breach-of-contract)
  (if (is-owner) 
    (if (is-past-grace-period)
      (ok (handle-end-contract owner))
      (err transfer-failed))
    (err is-not-allowed-for-renter)))


;; if one of the parties requests contract to be 
;; expired after it'
(define-public (expire-contract)
  (if (is-a-party)
    (if (not (is-contract-in-effect))
      (ok (handle-end-contract renter))
      (err is-not-allowed-for-anyone))
    (err is-not-a-party)))

;; if neither party expires contract
;; no operation would be permitted
;; until renegotiation starts again


(define-private (handle-end-contract (deposit-receiver principal)) 
  (begin 
    (nft-transfer? property name property-rental-contract owner)
    (var-set is-contract-valid false)
    (transfer-funds (var-get deposit) property-rental-contract deposit-receiver)
    ))


;; Contract cancellation
;; In case for example the need of both people to drop this contract
;; and create another one or they're just not into the contract any more
;; any tokens would be destroyed

(define-public (request-cancellation) 
  (set-cancellation-requested true))
(define-public (abort-cancellation) 
  (set-cancellation-requested false))


(define-private (set-cancellation-requested (is-requested bool))
  (if (is-a-party)
    (if (is-contract-in-effect)
      (if (is-both-submitted-cancellation-requests)
        ;; if both agree to the cancellation
        (ok (handle-end-contract renter))
        (if (is-owner)
          (ok (var-set owner-requested-cancellation is-requested))
          (ok (var-set renter-requested-cancellation is-requested))))
      (err is-not-allowed-for-anyone))
    (err is-not-a-party)))


(define-private (is-both-submitted-cancellation-requests) 
  (and 
    (var-get owner-requested-cancellation)
    (var-get owner-requested-cancellation)))



;; Time utilities
;; Currently this is the only way to get time
;; it is okay and is not bad at all
;; u1590626084 this is the timestamp I use for development
;; as unit tests cannot access any blocks
(define-private (get-current-time) 
  (default-to u1590626084 (get-block-info? time block-height)))

(define-private (get-current-year) 
  (+ u1970 (get-years-since-1970)))

(define-private (get-current-day) 
  (let 
    (
      (seconds-after-start-of-month 
        (- 
          (get-current-time)
          (get-years-seconds-since-1970-till-jan-first)
        ;; subtract one other wise we'd go a month back
          (* (- (get-current-month) u1) u30 u60 u60 u24))))
    ;; Clarity floors floating points so this will fix it 
    (seconds-to-days seconds-after-start-of-month)))

(define-private (get-current-month) 
  (let 
    ((seconds-after-start-of-year 
      (- (get-current-time) (get-years-seconds-since-1970-till-jan-first))))
    ;; Clarity floors floating points so this will fix it 
    (+ (/ (seconds-to-days seconds-after-start-of-year) u30) u1)))

(define-private (years-to-seconds (years uint)) 
  (* (days-to-seconds years) u365))


(define-private (days-to-seconds (days uint)) 
  (* days u24 u60 u60))

(define-private (seconds-to-days (days uint)) 
  (/ days u24 u60 u60))
  
(define-private (get-years-since-1970) 
  (/ (seconds-to-days (get-current-time)) u365))

;; since we don't have much support for time control
;; I have made this monstrosity
(define-private (get-years-seconds-since-1970-till-jan-first)
  (let 
    (
      ;; first get the years since 1970
      ;; for example in 2020 it would be 50 years
      (years-since-1970 (get-years-since-1970))

      ;; then we oughta not forget about leap year days
      ;; as we don't have floating point this is better
      (leap-year-days (/ (get-years-since-1970) u4)))

      (let
        ;; then get the seconds from Jan 1970 till 365 * years later
        ((years-seconds (* (days-to-seconds years-since-1970) u365))
        ;; and their leap days seconds
        (leap-year-days-seconds (* (days-to-seconds leap-year-days))))
        ;; add up the years and leap years' days' seconds
        ;; and we're golden!
        (+ years-seconds leap-year-days-seconds))))


;; this should be the property
(nft-mint? property name owner)

