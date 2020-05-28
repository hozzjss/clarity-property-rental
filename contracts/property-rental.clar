;; Property token
(define-non-fungible-token property (buff 50))

;; Contract parties
(define-constant renter 'ST1P65RPJD6Z12PHFZ0SSMAGGFTP05P5Q98XFH565)
(define-constant property-rental-contract 'ST1P65RPJD6Z12PHFZ0SSMAGGFTP05P5Q98XFH565.property-rental)
(define-constant owner 'ST2VN90YREJPP7MPYSXYQ8RMGT2Q9VSAEJ1FH459T)

;; Different types of property types
(define-constant electronics u1)
(define-constant properties u2)
(define-constant other u3)



(define-constant is-not-a-party 1)
(define-constant transfer-failed 2)

;; Property constant details
(define-constant name "Hozz's computer")
(define-constant id u1)
(define-constant type electronics)
;; 15 days of grace period till renter pays rent
;; after that, it would be considered breach of contract
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

;; this represents a signature of both renter and owner
;; if one of them renegotiated after the other accepted
;; these signatures would then be nullified
(define-data-var owner-accepted-terms bool false)
(define-data-var renter-accepted-terms bool false)


;; Rent managemnet storage
;; This is the time of the next rent-payment
;; it would be extended to another month 
;; if the renter payed the rent 
(define-data-var next-rent-payment-time uint u0)
(define-map paid-months ((month uint) (year uint)) ((paid bool)))



;; Contract states

;; this should indicate if the contract is in effect
;; and has not been breached
(define-private (is-contract-in-effect) 
  (> 
    (var-get contract-in-effect-since) (get-current-time)))


;; Rental details getter
(define-read-only (get-details) 
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
;; Owner and renter can negotiate through this function
(define-public (negotiate-rent (new-rent uint) (new-contract-duration uint) (new-deposit uint)) 
  (if 
    (and 
      (is-a-party))
      (begin 
          (reset-terms-agreements)
          (ok 
            (begin 
                (var-set rent new-rent)
                (var-set deposit new-deposit)
                (var-set contract-duration new-contract-duration)
                )))
    (err is-not-a-party)))



(define-public (accept-terms) 
  (if (is-a-party)
    (begin 
        (if (is-owner) 
          (var-set owner-accepted-terms true) 
          (var-set renter-accepted-terms true))
        (let ((isAccepted (check-parties-agreements))) 
          (if isAccepted 
              (ok (seal-contract)) 
              (ok false)))
    )
    (err is-not-a-party)))


(define-private (is-owner) (is-eq tx-sender owner))

(define-private (is-renter) (is-eq tx-sender renter))
(define-private (can-negotiate) 
  (and 
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

;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;
;; Finished 
;; Negotiations 
;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;


;; Contract seal
;; This acts as a sealing function
;; After this function is executed successfully
;; contract would be valid until the end of the duration
;; or until the renter breaches contract
;; this function is only called when both parties 
;; accept the negotiated contract terms


(define-private (seal-contract) 
  (begin
    (let 
      ((deposit-transfer-successful (transfer-deposit)) 
      (rent-transfer-successful (transfer-first-month-rent)))
      (if (and deposit-transfer-successful rent-transfer-successful) 
          (begin
            (var-set contract-in-effect-since (get-current-time))
            ;; until the end of the contract 
            ;; as long as the contract is 
            ;; the property is owned by the contract
            (nft-transfer? property name owner property-rental-contract) true) false))))
;;; Payment handling
(define-private (transfer-funds (amount uint) (recipient principal) (sender principal))
  (match 
    (stx-transfer? amount recipient sender) 
        transferred true
        failed false))

;;; Payment handlers
;; deposit does not go to either party
;; rather it stays in the contract
(define-private (transfer-deposit)
  (transfer-funds (var-get deposit) property-rental-contract renter))

;; First month would be transferred directly to owner
(define-private (transfer-first-month-rent)
  (transfer-funds (var-get rent) owner renter))


;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;
;; Finished 
;; Contract seal 
;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;



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
                (ok (set-current-month-paid))
                (ok (set-next-month-paid)))
            (err transfer-failed))))
      (err is-not-a-party)))

(define-private (set-month-paid (month uint) (year uint)) 
  (map-set paid-months ((month month) (year year)) ((paid true))))

(define-private (set-current-month-paid)
  (set-month-paid (get-current-month) (get-current-year)))

(define-private (set-next-month-paid) 
  (set-month-paid (get-next-month) (get-next-year)))

(define-private (is-month-paid (month uint) (year uint)) 
  (default-to false (get paid (map-get? paid-months ((month (get-next-month)) (year (get-next-year)))))))

(define-private (is-next-month-paid) 
  (is-month-paid (get-next-month) (get-next-year)))

(define-private (is-current-month-paid)
  (is-month-paid (get-current-month) (get-current-year)))


(define-private (get-next-month) 
  (let ((current-month (get-current-month)))
    (if (< current-month u12) 
      (+ current-month u1)
    u1)))

;; it's a simple operation but I rather keeping it this way
;; shall the need rise to make complex stuff or something
;; Developer insecurity I guess xD
(define-private (get-next-year) (+ u1 (get-current-year)))


;; Rent will always be held by the contract until owner requests
;; a withdrawal of rent money
(define-private (handle-deposit-rent)
  (transfer-funds (var-get rent) property-rental-contract renter))




;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;
;; Finished 
;; Rent Management 
;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;



;; Time utilities
;; Currently this is the only way to get time
;; it is okay and is not bad at all
(define-private (get-current-time) 
  (default-to u1590626084 (get-block-info? time block-height)))

(define-private (get-current-year) 
  (+ u1970 (get-years-since-1970)))

(define-private (get-current-month) 
  (let 
    ((seconds-since-start-of-year 
      (- (get-current-time) (get-years-seconds-since-1970-till-jan-first))))
    ;; Clarity floors floating points so this will fix it 
    (+ (/ (seconds-to-days seconds-since-start-of-year) u30) u1)))

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
        (+ years-seconds leap-year-days-seconds)
        )))
;; this should be the property
(nft-mint? property name owner)

