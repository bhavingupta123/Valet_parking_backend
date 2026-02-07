package main

import (
	"log"

	"valet-parking-backend/internal/config"
	"valet-parking-backend/internal/db"
	"valet-parking-backend/internal/handlers"
	"valet-parking-backend/internal/middleware"
	"valet-parking-backend/internal/models"

	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	cfg := config.Load()
	log.Println("entering main")

	// Connect to MongoDB
	database, err := db.Connect(cfg.MongoURI, cfg.DBName)
	if err != nil {
		log.Fatal("Failed to connect to MongoDB:", err)
	}
	defer database.Close()

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(database, cfg.JWTSecret)
	vehicleHandler := handlers.NewVehicleHandler(database)
	sessionHandler := handlers.NewSessionHandler(database)

	// Setup Gin router
	r := gin.Default()

	// CORS middleware
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// API routes
	api := r.Group("/api")
	{
		// Auth routes (no auth required)
		auth := api.Group("/auth")
		{
			auth.POST("/send-otp", authHandler.SendOTP)
			auth.POST("/verify-otp", authHandler.VerifyOTP)
		}

		// Protected routes
		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(cfg.JWTSecret))
		{
			// Profile route (any authenticated user)
			protected.PUT("/auth/profile", authHandler.UpdateProfile)

			// Vehicle routes (customer only)
			vehicles := protected.Group("/vehicles")
			vehicles.Use(middleware.RoleMiddleware(string(models.RoleCustomer)))
			{
				vehicles.POST("", vehicleHandler.AddVehicle)
				vehicles.GET("", vehicleHandler.ListVehicles)
			}

			// Vehicle search (valet only)
			protected.GET("/vehicles/search", middleware.RoleMiddleware(string(models.RoleValet)), vehicleHandler.GetVehicleByRegistration)

			// Session routes
			sessions := protected.Group("/sessions")
			{
				// Create session (valet only)
				sessions.POST("", middleware.RoleMiddleware(string(models.RoleValet)), sessionHandler.CreateSession)

				// Get active session (any authenticated user)
				sessions.GET("/active", sessionHandler.GetActiveSession)

				// Get session by ID (any authenticated user)
				sessions.GET("/:id", sessionHandler.GetSession)

				// Request pickup (customer only)
				sessions.POST("/:id/request-pickup", middleware.RoleMiddleware(string(models.RoleCustomer)), sessionHandler.RequestPickup)

				// Accept parking (customer only)
				sessions.POST("/:id/accept", middleware.RoleMiddleware(string(models.RoleCustomer)), sessionHandler.AcceptParking)

				// Reject parking (customer only)
				sessions.POST("/:id/reject", middleware.RoleMiddleware(string(models.RoleCustomer)), sessionHandler.RejectParking)

				// Cancel pickup (customer only)
				sessions.POST("/:id/cancel-pickup", middleware.RoleMiddleware(string(models.RoleCustomer)), sessionHandler.CancelPickup)

				// Verify delivery (valet only)
				sessions.POST("/:id/verify-delivery", middleware.RoleMiddleware(string(models.RoleValet)), sessionHandler.VerifyDelivery)

				// Update session status (valet only)
				sessions.PUT("/:id/status", middleware.RoleMiddleware(string(models.RoleValet)), sessionHandler.UpdateStatus)

				// Get pending pickups (valet only)
				sessions.GET("/pending-pickups", middleware.RoleMiddleware(string(models.RoleValet)), sessionHandler.GetPendingPickups)

				// Get all active sessions (valet only)
				sessions.GET("/active-all", middleware.RoleMiddleware(string(models.RoleValet)), sessionHandler.GetAllActiveSessions)

				// Get history (any authenticated user)
				sessions.GET("/history", sessionHandler.GetHistory)
			}
		}
	}

	// Start server
	log.Printf("Server starting on port %s", cfg.ServerPort)
	if err := r.Run(":" + cfg.ServerPort); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
