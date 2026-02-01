package config

import (
	"os"
)

type Config struct {
	MongoURI   string
	DBName     string
	JWTSecret  string
	ServerPort string
}

func Load() *Config {
	return &Config{
		MongoURI:   getEnv("MONGO_URI", "mongodb+srv://guptabhavin60_db_user:ce1wZlthNh7Az70u@cluster0.udf3awx.mongodb.net/"),
		DBName:     getEnv("DB_NAME", "valet_parking"),
		JWTSecret:  getEnv("JWT_SECRET", "your-secret-key-change-in-production"),
		ServerPort: getEnv("SERVER_PORT", "8080"),
	}
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
