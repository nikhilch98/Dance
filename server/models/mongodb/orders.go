package mongodb

import "time"

type OrderStatus string

const (
	OrderStatusCreated    OrderStatus = "CREATED"
	OrderStatusPending    OrderStatus = "PENDING"
	OrderStatusSuccessful OrderStatus = "SUCCESSFUL"
	OrderStatusCanceled   OrderStatus = "CANCELED"
	OrderStatusRefunded   OrderStatus = "REFUNDED"
)

type OrderStatusUpdate struct {
	Status    OrderStatus `json:"status" bson:"status"`
	Timestamp int64       `json:"timestamp" bson:"timestamp"`
	Note      *string     `json:"note,omitempty" bson:"note,omitempty"`
}

type Order struct {
	OrderID             string              `json:"order_id" bson:"order_id"`
	UserID              string              `json:"user_id" bson:"user_id"`
	WorkshopUUID        string              `json:"workshop_uuid" bson:"workshop_uuid"`
	Amount              float64             `json:"amount" bson:"amount"`
	Currency            string              `json:"currency" bson:"currency"`
	Status              OrderStatus         `json:"status" bson:"status"`
	StatusHistory       []OrderStatusUpdate `json:"status_history" bson:"status_history"`
	PaymentLink         *string             `json:"payment_link,omitempty" bson:"payment_link,omitempty"`
	PaymentGateway      string              `json:"payment_gateway" bson:"payment_gateway"`
	IdempotencyKey      string              `json:"idempotency_key" bson:"idempotency_key"`
	UserEmail           string              `json:"user_email" bson:"user_email"`
	UserPhoneNumber     string              `json:"user_phone_number" bson:"user_phone_number"`
	OrderVerificationQR *string             `json:"order_verification_qr,omitempty" bson:"order_verification_qr,omitempty"`
	CreatedAt           int64               `json:"created_at" bson:"created_at"`
	UpdatedAt           int64               `json:"updated_at" bson:"updated_at"`
	WorkshopDetails     *Workshop           `json:"workshop_details,omitempty" bson:"workshop_details,omitempty"`
}

// IsValidStatusTransition checks if a status transition is valid
func (o *Order) IsValidStatusTransition(newStatus OrderStatus) bool {
	currentStatus := o.Status

	switch currentStatus {
	case OrderStatusCreated:
		return newStatus == OrderStatusPending || newStatus == OrderStatusCanceled
	case OrderStatusPending:
		return newStatus == OrderStatusSuccessful || newStatus == OrderStatusCanceled
	case OrderStatusSuccessful:
		return newStatus == OrderStatusRefunded
	case OrderStatusCanceled:
		return false // Cannot transition from canceled
	case OrderStatusRefunded:
		return false // Cannot transition from refunded
	default:
		return false
	}
}

// AddStatusUpdate adds a new status update to the order
func (o *Order) AddStatusUpdate(status OrderStatus, note *string) {
	update := OrderStatusUpdate{
		Status:    status,
		Timestamp: time.Now().Unix(),
		Note:      note,
	}
	o.StatusHistory = append(o.StatusHistory, update)
	o.Status = status
	o.UpdatedAt = time.Now().Unix()
}
