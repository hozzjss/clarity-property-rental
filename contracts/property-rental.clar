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



(define-constant negotiator-is-not-a-party 1)

;; Property constant details
(define-constant name "Hozz's computer")
(define-constant id u1)
(define-constant type electronics)


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



;; Owner and renter can negotiate through this function
(define-public (negotiate-rent (new-rent uint) (new-contract-duration uint) (new-deposit uint)) 
  (if 
    (and 
      (or (is-renter) (is-owner)))
      (begin 
          (reset-terms-agreements)
          (ok 
            (begin 
                (var-set rent new-rent)
                (var-set deposit new-deposit)
                (var-set contract-duration new-contract-duration)
                )))
    (err negotiator-is-not-a-party)))



(define-public (accept-terms) 
  (if (or (is-renter) (is-owner))
    (begin 
        (if (is-owner) 
          (var-set owner-accepted-terms true) 
          (var-set renter-accepted-terms true))
        (let ((isAccepted (check-parties-agreements))) 
          (if isAccepted 
              (ok (seal-contract)) 
              (ok false)))
    )
    (err negotiator-is-not-a-party)))

;; Private utility functions

(define-private (is-owner) (is-eq tx-sender owner))

(define-private (is-renter) (is-eq tx-sender renter))
(define-private (can-negotiate) 
  (and 
    (not (is-contract-in-effect))
    (or (is-renter) (is-owner))))



(define-private (reset-terms-agreements) 
  (begin
    (var-set owner-accepted-terms false)
    (var-set renter-accepted-terms false)))

(define-private (check-parties-agreements) 
  (and 
    (var-get renter-accepted-terms) 
    (var-get owner-accepted-terms)))


(define-private (transfer-funds (amount uint) (recipient principal) (sender principal))
  (match 
    (stx-transfer? amount recipient sender) 
        transferred true
        failed false))


;; deposit does not go to either party
;; rather it stays in the contract
(define-private (transfer-deposit)
  (transfer-funds (var-get deposit) property-rental-contract renter))

(define-private (transfer-rent)
  (transfer-funds (var-get rent) owner renter))


(define-private (get-current-time) 
  (default-to u0 (get-block-info? time block-height)))
      



(define-private (seal-contract) 
  (begin
    (let 
        ((deposit-transfer-successful (transfer-deposit)) 
        (rent-transfer-successful (transfer-rent)))
    (if (and deposit-transfer-successful rent-transfer-successful) 
        (begin
          (var-set contract-in-effect-since (get-current-time))
          ;; until the end of the contract 
          ;; the property is owned by the contract
          (nft-transfer? property name owner property-rental-contract)
          true)
        false))))

;; this should be the property
(nft-mint? property name owner)
