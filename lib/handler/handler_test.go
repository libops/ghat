package handler

import (
	"os"
	"testing"
)

func TestLoadEnv(t *testing.T) {
	key := "TEST_ENV_VAR"
	expectedValue := "test-value"
	os.Setenv(key, expectedValue)
	defer os.Unsetenv(key)
	if value := loadEnv(key); value != expectedValue {
		t.Fatalf("expected %s but got %s", expectedValue, value)
	}
}

func TestMissingEnv(t *testing.T) {
	missingKey := "MISSING_ENV_VAR"
	os.Unsetenv(missingKey)
	defer func() {
		if r := recover(); r == nil {
			t.Fatalf("expected loadEnv to panic when environment variable is missing")
		}
	}()
	loadEnv(missingKey)
}
