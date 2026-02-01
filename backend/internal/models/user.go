package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Role string

const (
	RoleCustomer Role = "customer"
	RoleValet    Role = "valet"
)

type User struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Phone     string             `bson:"phone" json:"phone"`
	Name      string             `bson:"name" json:"name"`
	Role      Role               `bson:"role" json:"role"`
	CreatedAt time.Time          `bson:"created_at" json:"created_at"`
}

type OTPStore struct {
	ID        primitive.ObjectID `bson:"_id,omitempty"`
	Phone     string             `bson:"phone"`
	OTP       string             `bson:"otp"`
	Role      Role               `bson:"role"`
	ExpiresAt time.Time          `bson:"expires_at"`
}
