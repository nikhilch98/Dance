package qr

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"nachna/config"
	"nachna/core"
	"nachna/models/mongodb"
	"sync"
	"time"
)

type QRData struct {
	OrderID         string  `json:"order_id"`
	UserID          string  `json:"user_id"`
	WorkshopUUID    string  `json:"workshop_uuid"`
	Amount          float64 `json:"amount"`
	Status          string  `json:"status"`
	GeneratedAt     int64   `json:"generated_at"`
	ExpiresAt       *int64  `json:"expires_at,omitempty"`
	VerificationKey string  `json:"verification_key"`
}

type QRServiceImpl struct {
	customImagePath string
	qrSize          int
}

var qrServiceInstance *QRServiceImpl
var qrServiceLock = &sync.Mutex{}
var activeQRGenerations = make(map[string]bool) // Track active QR generations to prevent duplicates
var activeQRLock = &sync.Mutex{}

func (QRServiceImpl) GetInstance() *QRServiceImpl {
	if qrServiceInstance == nil {
		qrServiceLock.Lock()
		defer qrServiceLock.Unlock()
		if qrServiceInstance == nil {
			// Get custom image path from config
			customImagePath := ""
			if len(config.Config.WebBasedStudios) > 0 {
				// Use first studio's config or add a dedicated QR config
				customImagePath = "static/assets/qr/custom_logo.png" // Default path
			}

			qrServiceInstance = &QRServiceImpl{
				customImagePath: customImagePath,
				qrSize:          256, // Default QR size
			}
		}
	}
	return qrServiceInstance
}

// GenerateVerificationKey generates a unique verification key for the QR
func (q *QRServiceImpl) GenerateVerificationKey() (string, *core.NachnaException) {
	bytes := make([]byte, 32)
	_, err := rand.Read(bytes)
	if err != nil {
		return "", &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to generate verification key",
			LogMessage:   err.Error(),
		}
	}
	return base64.URLEncoding.EncodeToString(bytes), nil
}

// GenerateOrderQR generates a QR code for an order
func (q *QRServiceImpl) GenerateOrderQR(order *mongodb.Order) (string, *core.NachnaException) {
	// Check if QR generation is already in progress for this order
	activeQRLock.Lock()
	if activeQRGenerations[order.OrderID] {
		activeQRLock.Unlock()
		return "", &core.NachnaException{
			StatusCode:   409,
			ErrorMessage: "QR code generation already in progress for this order",
		}
	}
	activeQRGenerations[order.OrderID] = true
	activeQRLock.Unlock()

	// Ensure we clean up the active generation tracking
	defer func() {
		activeQRLock.Lock()
		delete(activeQRGenerations, order.OrderID)
		activeQRLock.Unlock()
	}()

	// Generate verification key
	verificationKey, err := q.GenerateVerificationKey()
	if err != nil {
		return "", err
	}

	// Create QR data
	qrData := QRData{
		OrderID:         order.OrderID,
		UserID:          order.UserID,
		WorkshopUUID:    order.WorkshopUUID,
		Amount:          order.Amount,
		Status:          string(order.Status),
		GeneratedAt:     time.Now().Unix(),
		VerificationKey: verificationKey,
	}

	// Set expiration time (e.g., 30 days from generation)
	expiresAt := time.Now().AddDate(0, 0, 30).Unix()
	qrData.ExpiresAt = &expiresAt

	// Convert to JSON
	qrDataJSON, jsonErr := json.Marshal(qrData)
	if jsonErr != nil {
		return "", &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to marshal QR data",
			LogMessage:   jsonErr.Error(),
		}
	}

	// Encode as base64 for QR content
	qrContent := base64.StdEncoding.EncodeToString(qrDataJSON)

	// For now, return the base64 encoded string
	// In production, you would use a QR library like github.com/skip2/go-qrcode
	// to generate actual QR image with custom logo overlay

	return qrContent, nil
}

// ValidateQR validates a QR code and returns the order data
func (q *QRServiceImpl) ValidateQR(qrContent string) (*QRData, *core.NachnaException) {
	// Decode base64
	qrDataJSON, err := base64.StdEncoding.DecodeString(qrContent)
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid QR code format",
			LogMessage:   err.Error(),
		}
	}

	// Parse JSON
	var qrData QRData
	err = json.Unmarshal(qrDataJSON, &qrData)
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid QR code data",
			LogMessage:   err.Error(),
		}
	}

	// Check expiration
	if qrData.ExpiresAt != nil && time.Now().Unix() > *qrData.ExpiresAt {
		return nil, &core.NachnaException{
			StatusCode:   410,
			ErrorMessage: "QR code has expired",
		}
	}

	return &qrData, nil
}

// IsQRGenerationInProgress checks if QR generation is in progress for an order
func (q *QRServiceImpl) IsQRGenerationInProgress(orderID string) bool {
	activeQRLock.Lock()
	defer activeQRLock.Unlock()
	return activeQRGenerations[orderID]
}
