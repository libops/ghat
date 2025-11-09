package handler

import (
	"fmt"
	"net/http"
	"os"
	"strconv"

	"github.com/bradleyfalzon/ghinstallation/v2"
	"github.com/google/go-github/v78/github"
)

type GitHubClaims struct {
	Iss                  string `json:"iss"`
	Sub                  string `json:"sub"`
	Repository           string `json:"repository"`
	RepositoryOwner      string `json:"repository_owner"`
	RepositoryVisibility string `json:"repository_visibility"`
	Actor                string `json:"actor"`
	Workflow             string `json:"workflow"`
	Ref                  string `json:"ref"`
	SHA                  string `json:"sha"`
	EventName            string `json:"event_name"`
	Exp                  int64  `json:"exp"`
}

type Handler struct {
	githubClient         *github.Client
	githubAppId          int64
	githubInstallationId int64
}

func NewHandler() (*Handler, error) {
	appId := loadEnvInt64("GITHUB_APP_ID")
	installationId := loadEnvInt64("GITHUB_INSTALL_ID")
	privateKeyPath := loadEnv("GITHUB_APP_PRIVATE_KEY")
	tr := http.DefaultTransport
	itr, err := ghinstallation.NewAppsTransportKeyFromFile(tr, appId, privateKeyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create installation transport: %v", err)
	}

	return &Handler{
		githubClient:         github.NewClient(&http.Client{Transport: itr}),
		githubAppId:          appId,
		githubInstallationId: installationId,
	}, nil
}

func loadEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		panic(fmt.Sprintf("Environment variable not set: %s", key))
	}
	return v
}

func loadEnvInt64(key string) int64 {
	v := loadEnv(key)
	n, err := strconv.ParseInt(v, 10, 64)
	if err != nil {
		panic(fmt.Sprintf("Environment variable not an int: %s", key))
	}
	return n
}
