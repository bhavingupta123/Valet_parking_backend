package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type SessionStatus string

const (
	StatusPending   SessionStatus = "pending"   // Waiting for customer acceptance
	StatusParked    SessionStatus = "parked"    // Customer accepted, car is parked
	StatusRequested SessionStatus = "requested" // Customer requested pickup
	StatusMoving    SessionStatus = "moving"    // Valet is getting the car
	StatusAvailable SessionStatus = "available" // Car is ready for pickup
	StatusDelivered SessionStatus = "delivered" // Car delivered to customer
	StatusCancelled SessionStatus = "cancelled" // Request cancelled
	StatusInTransit SessionStatus = "in_transit"
)

type ParkingSession struct {
	ID           primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	TicketNumber string             `bson:"ticket_number" json:"ticket_number"`
	VehicleID    primitive.ObjectID `bson:"vehicle_id" json:"vehicle_id"`
	CustomerID   primitive.ObjectID `bson:"customer_id" json:"customer_id"`
	ValetID      primitive.ObjectID `bson:"valet_id" json:"valet_id"`
	VenueName    string             `bson:"venue_name" json:"venue_name"`
	Status       SessionStatus      `bson:"status" json:"status"`
	ParkedAt     time.Time          `bson:"parked_at" json:"parked_at"`
	RequestedAt  *time.Time         `bson:"requested_at,omitempty" json:"requested_at,omitempty"`
	DeliveredAt  *time.Time         `bson:"delivered_at,omitempty" json:"delivered_at,omitempty"`
	PickupOTP    string             `bson:"pickup_otp,omitempty" json:"pickup_otp,omitempty"`
	OTPExpiresAt *time.Time         `bson:"otp_expires_at,omitempty" json:"otp_expires_at,omitempty"`
}

// SessionWithDetails includes vehicle and user details for API responses
type SessionWithDetails struct {
	ParkingSession `bson:",inline"`
	Vehicle        *Vehicle `bson:"vehicle,omitempty" json:"vehicle,omitempty"`
	Customer       *User    `bson:"customer,omitempty" json:"customer,omitempty"`
	Valet          *User    `bson:"valet,omitempty" json:"valet,omitempty"`
}
