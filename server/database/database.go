package database

import (
	"context"
	"nachna/core"
	"nachna/models/mongodb"
)

// DatabaseInterface defines the contract for database operations
type Database interface {
	// Artist operations
	GetInstance() (Database, *core.NachnaException)
	GetAllArtists(ctx context.Context) ([]*mongodb.Artist, *core.NachnaException)
	GetChoreoLinkGivenArtistIdListAndSong(ctx context.Context, artistIdList []string, song string) (*string, *core.NachnaException)
	RemoveWorkshopsGivenStudioId(ctx context.Context, studioId string) (int64, *core.NachnaException)
	InsertWorkshops(ctx context.Context, workshops []mongodb.Workshop) *core.NachnaException
	// Connection management
	Connect(ctx context.Context) error
	Disconnect(ctx context.Context) error
	Ping(ctx context.Context) error
}
