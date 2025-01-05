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

const githubKeysURL = "https://token.actions.githubusercontent.com/.well-known/jwks"

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
		return nil, fmt.Errorf("Unable to fetch JWKS: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	token, err := jwt.Parse(
		[]byte(tokenString),
		jwt.WithKeySet(keySet),
		jwt.WithContext(ctx),
		jwt.WithVerify(true))
	if err != nil {
		return nil, fmt.Errorf("Unable to parse token: %v", err)
	}

	if err := validateClaims(token); err != nil {
		return nil, fmt.Errorf("Unable to validate claims: %v", err)
	}
	rawClaims, err := json.Marshal(token)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal claims: %v", err)
	}

	var claims GitHubClaims
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

	claims := map[string]string{
		"aud":              "https://github.com/libops",
		"repository_owner": "libops",
	}
	for c, expectedValue := range claims {
		claim, ok := token.Get(c)
		if !ok {
			return fmt.Errorf("%s claim not found", c)
		}
		found := false
		switch v := claim.(type) {
		case string:
			if strings.ToLower(v) == expectedValue {
				found = true
			}
		case []string:
			for _, claimValue := range v {
				if strings.ToLower(claimValue) == expectedValue {
					found = true
					break
				}
			}
		}
		if !found {
			return fmt.Errorf("invalid %s: %v", c, claim)
		}
	}

	return nil
}
