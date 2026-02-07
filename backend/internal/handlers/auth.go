package handlers

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"time"

	"valet-parking-backend/internal/db"
	"valet-parking-backend/internal/middleware"
	"valet-parking-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type AuthHandler struct {
	db        *db.MongoDB
	jwtSecret string
}

func NewAuthHandler(database *db.MongoDB, jwtSecret string) *AuthHandler {
	return &AuthHandler{
		db:        database,
		jwtSecret: jwtSecret,
	}
}

type SendOTPRequest struct {
	Phone string `json:"phone" binding:"required"`
	Role  string `json:"role" binding:"required"`
}

type VerifyOTPRequest struct {
	Phone     string `json:"phone" binding:"required"`
	OTP       string `json:"otp" binding:"required"`
	Name      string `json:"name"`
	VenueName string `json:"venue_name"` // Only for valets
}

func (h *AuthHandler) SendOTP(c *gin.Context) {
	var req SendOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate role
	if req.Role != string(models.RoleCustomer) && req.Role != string(models.RoleValet) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid role. Must be 'customer' or 'valet'"})
		return
	}

	// Generate 6-digit OTP
	otp := fmt.Sprintf("%06d", rand.Intn(1000000))

	// Store OTP in database
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Delete any existing OTP for this phone
	_, _ = h.db.OTPs().DeleteMany(ctx, bson.M{"phone": req.Phone})

	// Insert new OTP
	otpDoc := models.OTPStore{
		Phone:     req.Phone,
		OTP:       otp,
		Role:      models.Role(req.Role),
		ExpiresAt: time.Now().Add(5 * time.Minute),
	}

	_, err := h.db.OTPs().InsertOne(ctx, otpDoc)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate OTP"})
		return
	}

	// Log OTP to console (for MVP - no actual SMS)
	log.Printf("========================================")
	log.Printf("OTP for %s: %s", req.Phone, otp)
	log.Printf("========================================")

	c.JSON(http.StatusOK, gin.H{
		"message": "OTP sent successfully",
		"otp":     otp, // Include OTP in response for MVP testing
	})
}

func (h *AuthHandler) VerifyOTP(c *gin.Context) {
	var req VerifyOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Find OTP
	var otpDoc models.OTPStore
	err := h.db.OTPs().FindOne(ctx, bson.M{
		"phone": req.Phone,
		"otp":   req.OTP,
	}).Decode(&otpDoc)

	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid OTP"})
		return
	}

	// Check if OTP expired
	if time.Now().After(otpDoc.ExpiresAt) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "OTP expired"})
		return
	}

	// Delete used OTP
	_, _ = h.db.OTPs().DeleteOne(ctx, bson.M{"_id": otpDoc.ID})

	// Find or create user
	var user models.User
	err = h.db.Users().FindOne(ctx, bson.M{
		"phone": req.Phone,
		"role":  otpDoc.Role,
	}).Decode(&user)

	if err != nil {
		// Create new user
		user = models.User{
			ID:        primitive.NewObjectID(),
			Phone:     req.Phone,
			Name:      req.Name,
			Role:      otpDoc.Role,
			VenueName: req.VenueName, // Only used for valets
			CreatedAt: time.Now(),
		}
		_, err = h.db.Users().InsertOne(ctx, user)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
			return
		}
	}

	// Generate JWT
	claims := middleware.Claims{
		UserID: user.ID.Hex(),
		Phone:  user.Phone,
		Role:   string(user.Role),
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour * 30)), // 30 days
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(h.jwtSecret))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": tokenString,
		"user":  user,
	})
}

type UpdateProfileRequest struct {
	Name      string `json:"name" binding:"required"`
	VenueName string `json:"venue_name"`
}

func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID, _ := c.Get("user_id")
	userObjID, _ := primitive.ObjectIDFromHex(userID.(string))

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Build update document
	updateDoc := bson.M{
		"name": req.Name,
	}
	if req.VenueName != "" {
		updateDoc["venue_name"] = req.VenueName
	}

	// Update user
	_, err := h.db.Users().UpdateOne(ctx,
		bson.M{"_id": userObjID},
		bson.M{"$set": updateDoc},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
		return
	}

	// Get updated user
	var user models.User
	err = h.db.Users().FindOne(ctx, bson.M{"_id": userObjID}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get updated profile"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Profile updated successfully",
		"user":    user,
	})
}
