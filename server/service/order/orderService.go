package order

import (
	"context"
	"crypto/rand"
	"fmt"
	"nachna/core"
	"nachna/database"
	"nachna/models/mongodb"
	"nachna/service/payment"
	"nachna/service/qr"
	"sync"
	"time"
)

type OrderServiceImpl struct {
	databaseImpl   *database.MongoDBDatabaseImpl
	paymentService *payment.PaymentServiceImpl
	qrService      *qr.QRServiceImpl
}

var orderServiceInstance *OrderServiceImpl
var orderServiceLock = &sync.Mutex{}

func (OrderServiceImpl) GetInstance(databaseImpl *database.MongoDBDatabaseImpl) *OrderServiceImpl {
	if orderServiceInstance == nil {
		orderServiceLock.Lock()
		defer orderServiceLock.Unlock()
		if orderServiceInstance == nil {
			orderServiceInstance = &OrderServiceImpl{
				databaseImpl:   databaseImpl,
				paymentService: payment.PaymentServiceImpl{}.GetInstance(),
				qrService:      qr.QRServiceImpl{}.GetInstance(),
			}
		}
	}
	return orderServiceInstance
}

// GenerateOrderID generates a unique order ID
func (o *OrderServiceImpl) GenerateOrderID() (string, *core.NachnaException) {
	timestamp := time.Now().Unix()
	randomBytes := make([]byte, 4)
	_, err := rand.Read(randomBytes)
	if err != nil {
		return "", &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to generate order ID",
			LogMessage:   err.Error(),
		}
	}

	orderID := fmt.Sprintf("order_%d_%x", timestamp, randomBytes)
	return orderID, nil
}

// GenerateIdempotencyKey generates a unique idempotency key
func (o *OrderServiceImpl) GenerateIdempotencyKey() (string, *core.NachnaException) {
	randomBytes := make([]byte, 16)
	_, err := rand.Read(randomBytes)
	if err != nil {
		return "", &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to generate idempotency key",
			LogMessage:   err.Error(),
		}
	}

	return fmt.Sprintf("idem_%x", randomBytes), nil
}

// CreatePaymentLink creates a payment link for a workshop
func (o *OrderServiceImpl) CreatePaymentLink(workshopUUID string, userID string, userEmail string, userPhoneNumber string) (*mongodb.Order, string, *core.NachnaException) {
	ctx := context.Background()

	// Get workshop details
	workshop, err := o.databaseImpl.GetWorkshopByUUID(ctx, workshopUUID)
	if err != nil {
		return nil, "", err
	}

	// Calculate amount (for now, using a default pricing structure)
	// In production, this would be calculated based on workshop pricing info
	amount := 1000.0 // Default amount
	if workshop.PricingInfo != nil {
		// Parse pricing info and calculate actual amount
		// This is a simplified implementation
	}

	// Generate order ID and idempotency key
	orderID, err := o.GenerateOrderID()
	if err != nil {
		return nil, "", err
	}

	idempotencyKey, err := o.GenerateIdempotencyKey()
	if err != nil {
		return nil, "", err
	}

	// Create order
	order := &mongodb.Order{
		OrderID:         orderID,
		UserID:          userID,
		WorkshopUUID:    workshopUUID,
		Amount:          amount,
		Currency:        "INR",
		Status:          mongodb.OrderStatusCreated,
		PaymentGateway:  "razorpay", // Default gateway
		IdempotencyKey:  idempotencyKey,
		UserEmail:       userEmail,
		UserPhoneNumber: userPhoneNumber,
		CreatedAt:       time.Now().Unix(),
		UpdatedAt:       time.Now().Unix(),
		WorkshopDetails: workshop,
	}

	// Add initial status update
	order.AddStatusUpdate(mongodb.OrderStatusCreated, nil)

	// Create payment link with external gateway
	paymentRequest := &payment.PaymentGatewayRequest{
		OrderID:         orderID,
		Amount:          amount,
		Currency:        "INR",
		UserEmail:       userEmail,
		UserPhoneNumber: userPhoneNumber,
		IdempotencyKey:  idempotencyKey,
		Description:     fmt.Sprintf("Payment for workshop: %s", workshopUUID),
	}

	paymentResponse, err := o.paymentService.CreatePaymentLink(paymentRequest)
	if err != nil {
		return nil, "", err
	}

	order.PaymentLink = &paymentResponse.PaymentLink

	// Save order to database
	err = o.databaseImpl.CreateOrder(ctx, order)
	if err != nil {
		return nil, "", err
	}

	return order, paymentResponse.PaymentLink, nil
}

// ProcessPaymentWebhook processes payment webhook updates
func (o *OrderServiceImpl) ProcessPaymentWebhook(orderID string, newStatus mongodb.OrderStatus, note *string) *core.NachnaException {
	ctx := context.Background()

	// Get existing order
	order, err := o.databaseImpl.GetOrderByID(ctx, orderID)
	if err != nil {
		return err
	}

	// Validate status transition
	if !order.IsValidStatusTransition(newStatus) {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: fmt.Sprintf("Invalid status transition from %s to %s", order.Status, newStatus),
		}
	}

	// Update order status
	err = o.databaseImpl.UpdateOrderStatus(ctx, orderID, newStatus, note)
	if err != nil {
		return err
	}

	// If order is successful, trigger QR generation in background
	if newStatus == mongodb.OrderStatusSuccessful {
		go o.GenerateQRForOrder(orderID)
	}

	return nil
}

// GenerateQRForOrder generates QR code for an order
func (o *OrderServiceImpl) GenerateQRForOrder(orderID string) {
	ctx := context.Background()

	// Check if QR generation is already in progress
	if o.qrService.IsQRGenerationInProgress(orderID) {
		return
	}

	// Get order details
	order, err := o.databaseImpl.GetOrderByID(ctx, orderID)
	if err != nil {
		fmt.Printf("Error getting order for QR generation: %v\n", err)
		return
	}

	// Skip if order already has QR code
	if order.OrderVerificationQR != nil && *order.OrderVerificationQR != "" {
		return
	}

	// Generate QR code
	qrCode, err := o.qrService.GenerateOrderQR(order)
	if err != nil {
		fmt.Printf("Error generating QR code for order %s: %v\n", orderID, err)
		return
	}

	// Update order with QR code
	err = o.databaseImpl.UpdateOrderQR(ctx, orderID, qrCode)
	if err != nil {
		fmt.Printf("Error updating order with QR code: %v\n", err)
		return
	}

	fmt.Printf("Successfully generated QR code for order %s\n", orderID)
}

// GetOrderStatus retrieves order status and details
func (o *OrderServiceImpl) GetOrderStatus(orderID string) (*mongodb.Order, *core.NachnaException) {
	ctx := context.Background()
	return o.databaseImpl.GetOrderByID(ctx, orderID)
}

// GetOrderHistory retrieves order history for a user
func (o *OrderServiceImpl) GetOrderHistory(userID string) ([]*mongodb.Order, *core.NachnaException) {
	ctx := context.Background()
	return o.databaseImpl.GetOrdersByUserID(ctx, userID)
}

// ProcessOrdersWithoutQR processes orders that need QR code generation
func (o *OrderServiceImpl) ProcessOrdersWithoutQR() *core.NachnaException {
	ctx := context.Background()

	// Get orders without QR codes
	orders, err := o.databaseImpl.GetOrdersWithoutQR(ctx)
	if err != nil {
		return err
	}

	fmt.Printf("Found %d orders without QR codes\n", len(orders))

	// Generate QR codes for each order
	for _, order := range orders {
		go o.GenerateQRForOrder(order.OrderID)
	}

	return nil
}
