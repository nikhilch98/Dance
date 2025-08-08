package request

import (
	"encoding/json"
	"io"
	"nachna/core"
	"nachna/models/mongodb"
)

type CreatePaymentLinkRequest struct {
	WorkshopUUID string `json:"workshop_uuid"`
}

func (r *CreatePaymentLinkRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.WorkshopUUID == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "workshop_uuid is required",
		}
	}

	return nil
}

type PaymentWebhookRequest struct {
	OrderID   string              `json:"order_id"`
	Status    mongodb.OrderStatus `json:"status"`
	Gateway   string              `json:"gateway"`
	Note      *string             `json:"note,omitempty"`
	Signature *string             `json:"signature,omitempty"`
}

func (r *PaymentWebhookRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.OrderID == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "order_id is required",
		}
	}

	if r.Status == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "status is required",
		}
	}

	return nil
}

type OrderStatusRequest struct {
	OrderID string `json:"order_id"`
}

func (r *OrderStatusRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.OrderID == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "order_id is required",
		}
	}

	return nil
}
