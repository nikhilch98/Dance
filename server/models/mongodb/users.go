package mongodb

import "time"

type User struct {
	ID                ObjectId  `json:"_id,omitempty" bson:"_id,omitempty"`
	MobileNumber      string    `json:"mobile_number" bson:"mobile_number"`
	Name              *string   `json:"name,omitempty" bson:"name,omitempty"`
	DateOfBirth       *string   `json:"date_of_birth,omitempty" bson:"date_of_birth,omitempty"`
	Gender            *string   `json:"gender,omitempty" bson:"gender,omitempty"`
	ProfilePictureID  *string   `json:"profile_picture_id,omitempty" bson:"profile_picture_id,omitempty"`
	ProfilePictureURL *string   `json:"profile_picture_url,omitempty" bson:"profile_picture_url,omitempty"`
	IsAdmin           bool      `json:"is_admin" bson:"is_admin"`
	CreatedAt         time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt         time.Time `json:"updated_at" bson:"updated_at"`
	IsDeleted         bool      `json:"is_deleted" bson:"is_deleted"`
}

type ProfilePicture struct {
	ID          ObjectId  `json:"_id,omitempty" bson:"_id,omitempty"`
	UserID      string    `json:"user_id" bson:"user_id"`
	ImageData   []byte    `json:"image_data" bson:"image_data"`
	ContentType string    `json:"content_type" bson:"content_type"`
	Filename    string    `json:"filename" bson:"filename"`
	Size        int64     `json:"size" bson:"size"`
	CreatedAt   time.Time `json:"created_at" bson:"created_at"`
}

type DeviceToken struct {
	ID          ObjectId  `json:"_id,omitempty" bson:"_id,omitempty"`
	UserID      string    `json:"user_id" bson:"user_id"`
	DeviceToken string    `json:"device_token" bson:"device_token"`
	Platform    string    `json:"platform" bson:"platform"` // ios, android
	IsActive    bool      `json:"is_active" bson:"is_active"`
	CreatedAt   time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" bson:"updated_at"`
}

type Notification struct {
	ID        ObjectId               `json:"_id,omitempty" bson:"_id,omitempty"`
	UserID    string                 `json:"user_id" bson:"user_id"`
	Title     string                 `json:"title" bson:"title"`
	Body      string                 `json:"body" bson:"body"`
	Data      map[string]interface{} `json:"data,omitempty" bson:"data,omitempty"`
	Sent      bool                   `json:"sent" bson:"sent"`
	Success   bool                   `json:"success" bson:"success"`
	ErrorMsg  *string                `json:"error_msg,omitempty" bson:"error_msg,omitempty"`
	CreatedAt time.Time              `json:"created_at" bson:"created_at"`
	SentAt    *time.Time             `json:"sent_at,omitempty" bson:"sent_at,omitempty"`
}

type Reaction struct {
	ID         ObjectId  `json:"_id,omitempty" bson:"_id,omitempty"`
	UserID     string    `json:"user_id" bson:"user_id"`
	EntityID   string    `json:"entity_id" bson:"entity_id"`
	EntityType string    `json:"entity_type" bson:"entity_type"` // artist, workshop, studio
	Reaction   string    `json:"reaction" bson:"reaction"`       // like, notify
	IsDeleted  bool      `json:"is_deleted" bson:"is_deleted"`
	CreatedAt  time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt  time.Time `json:"updated_at" bson:"updated_at"`
}

// ObjectId represents MongoDB ObjectId
type ObjectId interface{}
