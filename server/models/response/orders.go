package response

import "nachna/models/mongodb"

type CreatePaymentLinkResponse struct {
	PaymentLink string  `json:"payment_link"`
	OrderID     string  `json:"order_id"`
	Amount      float64 `json:"amount"`
	Currency    string  `json:"currency"`
}

type PaymentWebhookResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type OrderStatusResponse struct {
	OrderID         string                      `json:"order_id"`
	UserID          string                      `json:"user_id"`
	WorkshopUUID    string                      `json:"workshop_uuid"`
	Amount          float64                     `json:"amount"`
	Currency        string                      `json:"currency"`
	Status          mongodb.OrderStatus         `json:"status"`
	StatusHistory   []mongodb.OrderStatusUpdate `json:"status_history"`
	PaymentLink     *string                     `json:"payment_link,omitempty"`
	CreatedAt       int64                       `json:"created_at"`
	UpdatedAt       int64                       `json:"updated_at"`
	WorkshopDetails *mongodb.Workshop           `json:"workshop_details,omitempty"`
}

type OrderHistoryResponse struct {
	Orders []OrderStatusResponse `json:"orders"`
	Total  int                   `json:"total"`
}
