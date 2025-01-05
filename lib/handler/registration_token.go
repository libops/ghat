package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/google/go-github/v68/github"
)

func (h *Handler) RepoAdminToken(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(claimsKey).(GitHubClaims)
	if !ok {
		http.Error(w, "Unauthorized: missing claims in context", http.StatusUnauthorized)
		return
	}
	if claims.Repository == "" {
		http.Error(w, "Invalid request: repository claim is empty", http.StatusBadRequest)
		return
	}

	opts := &github.InstallationTokenOptions{
		Repositories: []string{
			claims.Repository,
		},
		Permissions: &github.InstallationPermissions{
			Administration: github.Ptr("write"),
		},
	}
	token, _, err := h.githubClient.Apps.CreateInstallationToken(r.Context(), h.githubInstallationId, opts)
	if err != nil {
		slog.Error("Error fetching scoped token", "err", err, "claims", claims)
		http.Error(w, "Internal error.", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]string{"token": token.GetToken()}); err != nil {
		slog.Error("Failed to encode response", "err", err, "claims", claims)
		http.Error(w, "Internal error.", http.StatusInternalServerError)
	}
}
