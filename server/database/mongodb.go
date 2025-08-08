package database

import (
	"context"
	"errors"
	"nachna/config"
	"nachna/core"
	"nachna/models/mongodb"
	"sync"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var lock = &sync.Mutex{}

type MongoDBDatabaseImpl struct {
	client   *mongo.Client
	database *mongo.Database
}

// InsertWorkshops implements Database.
func (m *MongoDBDatabaseImpl) InsertWorkshops(ctx context.Context, workshops []mongodb.Workshop) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}
	// Convert []*mongodb.Workshop to []interface{}
	docs := make([]interface{}, len(workshops))
	for i, workshop := range workshops {
		docs[i] = workshop
	}
	_, err := m.database.Collection("workshops_v2").InsertMany(ctx, docs)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to insert workshops",
		}
	}
	return nil
}

// RemoveWorkshopsGivenStudioId implements Database.
func (m *MongoDBDatabaseImpl) RemoveWorkshopsGivenStudioId(ctx context.Context, studioId string) (int64, *core.NachnaException) {
	if m.database == nil {
		return 0, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Remove all workshops with the given studioId
	filter := bson.M{"studio_id": studioId}
	deleteResult, err := m.database.Collection("workshops_v2").DeleteMany(ctx, filter)
	if err != nil {
		return 0, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to remove workshops for studio",
		}
	}
	return deleteResult.DeletedCount, nil
}

// GetChoreoLinkGivenArtistIdListAndSong implements Database.
func (m *MongoDBDatabaseImpl) GetChoreoLinkGivenArtistIdListAndSong(ctx context.Context, artistIdList []string, song string) (*string, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}
	cursor := m.database.Collection("choreo_links").FindOne(ctx, bson.M{"song": song, "artist_id_list": artistIdList})
	if cursor == nil || cursor.Err() != nil {
		return nil, nil
	}
	var choreoLink mongodb.ChoreoLink
	if err := cursor.Decode(&choreoLink); err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to decode choreo link",
		}
	}
	return &choreoLink.ChoreoInstaLink, nil
}

var databaseServiceInstance *MongoDBDatabaseImpl

// GetInstance returns a singleton instance of MongoDBDatabaseImpl
func (MongoDBDatabaseImpl) GetInstance() (*MongoDBDatabaseImpl, *core.NachnaException) {
	lock.Lock()
	defer lock.Unlock()
	if databaseServiceInstance == nil {
		databaseServiceInstance = &MongoDBDatabaseImpl{}
		err := databaseServiceInstance.Connect(context.Background())
		if err != nil {
			databaseServiceInstance = nil
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to connect to MongoDB",
			}
		}
	}
	return databaseServiceInstance, nil
}

func (m *MongoDBDatabaseImpl) Connect(ctx context.Context) error {
	if m.client != nil {
		return nil // already connected
	}
	client, err := mongo.Connect(ctx, options.Client().ApplyURI(config.Config.MongoDB.Uri))
	if err != nil {
		return err
	}
	m.client = client
	m.database = client.Database("discovery")
	return nil
}

func (m *MongoDBDatabaseImpl) Disconnect(ctx context.Context) error {
	if m.client == nil {
		return nil
	}
	return m.client.Disconnect(ctx)
}

func (m *MongoDBDatabaseImpl) Ping(ctx context.Context) error {
	if m.client == nil {
		return errors.New("not connected")
	}
	return m.client.Ping(ctx, nil)
}

func (m *MongoDBDatabaseImpl) GetAllArtists(ctx context.Context) ([]*mongodb.Artist, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}
	cursor, err := m.database.Collection("artists_v2").Find(ctx, bson.M{})
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to get artists",
		}
	}
	defer cursor.Close(ctx)
	var artists []*mongodb.Artist
	for cursor.Next(ctx) {
		var artist mongodb.Artist
		if err := cursor.Decode(&artist); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode artist",
			}
		}
		artists = append(artists, &artist)
	}
	return artists, nil
}

func (m *MongoDBDatabaseImpl) GetAllStudiosFromDB(ctx context.Context) ([]*mongodb.Studio, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}
	cursor, err := m.database.Collection("studios").Find(ctx, bson.M{})
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to get studios",
		}
	}
	defer cursor.Close(ctx)
	var studios []*mongodb.Studio
	for cursor.Next(ctx) {
		var studio mongodb.Studio
		if err := cursor.Decode(&studio); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode studio",
			}
		}
		studios = append(studios, &studio)
	}
	return studios, nil
}

