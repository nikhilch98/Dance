package database

import (
	"context"
	"errors"
	"nachna/config"
	"nachna/core"
	"nachna/models/mongodb"
	"sync"

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

var mongoDBDatabaseImpl *MongoDBDatabaseImpl

// GetInstance returns a singleton instance of MongoDBDatabaseImpl
func (MongoDBDatabaseImpl) GetInstance() (Database, *core.NachnaException) {
	lock.Lock()
	defer lock.Unlock()
	if mongoDBDatabaseImpl == nil {
		mongoDBDatabaseImpl = &MongoDBDatabaseImpl{}
		err := mongoDBDatabaseImpl.Connect(context.Background())
		if err != nil {
			mongoDBDatabaseImpl = nil
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to connect to MongoDB",
			}
		}
	}
	return mongoDBDatabaseImpl, nil
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
