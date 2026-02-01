package handlers

import (
	"context"
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"valet-parking-backend/internal/db"
	"valet-parking-backend/internal/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type SessionHandler struct {
	db *db.MongoDB
}

func NewSessionHandler(database *db.MongoDB) *SessionHandler {
	return &SessionHandler{db: database}
}

type CreateSessionRequest struct {
	VehicleID  string `json:"vehicle_id" binding:"required"`
	CustomerID string `json:"customer_id" binding:"required"`
	VenueName  string `json:"venue_name" binding:"required"`
}

func (h *SessionHandler) CreateSession(c *gin.Context) {
	var req CreateSessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	valetID, _ := c.Get("user_id")
	valetObjID, _ := primitive.ObjectIDFromHex(valetID.(string))
	vehicleObjID, err := primitive.ObjectIDFromHex(req.VehicleID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid vehicle ID"})
		return
	}
	customerObjID, err := primitive.ObjectIDFromHex(req.CustomerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid customer ID"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Check if vehicle already has an active session
	var existing models.ParkingSession
	err = h.db.Sessions().FindOne(ctx, bson.M{
		"vehicle_id": vehicleObjID,
		"status":     bson.M{"$nin": []models.SessionStatus{models.StatusDelivered, models.StatusCancelled}},
	}).Decode(&existing)

	if err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Vehicle already has an active parking session"})
		return
	}

	// Generate ticket number
	ticketNumber := fmt.Sprintf("%s-%d", time.Now().Format("20060102"), rand.Intn(100000))

	session := models.ParkingSession{
		ID:           primitive.NewObjectID(),
		TicketNumber: ticketNumber,
		VehicleID:    vehicleObjID,
		CustomerID:   customerObjID,
		ValetID:      valetObjID,
		VenueName:    req.VenueName,
		Status:       models.StatusPending, // Waiting for customer acceptance
		ParkedAt:     time.Now(),
	}

	_, err = h.db.Sessions().InsertOne(ctx, session)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create session"})
		return
	}

	c.JSON(http.StatusCreated, session)
}

func (h *SessionHandler) GetActiveSession(c *gin.Context) {
	userID, _ := c.Get("user_id")
	role, _ := c.Get("role")
	userObjID, _ := primitive.ObjectIDFromHex(userID.(string))

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var filter bson.M
	if role == string(models.RoleCustomer) {
		filter = bson.M{
			"customer_id": userObjID,
			"status":      bson.M{"$nin": []models.SessionStatus{models.StatusDelivered, models.StatusCancelled}},
		}
	} else {
		filter = bson.M{
			"valet_id": userObjID,
			"status":   bson.M{"$nin": []models.SessionStatus{models.StatusDelivered, models.StatusCancelled}},
		}
	}

	var session models.ParkingSession
	err := h.db.Sessions().FindOne(ctx, filter, options.FindOne().SetSort(bson.D{{Key: "parked_at", Value: -1}})).Decode(&session)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "No active session found"})
		return
	}

	// Get vehicle details
	var vehicle models.Vehicle
	_ = h.db.Vehicles().FindOne(ctx, bson.M{"_id": session.VehicleID}).Decode(&vehicle)

	// Get customer details
	var customer models.User
	_ = h.db.Users().FindOne(ctx, bson.M{"_id": session.CustomerID}).Decode(&customer)

	// Get valet details
	var valet models.User
	_ = h.db.Users().FindOne(ctx, bson.M{"_id": session.ValetID}).Decode(&valet)

	c.JSON(http.StatusOK, gin.H{
		"session":  session,
		"vehicle":  vehicle,
		"customer": customer,
		"valet":    valet,
	})
}

