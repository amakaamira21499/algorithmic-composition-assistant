(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-PARAMETERS (err u201))
(define-constant ERR-ORCHESTRATION-NOT-FOUND (err u202))
(define-constant ERR-INVALID-INSTRUMENT (err u203))

;; Data Variables
(define-data-var orchestration-count uint u0)
(define-data-var service-active bool true)

;; Data Maps
(define-map instrument-registry
    (string-ascii 50)  ;; instrument ID
    {
        name: (string-ascii 50),
        family: (string-ascii 50),
        range-low: (string-ascii 10),
        range-high: (string-ascii 10),
        properties: (string-ascii 200)
    }
)

(define-map orchestrations
    uint  ;; orchestration ID
    {
        composition-id: uint,
        instruments: (list 20 (string-ascii 50)),
        voicing: (string-ascii 1000),
        creator: principal,
        timestamp: uint,
        status: (string-ascii 20)
    }
)

(define-map ensemble-types
    (string-ascii 50)  ;; ensemble type
    {
        name: (string-ascii 50),
        size: uint,
        description: (string-ascii 200)
    }
)

(define-map instrument-compatibilities
    {
        instrument1: (string-ascii 50),
        instrument2: (string-ascii 50)
    }
    {
        compatibility-score: uint,
        notes: (string-ascii 100)
    }
)

;; Private Functions

;; Check if an instrument is registered
(define-private (check-registered-instrument (instrument-id (string-ascii 50)) (valid bool))
    (match (map-get? instrument-registry instrument-id)
        instrument-data valid
        false
    )
)

;; Generate basic voicing for instruments
(define-private (make-voicing (instrument-list (list 20 (string-ascii 50))))
    (concat "voicing_for_" (unwrap-panic (element-at instrument-list u0)))
)

;; Public Functions

;; Create a new orchestration recommendation
(define-public (create-orchestration (composition-id uint) 
                                   (ensemble-type (string-ascii 50))
                                   (instrument-list (list 20 (string-ascii 50))))
    (let
        (
            (user-principal tx-sender)
            (current-time burn-block-height)
            (orchestration-id (+ (var-get orchestration-count) u1))
        )
        (asserts! (var-get service-active) ERR-NOT-AUTHORIZED)
        (asserts! (>= (len instrument-list) u1) ERR-INVALID-PARAMETERS)
        
        ;; Validate instruments
        (asserts! (fold check-registered-instrument instrument-list true) ERR-INVALID-INSTRUMENT)
        
        ;; Create orchestration
        (map-set orchestrations
            orchestration-id
            {
                composition-id: composition-id,
                instruments: instrument-list,
                voicing: (make-voicing instrument-list),
                creator: user-principal,
                timestamp: current-time,
                status: "pending"
            }
        )
        
        ;; Increment orchestration count
        (var-set orchestration-count orchestration-id)
        (ok orchestration-id)
    )
)

;; Get orchestration details
(define-public (get-orchestration (orchestration-id uint))
    (match (map-get? orchestrations orchestration-id)
        orchestration (ok orchestration)
        ERR-ORCHESTRATION-NOT-FOUND
    )
)

;; Update orchestration status
(define-public (update-orchestration-status (orchestration-id uint) 
                                          (new-status (string-ascii 20)))
    (let
        (
            (orchestration (unwrap! (map-get? orchestrations orchestration-id)
                ERR-ORCHESTRATION-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set orchestrations
            orchestration-id
            (merge orchestration { status: new-status })))
    )
)

;; Register new instrument
(define-public (register-instrument 
    (id (string-ascii 50))
    (name (string-ascii 50))
    (family (string-ascii 50))
    (range-low (string-ascii 10))
    (range-high (string-ascii 10))
    (properties (string-ascii 200)))
    
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set instrument-registry
            id
            {
                name: name,
                family: family,
                range-low: range-low,
                range-high: range-high,
                properties: properties
            }
        ))
    )
)

;; Register ensemble type
(define-public (register-ensemble-type
    (type-id (string-ascii 50))
    (name (string-ascii 50))
    (size uint)
    (description (string-ascii 200)))
    
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set ensemble-types
            type-id
            {
                name: name,
                size: size,
                description: description
            }
        ))
    )
)

;; Set instrument compatibility
(define-public (set-instrument-compatibility
    (instrument1 (string-ascii 50))
    (instrument2 (string-ascii 50))
    (score uint)
    (notes (string-ascii 100)))
    
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (and (>= score u0) (<= score u100)) ERR-INVALID-PARAMETERS)
        (ok (map-set instrument-compatibilities
            { instrument1: instrument1, instrument2: instrument2 }
            {
                compatibility-score: score,
                notes: notes
            }
        ))
    )
)

;; Read-only Functions

;; Get instrument details
(define-read-only (get-instrument (id (string-ascii 50)))
    (match (map-get? instrument-registry id)
        instrument (ok instrument)
        ERR-ORCHESTRATION-NOT-FOUND
    )
)

;; Get ensemble type details
(define-read-only (get-ensemble-type (type-id (string-ascii 50)))
    (match (map-get? ensemble-types type-id)
        ensemble-type (ok ensemble-type)
        ERR-ORCHESTRATION-NOT-FOUND
    )
)

;; Get instrument compatibility
(define-read-only (get-compatibility
    (instrument1 (string-ascii 50))
    (instrument2 (string-ascii 50)))
    
    (match (map-get? instrument-compatibilities
        { instrument1: instrument1, instrument2: instrument2 })
        compatibility (ok compatibility)
        ERR-ORCHESTRATION-NOT-FOUND
    )
)

;; Get total number of orchestrations
(define-read-only (get-orchestration-count)
    (ok (var-get orchestration-count))
)
