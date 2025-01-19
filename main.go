package main

import (
	"log/slog"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	"github.com/libops/ghat/lib/handler"
)

func main() {
	wh, err := handler.NewHandler()
	if err != nil {
		slog.Error("Failed to initialize handler", "error", err)
		os.Exit(1)
	}

	r := mux.NewRouter()
	r.HandleFunc("/healthcheck", func(w http.ResponseWriter, r *http.Request) {
		_, err := w.Write([]byte("ok"))
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			slog.Error("Unable to write for healthcheck", "error", err)
		}
	}).Methods("GET")

	authRouter := r.PathPrefix("/").Subrouter()
	authRouter.Use(handler.LoggingMiddleware)
	authRouter.Use(handler.JWTAuthMiddleware)
	authRouter.HandleFunc("/repo/admin", wh.RepoAdminToken).Methods("POST")
	authRouter.HandleFunc("/test", func(w http.ResponseWriter, r *http.Request) {
		_, err := w.Write([]byte(`ok`))
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			slog.Error("Unable to write for healthcheck", "error", err)
		}
	})
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	slog.Info("Server is starting", "port", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		slog.Error("Server failed", "err", err)
	}
}
