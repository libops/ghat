package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"
)

type contextKey string

const claimsKey contextKey = "claims"

const githubKeysURL = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"

func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		statusWriter := &statusRecorder{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}
		next.ServeHTTP(statusWriter, r)
		duration := time.Since(start)
		slog.Info("Incoming request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", statusWriter.statusCode,
			"duration", duration,
			"client_ip", r.RemoteAddr,
			"user_agent", r.UserAgent(),
		)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (rec *statusRecorder) WriteHeader(code int) {
	rec.statusCode = code
	rec.ResponseWriter.WriteHeader(code)
}

// JWTMiddleware validates a JWT token was passed by a GitHub Action
// and adds claims to the context
func JWTAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, "Missing or invalid Authorization header", http.StatusUnauthorized)
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")

		claims, err := verifyJWT(tokenString)
		if err != nil {
			slog.Error("JWT verification failed", "err", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), claimsKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func verifyJWT(tokenString string) (*GitHubClaims, error) {
	keySet, err := fetchJWKS()
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	token, err := jwt.Parse([]byte(tokenString), jwt.WithKeySet(keySet), jwt.WithContext(ctx))
	if err != nil {
		return nil, err
	}

	var claims GitHubClaims
	if err := validateClaims(token); err != nil {
		return nil, err
	}
	rawClaims, err := json.Marshal(token)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal claims: %v", err)
	}
	if err := json.Unmarshal(rawClaims, &claims); err != nil {
		return nil, fmt.Errorf("failed to unmarshal claims: %v", err)
	}

	return &claims, nil
}

func fetchJWKS() (jwk.Set, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	return jwk.Fetch(ctx, githubKeysURL)
}

func validateClaims(token jwt.Token) error {
	iss, ok := token.Get("iss")
	if !ok || iss != "https://token.actions.githubusercontent.com" {
		return fmt.Errorf("invalid issuer: %v", iss)
	}

	if time.Now().After(token.Expiration()) {
		return fmt.Errorf("token has expired")
	}

	ro, ok := token.Get("repository_owner")
	if !ok {
		return fmt.Errorf("repository_owner claim not found")
	}
	if strings.ToLower(ro.(string)) != "libops" {
		return fmt.Errorf("invalid repository_owner: %v", iss)
	}
	return nil
}
