package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type VehicleType string

const (
	VehicleTypeCar        VehicleType = "car"
	VehicleTypeBike       VehicleType = "bike"
	VehicleTypeThreeWheel VehicleType = "three_wheeler"
)

type Vehicle struct {
	ID                 primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	OwnerID            primitive.ObjectID `bson:"owner_id" json:"owner_id"`
	RegistrationNumber string             `bson:"registration_number" json:"registration_number"`
	Make               string             `bson:"make" json:"make"`
	Model              string             `bson:"model" json:"model"`
	Color              string             `bson:"color" json:"color"`
	VehicleType        VehicleType        `bson:"vehicle_type" json:"vehicle_type"`
	Photos             []string           `bson:"photos,omitempty" json:"photos,omitempty"`
	CreatedAt          time.Time          `bson:"created_at" json:"created_at"`
}