func (h *SessionHandler) GetSession(c *gin.Context) {
	sessionID := c.Param("id")
	sessionObjID, err := primitive.ObjectIDFromHex(sessionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid session ID"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var session models.ParkingSession
	err = h.db.Sessions().FindOne(ctx, bson.M{"_id": sessionObjID}).Decode(&session)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Session not found"})
		return
	}

	// Get vehicle details
	var vehicle models.Vehicle
	_ = h.db.Vehicles().FindOne(ctx, bson.M{"_id": session.VehicleID}).Decode(&vehicle)

	// Get customer details
	var customer models.User
	_ = h.db.Users().FindOne(ctx, bson.M{"_id": session.CustomerID}).Decode(&customer)

	// Get valet details
	var valet models.User
	_ = h.db.Users().FindOne(ctx, bson.M{"_id": session.ValetID}).Decode(&valet)

	c.JSON(http.StatusOK, gin.H{
		"session":  session,
		"vehicle":  vehicle,
		"customer": customer,
		"valet":    valet,
	})
}

func (h *SessionHandler) RequestPickup(c *gin.Context) {
	sessionID := c.Param("id")
	sessionObjID, err := primitive.ObjectIDFromHex(sessionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid session ID"})
		return
	}

	userID, _ := c.Get("user_id")
	userObjID, _ := primitive.ObjectIDFromHex(userID.(string))

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Find session and verify ownership
	var session models.ParkingSession
	err = h.db.Sessions().FindOne(ctx, bson.M{
		"_id":         sessionObjID,
		"customer_id": userObjID,
		"status":      models.StatusParked,
	}).Decode(&session)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Session not found or already requested"})
		return
	}

	// Generate pickup OTP
	pickupOTP := fmt.Sprintf("%06d", rand.Intn(1000000))
	now := time.Now()
	expiresAt := now.Add(30 * time.Minute)

	// Update session
	_, err = h.db.Sessions().UpdateOne(ctx,
		bson.M{"_id": sessionObjID},
		bson.M{
			"$set": bson.M{
				"status":         models.StatusRequested,
				"requested_at":   now,
				"pickup_otp":     pickupOTP,
				"otp_expires_at": expiresAt,
			},
		},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to request pickup"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":    "Pickup requested successfully",
		"pickup_otp": pickupOTP,
		"expires_at": expiresAt,
	})
}

// AcceptParking allows customer to accept a pending parking session
func (h *SessionHandler) AcceptParking(c *gin.Context) {
	sessionID := c.Param("id")
	sessionObjID, err := primitive.ObjectIDFromHex(sessionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid session ID"})
		return
	}

	userID, _ := c.Get("user_id")
	userObjID, _ := primitive.ObjectIDFromHex(userID.(string))

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Update session from pending to parked
	result, err := h.db.Sessions().UpdateOne(ctx,
		bson.M{
			"_id":         sessionObjID,
			"customer_id": userObjID,
			"status":      models.StatusPending,
		},
		bson.M{
			"$set": bson.M{
				"status": models.StatusParked,
			},
		},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to accept parking"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Session not found or already accepted"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Parking accepted"})
}

// RejectParking allows customer to reject a pending parking session
func (h *SessionHandler) RejectParking(c *gin.Context) {
	sessionID := c.Param("id")
	sessionObjID, err := primitive.ObjectIDFromHex(sessionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid session ID"})
		return
	}

	userID, _ := c.Get("user_id")
	userObjID, _ := primitive.ObjectIDFromHex(userID.(string))

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Delete the pending session
	result, err := h.db.Sessions().DeleteOne(ctx, bson.M{
		"_id":         sessionObjID,
		"customer_id": userObjID,
		"status":      models.StatusPending,
	})

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reject parking"})
		return
	}

	if result.DeletedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Session not found or already processed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Parking rejected"})
}