// Order-related operations

// CreateOrder creates a new order in the database
func (m *MongoDBDatabaseImpl) CreateOrder(ctx context.Context, order *mongodb.Order) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	_, err := m.database.Collection("orders").InsertOne(ctx, order)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to create order",
		}
	}
	return nil
}

// GetOrderByID retrieves an order by its ID
func (m *MongoDBDatabaseImpl) GetOrderByID(ctx context.Context, orderID string) (*mongodb.Order, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	var order mongodb.Order
	err := m.database.Collection("orders").FindOne(ctx, bson.M{"order_id": orderID}).Decode(&order)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return nil, &core.NachnaException{
				LogMessage:   "order not found",
				StatusCode:   404,
				ErrorMessage: "Order not found",
			}
		}
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve order",
		}
	}
	return &order, nil
}

// UpdateOrderStatus updates an order's status and adds to status history
func (m *MongoDBDatabaseImpl) UpdateOrderStatus(ctx context.Context, orderID string, status mongodb.OrderStatus, note *string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Create status update
	statusUpdate := mongodb.OrderStatusUpdate{
		Status:    status,
		Timestamp: time.Now().Unix(),
		Note:      note,
	}

	// Update order with new status and push to status history
	update := bson.M{
		"$set": bson.M{
			"status":     status,
			"updated_at": time.Now().Unix(),
		},
		"$push": bson.M{
			"status_history": statusUpdate,
		},
	}

	_, err := m.database.Collection("orders").UpdateOne(ctx, bson.M{"order_id": orderID}, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to update order status",
		}
	}
	return nil
}

// UpdateOrderQR updates an order with the generated QR code
func (m *MongoDBDatabaseImpl) UpdateOrderQR(ctx context.Context, orderID string, qrCode string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	update := bson.M{
		"$set": bson.M{
			"order_verification_qr": qrCode,
			"updated_at":            time.Now().Unix(),
		},
	}

	_, err := m.database.Collection("orders").UpdateOne(ctx, bson.M{"order_id": orderID}, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to update order QR code",
		}
	}
	return nil
}

// GetOrdersByUserID retrieves all orders for a specific user
func (m *MongoDBDatabaseImpl) GetOrdersByUserID(ctx context.Context, userID string) ([]*mongodb.Order, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Sort by created_at descending (newest first)
	opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}})
	cursor, err := m.database.Collection("orders").Find(ctx, bson.M{"user_id": userID}, opts)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve orders",
		}
	}
	defer cursor.Close(ctx)

	var orders []*mongodb.Order
	for cursor.Next(ctx) {
		var order mongodb.Order
		if err := cursor.Decode(&order); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode order",
			}
		}
		orders = append(orders, &order)
	}
	return orders, nil
}

// GetWorkshopByUUID retrieves a workshop by its UUID
func (m *MongoDBDatabaseImpl) GetWorkshopByUUID(ctx context.Context, workshopUUID string) (*mongodb.Workshop, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	var workshop mongodb.Workshop
	err := m.database.Collection("workshops_v2").FindOne(ctx, bson.M{"uuid": workshopUUID}).Decode(&workshop)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return nil, &core.NachnaException{
				LogMessage:   "workshop not found",
				StatusCode:   404,
				ErrorMessage: "Workshop not found",
			}
		}
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve workshop",
		}
	}
	return &workshop, nil
}

// GetOrdersWithoutQR retrieves orders with successful status but no QR code
func (m *MongoDBDatabaseImpl) GetOrdersWithoutQR(ctx context.Context) ([]*mongodb.Order, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{
		"status": mongodb.OrderStatusSuccessful,
		"$or": []bson.M{
			{"order_verification_qr": bson.M{"$exists": false}},
			{"order_verification_qr": nil},
			{"order_verification_qr": ""},
		},
	}

	cursor, err := m.database.Collection("orders").Find(ctx, filter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve orders without QR",
		}
	}
	defer cursor.Close(ctx)

	var orders []*mongodb.Order
	for cursor.Next(ctx) {
		var order mongodb.Order
		if err := cursor.Decode(&order); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode order",
			}
		}
		orders = append(orders, &order)
	}
	return orders, nil
}
