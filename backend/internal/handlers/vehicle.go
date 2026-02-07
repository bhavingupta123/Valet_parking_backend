package handlers

import (
	"context"
	"net/http"
	"time"

	"valet-parking-backend/internal/db"
	"valet-parking-backend/internal/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type VehicleHandler struct {
	db *db.MongoDB
}

func NewVehicleHandler(database *db.MongoDB) *VehicleHandler {
	return &VehicleHandler{db: database}
}

type AddVehicleRequest struct {
	RegistrationNumber string `json:"registration_number" binding:"required"`
	Make               string `json:"make" binding:"required"`
	Model              string `json:"model" binding:"required"`
	Color              string `json:"color" binding:"required"`
	VehicleType        string `json:"vehicle_type" binding:"required"`
	Photos             []string `json:"photos,omitempty"`
}

func (h *VehicleHandler) AddVehicle(c *gin.Context) {
	var req AddVehicleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID, _ := c.Get("user_id")
	ownerID, err := primitive.ObjectIDFromHex(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Check if vehicle already exists for this owner
	var existing models.Vehicle
	err = h.db.Vehicles().FindOne(ctx, bson.M{
		"owner_id":            ownerID,
		"registration_number": req.RegistrationNumber,
	}).Decode(&existing)

	if err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Vehicle already registered"})
		return
	}

	// Validate vehicle type
	vehicleType := models.VehicleType(req.VehicleType)
	if vehicleType != models.VehicleTypeCar && vehicleType != models.VehicleTypeBike && vehicleType != models.VehicleTypeThreeWheel {
		vehicleType = models.VehicleTypeCar // Default to car
	}

	vehicle := models.Vehicle{
		ID:                 primitive.NewObjectID(),
		OwnerID:            ownerID,
		RegistrationNumber: req.RegistrationNumber,
		Make:               req.Make,
		Model:              req.Model,
		Color:              req.Color,
		VehicleType:        vehicleType,
		Photos:             req.Photos,
		CreatedAt:          time.Now(),
	}

	_, err = h.db.Vehicles().InsertOne(ctx, vehicle)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add vehicle"})
		return
	}

	c.JSON(http.StatusCreated, vehicle)
}

func (h *VehicleHandler) ListVehicles(c *gin.Context) {
	userID, _ := c.Get("user_id")
	ownerID, err := primitive.ObjectIDFromHex(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cursor, err := h.db.Vehicles().Find(ctx, bson.M{"owner_id": ownerID})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch vehicles"})
		return
	}
	defer cursor.Close(ctx)

	var vehicles []models.Vehicle
	if err := cursor.All(ctx, &vehicles); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode vehicles"})
		return
	}

	if vehicles == nil {
		vehicles = []models.Vehicle{}
	}

	c.JSON(http.StatusOK, vehicles)
}

// GetVehicleByRegistration finds a vehicle by registration number (for valets)
func (h *VehicleHandler) GetVehicleByRegistration(c *gin.Context) {
	regNumber := c.Query("registration_number")
	if regNumber == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Registration number required"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var vehicle models.Vehicle
	err := h.db.Vehicles().FindOne(ctx, bson.M{
		"registration_number": regNumber,
	}).Decode(&vehicle)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Vehicle not found"})
		return
	}

	// Get owner details
	var owner models.User
	_ = h.db.Users().FindOne(ctx, bson.M{"_id": vehicle.OwnerID}).Decode(&owner)

	c.JSON(http.StatusOK, gin.H{
		"vehicle": vehicle,
		"owner":   owner,
	})
}
