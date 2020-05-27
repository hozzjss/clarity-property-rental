;; Property token
(define-non-fungible-token property (buff 50))

;; Contract parties
(define-constant renter 'ST2H4YT31W0XX5VNHG95KAE7AWDJ2V5JN047CBBH)
(define-constant owner 'ST1TXPQCP005M76WZN7KXJ83V289WP098GKG6F2VS)

;; Different types of properties
(define-constant electronics u1)
(define-constant properties u2)
(define-constant other u3)



(define-constant negotiator-is-not-a-party 1)

;; Property constant details
(define-constant name "Hozz's computer")
(define-constant id u1)
(define-constant type electronics)


(define-data-var owner-accepted-terms bool false)
(define-data-var renter-accepted-terms bool false)
;; the contract would be for valid for 12 month
(define-data-var contract-duration uint u12)


(define-data-var rent uint u100)
(define-data-var deposit uint u100)


(nft-mint? property name owner)


(define-public (get-owner) (ok owner))

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

(define-public (negotiate-rent (new-rent-price uint) (new-contract-duration uint) (new-deposit uint)) 
   (begin 
   (reset-terms-agreements) 
   (if 
      (or (is-renter) (is-owner))
      (ok 
         (begin 
            (var-set rent new-rent-price)
            (var-set deposit new-deposit)
            (var-set contract-duration new-contract-duration)
            ))
      (err negotiator-is-not-a-party))))

(define-private (is-owner) (is-eq tx-sender owner))
(define-private (is-renter) (is-eq tx-sender renter))


(define-public (accept-terms) 
   (if (or (is-renter) (is-owner))
      (begin 
         (if (is-owner) 
            (var-set owner-accepted-terms true) 
            (var-set renter-accepted-terms true))
         (let ((isAccepted (check-parties-agreements))) 
            (if (not isAccepted) 
               (ok 1) 
               (ok 2)))
      )
      (err negotiator-is-not-a-party)))


;; (define-private rent-expired 
;;    ()))

   
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

(define-private (transfer-deposit)
   (transfer-funds (var-get deposit) owner renter))

