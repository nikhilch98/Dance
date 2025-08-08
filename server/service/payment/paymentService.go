package payment

import (
	"fmt"
	"nachna/core"
	"sync"
	"time"
)

type PaymentGatewayRequest struct {
	OrderID         string  `json:"order_id"`
	Amount          float64 `json:"amount"`
	Currency        string  `json:"currency"`
	UserEmail       string  `json:"user_email"`
	UserPhoneNumber string  `json:"user_phone_number"`
	IdempotencyKey  string  `json:"idempotency_key"`
	Description     string  `json:"description"`
}

type PaymentGatewayResponse struct {
	PaymentLink string `json:"payment_link"`
	Status      string `json:"status"`
	GatewayID   string `json:"gateway_id"`
}

type PaymentServiceImpl struct {
	gatewayBaseURL string
	apiKey         string
}

var paymentServiceInstance *PaymentServiceImpl
var paymentServiceLock = &sync.Mutex{}

func (PaymentServiceImpl) GetInstance() *PaymentServiceImpl {
	if paymentServiceInstance == nil {
		paymentServiceLock.Lock()
		defer paymentServiceLock.Unlock()
		if paymentServiceInstance == nil {
			paymentServiceInstance = &PaymentServiceImpl{
				gatewayBaseURL: "https://api.razorpay.com/v1", // Default to Razorpay for now
				apiKey:         "test_api_key",                // This should come from config
			}
		}
	}
	return paymentServiceInstance
}

// CreatePaymentLink creates a payment link with the external gateway
func (p *PaymentServiceImpl) CreatePaymentLink(request *PaymentGatewayRequest) (*PaymentGatewayResponse, *core.NachnaException) {
	// For now, this is a mock implementation
	// In production, this would make HTTP calls to actual payment gateways like Razorpay, PhonePe, etc.

	// Generate a mock payment link
	mockPaymentLink := fmt.Sprintf("https://payments.razorpay.com/pl_%s", request.IdempotencyKey)

	// Simulate some processing time
	time.Sleep(100 * time.Millisecond)

	response := &PaymentGatewayResponse{
		PaymentLink: mockPaymentLink,
		Status:      "created",
		GatewayID:   fmt.Sprintf("gw_%s", request.IdempotencyKey),
	}

	return response, nil
}

// ValidateWebhookSignature validates the webhook signature from payment gateway
func (p *PaymentServiceImpl) ValidateWebhookSignature(signature string, payload []byte) bool {
	// For now, return true for testing
	// In production, this would validate the actual signature from the gateway
	return true
}

// GetSupportedGateways returns list of supported payment gateways
func (p *PaymentServiceImpl) GetSupportedGateways() []string {
	return []string{"razorpay", "phonepe", "paytm", "stripe"}
}