// CancelPickup allows customer to cancel a pickup request
func (h *SessionHandler) CancelPickup(c *gin.Context) {
	sessionID := c.Param("id")
	sessionObjID, err := primitive.ObjectIDFromHex(sessionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid session ID"})
		return
	}

	userID, _ := c.Get("user_id")
	userObjID, _ := primitive.ObjectIDFromHex(userID.(string))

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Reset session back to parked status
	result, err := h.db.Sessions().UpdateOne(ctx,
		bson.M{
			"_id":         sessionObjID,
			"customer_id": userObjID,
			"status":      bson.M{"$in": []models.SessionStatus{models.StatusRequested, models.StatusMoving}},
		},
		bson.M{
			"$set": bson.M{
				"status": models.StatusParked,
			},
			"$unset": bson.M{
				"requested_at":   "",
				"pickup_otp":     "",
				"otp_expires_at": "",
			},
		},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to cancel pickup"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Cannot cancel - car may already be ready for pickup"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Pickup cancelled"})
}

type VerifyDeliveryRequest struct {
	OTP string `json:"otp" binding:"required"`
}

func (h *SessionHandler) VerifyDelivery(c *gin.Context) {
	sessionID := c.Param("id")
	sessionObjID, err := primitive.ObjectIDFromHex(sessionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid session ID format"})
		return
	}

	var req VerifyDeliveryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// First find the session by ID
	var session models.ParkingSession
	err = h.db.Sessions().FindOne(ctx, bson.M{"_id": sessionObjID}).Decode(&session)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Session not found"})
		return
	}

	// Check if session is in valid status for delivery
	validStatuses := map[models.SessionStatus]bool{
		models.StatusRequested: true,
		models.StatusMoving:    true,
		models.StatusAvailable: true,
		models.StatusInTransit: true,
	}
	if !validStatuses[session.Status] {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Cannot deliver - session status is '%s'. Customer must request pickup first.", session.Status)})
		return
	}

	// Check if OTP exists
	if session.PickupOTP == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No OTP found for this session. Customer must request pickup first."})
		return
	}

	// Verify OTP
	if session.PickupOTP != req.OTP {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid OTP"})
		return
	}

	// Check if OTP expired
	if session.OTPExpiresAt != nil && time.Now().After(*session.OTPExpiresAt) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "OTP has expired. Customer needs to request pickup again."})
		return
	}

	// Update session to delivered
	now := time.Now()
	_, err = h.db.Sessions().UpdateOne(ctx,
		bson.M{"_id": sessionObjID},
		bson.M{
			"$set": bson.M{
				"status":       models.StatusDelivered,
				"delivered_at": now,
			},
			"$unset": bson.M{
				"pickup_otp":     "",
				"otp_expires_at": "",
			},
		},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete delivery"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      "Vehicle delivered successfully",
		"delivered_at": now,
	})
}

type UpdateStatusRequest struct {
	Status string `json:"status" binding:"required"`
}

// UpdateStatus allows valet to update session status
func (h *SessionHandler) UpdateStatus(c *gin.Context) {
	sessionID := c.Param("id")
	sessionObjID, err := primitive.ObjectIDFromHex(sessionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid session ID"})
		return
	}

	var req UpdateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate status - only moving and available allowed for valet updates
	validStatuses := map[string]bool{
		"moving":    true,
		"available": true,
	}
	if !validStatuses[req.Status] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status. Must be: moving or available"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Update session status - only when pickup has been requested
	result, err := h.db.Sessions().UpdateOne(ctx,
		bson.M{
			"_id":    sessionObjID,
			"status": bson.M{"$in": []models.SessionStatus{models.StatusRequested, models.StatusMoving, models.StatusAvailable}},
		},
		bson.M{
			"$set": bson.M{
				"status": models.SessionStatus(req.Status),
			},
		},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update status"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Session not found or cannot update status"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Status updated successfully",
		"status":  req.Status,
	})
}

