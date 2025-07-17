package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"

	"github.com/google/go-github/v73/github"
)

func (h *Handler) RepoAdminToken(w http.ResponseWriter, r *http.Request) {
	claims := r.Context().Value(claimsKey).(GitHubClaims)
	if claims.Repository == "" {
		http.Error(w, "Invalid request: repository claim is empty", http.StatusBadRequest)
		return
	}

	opts := &github.InstallationTokenOptions{
		Repositories: []string{
			strings.Split(claims.Repository, "/")[1],
		},
		Permissions: &github.InstallationPermissions{
			Administration: github.Ptr("write"),
			Secrets:        github.Ptr("write"),
		},
	}
	token, _, err := h.githubClient.Apps.CreateInstallationToken(r.Context(), h.githubInstallationId, opts)
	if err != nil {
		slog.Error("Error fetching scoped token", "err", err, "claims", claims, "opts", opts)
		http.Error(w, "Internal error.", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]string{"token": token.GetToken()}); err != nil {
		slog.Error("Failed to encode response", "err", err, "claims", claims)
		http.Error(w, "Internal error.", http.StatusInternalServerError)
	}
}
