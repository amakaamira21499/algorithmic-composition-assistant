(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PARAMETERS (err u101))
(define-constant ERR-MODEL-NOT-FOUND (err u102))
(define-constant ERR-INVALID-MODEL-STATE (err u103))

;; Data Variables
(define-data-var model-version uint u1)
(define-data-var generation-count uint u0)
(define-data-var model-active bool true)

;; Data Maps
(define-map models 
    uint 
    {
        version: uint,
        parameters: (string-ascii 100),
        created-at: uint,
        created-by: principal
    }
)

(define-map compositions 
    uint 
    {
        melody: (string-ascii 1000),
        harmony: (string-ascii 1000),
        creator: principal,
        timestamp: uint,
        model-version: uint
    }
)

(define-map user-preferences
    principal
    {
        style: (string-ascii 50),
        complexity: uint,
        last-updated: uint
    }
)

;; Helper Functions

(define-private (get-digit-char (digit uint))
    (unwrap-panic (element-at 
        (list "0" "1" "2" "3" "4" "5" "6" "7" "8" "9")
        digit))
)

;; Convert uint to string (simplified version for numbers 0-99)
(define-private (uint-to-string-simple (value uint))
    (if (<= value u9)
        (get-digit-char value)
        (concat 
            (get-digit-char (/ value u10))
            (get-digit-char (mod value u10)))
    )
)

;; Generate a new musical composition
(define-public (generate-composition (style (string-ascii 50)) (complexity uint))
    (let
        (
            (user-principal tx-sender)
            (current-time burn-block-height)
            (composition-id (+ (var-get generation-count) u1))
        )
        (asserts! (var-get model-active) ERR-INVALID-MODEL-STATE)
        (asserts! (and (>= complexity u1) (<= complexity u10)) ERR-INVALID-PARAMETERS)
        
        ;; Update user preferences
        (map-set user-preferences
            user-principal
            {
                style: style,
                complexity: complexity,
                last-updated: current-time
            }
        )
        
        ;; Generate composition
        (map-set compositions
            composition-id
            {
                melody: (concat style (uint-to-string-simple complexity)),
                harmony: (concat "harmony_" style),
                creator: user-principal,
                timestamp: current-time,
                model-version: (var-get model-version)
            }
        )
        
        ;; Increment generation count
        (var-set generation-count composition-id)
        (ok composition-id)
    )
)

;; Get composition details
(define-public (get-composition (composition-id uint))
    (match (map-get? compositions composition-id)
        composition (ok composition)
        ERR-MODEL-NOT-FOUND
    )
)

;; Update user musical preferences
(define-public (update-preferences (style (string-ascii 50)) (complexity uint))
    (begin
        (asserts! (and (>= complexity u1) (<= complexity u10)) ERR-INVALID-PARAMETERS)
        (ok (map-set user-preferences
            tx-sender
            {
                style: style,
                complexity: complexity,
                last-updated: burn-block-height
            }
        ))
    )
)

;; Update model version (only contract owner)
(define-public (update-model-version (new-version uint) (parameters (string-ascii 100)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (var-set model-version new-version)
        (map-set models
            new-version
            {
                version: new-version,
                parameters: parameters,
                created-at: burn-block-height,
                created-by: tx-sender
            }
        )
        (ok new-version)
    )
)

;; Toggle model active status (only contract owner)
(define-public (toggle-model-status)
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (var-set model-active (not (var-get model-active))))
    )
)

;; Get current model version
(define-read-only (get-current-version)
    (ok (var-get model-version))
)

;; Get user preferences
(define-read-only (get-user-preferences (user principal))
    (match (map-get? user-preferences user)
        preferences (ok preferences)
        ERR-MODEL-NOT-FOUND
    )
)

;; Get total number of generated compositions
(define-read-only (get-generation-count)
    (ok (var-get generation-count))
)

;; Get model details
(define-read-only (get-model-details (version uint))
    (match (map-get? models version)
        model (ok model)
        ERR-MODEL-NOT-FOUND
    )
)