// GetHistory returns completed and cancelled sessions for the user
func (h *SessionHandler) GetHistory(c *gin.Context) {
	userID, _ := c.Get("user_id")
	role, _ := c.Get("role")
	userObjID, _ := primitive.ObjectIDFromHex(userID.(string))

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var filter bson.M
	if role == string(models.RoleCustomer) {
		filter = bson.M{
			"customer_id": userObjID,
			"status":      bson.M{"$in": []models.SessionStatus{models.StatusDelivered, models.StatusCancelled}},
		}
	} else {
		filter = bson.M{
			"valet_id": userObjID,
			"status":   bson.M{"$in": []models.SessionStatus{models.StatusDelivered, models.StatusCancelled}},
		}
	}

	cursor, err := h.db.Sessions().Find(ctx, filter, options.Find().SetSort(bson.D{bson.E{Key: "parked_at", Value: -1}}).SetLimit(50))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch history"})
		return
	}
	defer cursor.Close(ctx)

	var sessions []models.ParkingSession
	if err := cursor.All(ctx, &sessions); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode sessions"})
		return
	}

	// Enrich with vehicle and customer details
	var results []gin.H
	for _, session := range sessions {
		var vehicle models.Vehicle
		_ = h.db.Vehicles().FindOne(ctx, bson.M{"_id": session.VehicleID}).Decode(&vehicle)

		var customer models.User
		_ = h.db.Users().FindOne(ctx, bson.M{"_id": session.CustomerID}).Decode(&customer)

		var valet models.User
		_ = h.db.Users().FindOne(ctx, bson.M{"_id": session.ValetID}).Decode(&valet)

		results = append(results, gin.H{
			"session":  session,
			"vehicle":  vehicle,
			"customer": customer,
			"valet":    valet,
		})
	}

	if results == nil {
		results = []gin.H{}
	}

	c.JSON(http.StatusOK, results)
}

// GetPendingPickups returns all sessions needing valet attention (requested, moving, available)
func (h *SessionHandler) GetPendingPickups(c *gin.Context) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cursor, err := h.db.Sessions().Find(ctx, bson.M{
		"status": bson.M{"$in": []models.SessionStatus{models.StatusRequested, models.StatusMoving, models.StatusAvailable}},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch pickups"})
		return
	}
	defer cursor.Close(ctx)

	var sessions []models.ParkingSession
	if err := cursor.All(ctx, &sessions); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode sessions"})
		return
	}

	// Enrich with vehicle and customer details
	var results []gin.H
	for _, session := range sessions {
		var vehicle models.Vehicle
		_ = h.db.Vehicles().FindOne(ctx, bson.M{"_id": session.VehicleID}).Decode(&vehicle)

		var customer models.User
		_ = h.db.Users().FindOne(ctx, bson.M{"_id": session.CustomerID}).Decode(&customer)

		results = append(results, gin.H{
			"session":  session,
			"vehicle":  vehicle,
			"customer": customer,
		})
	}

	if results == nil {
		results = []gin.H{}
	}

	c.JSON(http.StatusOK, results)
}

// GetAllActiveSessions returns all active sessions for valet (pending, parked, requested, moving, available)
func (h *SessionHandler) GetAllActiveSessions(c *gin.Context) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cursor, err := h.db.Sessions().Find(ctx, bson.M{
		"status": bson.M{"$nin": []models.SessionStatus{models.StatusDelivered, models.StatusCancelled}},
	}, options.Find().SetSort(bson.D{bson.E{Key: "parked_at", Value: -1}}))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch sessions"})
		return
	}
	defer cursor.Close(ctx)

	var sessions []models.ParkingSession
	if err := cursor.All(ctx, &sessions); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode sessions"})
		return
	}

	// Enrich with vehicle and customer details
	var results []gin.H
	for _, session := range sessions {
		var vehicle models.Vehicle
		_ = h.db.Vehicles().FindOne(ctx, bson.M{"_id": session.VehicleID}).Decode(&vehicle)

		var customer models.User
		_ = h.db.Users().FindOne(ctx, bson.M{"_id": session.CustomerID}).Decode(&customer)

		results = append(results, gin.H{
			"session":  session,
			"vehicle":  vehicle,
			"customer": customer,
		})
	}

	if results == nil {
		results = []gin.H{}
	}

	c.JSON(http.StatusOK, results)
}
