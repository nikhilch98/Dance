package api

import (
	"nachna/core"
	"nachna/database"
	"nachna/models/request"
	"nachna/models/response"
	"nachna/service/order"
	"nachna/utils"
	"net/http"
)

func GetOrderService() (*order.OrderServiceImpl, *core.NachnaException) {
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return nil, err
	}
	orderService := order.OrderServiceImpl{}.GetInstance(databaseImpl)
	return orderService, nil
}

func CreatePaymentLink(r *http.Request) (any, *core.NachnaException) {
	createPaymentLinkRequest := &request.CreatePaymentLinkRequest{}
	err := createPaymentLinkRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	// Extract user ID from auth token (this would typically be done by middleware)
	userID := r.Header.Get("X-User-ID") // Assuming auth middleware sets this
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// For now, using mock user details - in production, fetch from user service
	userEmail := "user@example.com"
	userPhoneNumber := "+919999999999"

	orderService, err := GetOrderService()
	if err != nil {
		return nil, err
	}

	// Create payment link
	order, paymentLink, err := orderService.CreatePaymentLink(
		createPaymentLinkRequest.WorkshopUUID,
		userID,
		userEmail,
		userPhoneNumber,
	)
	if err != nil {
		return nil, err
	}

	return response.CreatePaymentLinkResponse{
		PaymentLink: paymentLink,
		OrderID:     order.OrderID,
		Amount:      order.Amount,
		Currency:    order.Currency,
	}, nil
}

func PaymentWebhook(r *http.Request) (any, *core.NachnaException) {
	paymentWebhookRequest := &request.PaymentWebhookRequest{}
	err := paymentWebhookRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	orderService, err := GetOrderService()
	if err != nil {
		return nil, err
	}

	// Process webhook
	err = orderService.ProcessPaymentWebhook(
		paymentWebhookRequest.OrderID,
		paymentWebhookRequest.Status,
		paymentWebhookRequest.Note,
	)
	if err != nil {
		return nil, err
	}

	return response.PaymentWebhookResponse{
		Success: true,
		Message: "Webhook processed successfully",
	}, nil
}

func GetOrderStatus(r *http.Request) (any, *core.NachnaException) {
	orderStatusRequest := &request.OrderStatusRequest{}
	err := orderStatusRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	orderService, err := GetOrderService()
	if err != nil {
		return nil, err
	}

	// Get order status
	order, err := orderService.GetOrderStatus(orderStatusRequest.OrderID)
	if err != nil {
		return nil, err
	}

	return response.OrderStatusResponse{
		OrderID:         order.OrderID,
		UserID:          order.UserID,
		WorkshopUUID:    order.WorkshopUUID,
		Amount:          order.Amount,
		Currency:        order.Currency,
		Status:          order.Status,
		StatusHistory:   order.StatusHistory,
		PaymentLink:     order.PaymentLink,
		CreatedAt:       order.CreatedAt,
		UpdatedAt:       order.UpdatedAt,
		WorkshopDetails: order.WorkshopDetails,
	}, nil
}

func GetOrderHistory(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID") // Assuming auth middleware sets this
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	orderService, err := GetOrderService()
	if err != nil {
		return nil, err
	}

	// Get order history
	orders, err := orderService.GetOrderHistory(userID)
	if err != nil {
		return nil, err
	}

	// Convert to response format
	orderResponses := make([]response.OrderStatusResponse, len(orders))
	for i, order := range orders {
		orderResponses[i] = response.OrderStatusResponse{
			OrderID:         order.OrderID,
			UserID:          order.UserID,
			WorkshopUUID:    order.WorkshopUUID,
			Amount:          order.Amount,
			Currency:        order.Currency,
			Status:          order.Status,
			StatusHistory:   order.StatusHistory,
			PaymentLink:     order.PaymentLink,
			CreatedAt:       order.CreatedAt,
			UpdatedAt:       order.UpdatedAt,
			WorkshopDetails: order.WorkshopDetails,
		}
	}

	return response.OrderHistoryResponse{
		Orders: orderResponses,
		Total:  len(orderResponses),
	}, nil
}

func init() {
	// Payment APIs
	Router.HandleFunc(utils.MakeHandler("/create_payment_link", CreatePaymentLink, "user")).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/payment_webhook", PaymentWebhook)).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/order_status", GetOrderStatus, "user")).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/order_history", GetOrderHistory, "user")).Methods(http.MethodGet)
}
