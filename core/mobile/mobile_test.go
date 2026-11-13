package mobile

import (
	"path/filepath"
	"testing"

	"github.com/thisisvista/vista-vpn/core/internal/config"
)

func TestUseAndroidDashboardPortMigratesDefault(t *testing.T) {
	path := filepath.Join(t.TempDir(), config.FileName)
	if err := config.Save(path, config.Default()); err != nil {
		t.Fatal(err)
	}

	if err := useAndroidDashboardPort(path); err != nil {
		t.Fatal(err)
	}

	got, _, err := config.Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if got.Dashboard.Listen != androidDashboardListen {
		t.Fatalf("dashboard listen = %q, want %q", got.Dashboard.Listen, androidDashboardListen)
	}
}

func TestUseAndroidDashboardPortPreservesCustomAddress(t *testing.T) {
	path := filepath.Join(t.TempDir(), config.FileName)
	cfg := config.Default()
	cfg.Dashboard.Listen = "127.0.0.1:11999"
	if err := config.Save(path, cfg); err != nil {
		t.Fatal(err)
	}

	if err := useAndroidDashboardPort(path); err != nil {
		t.Fatal(err)
	}

	got, _, err := config.Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if got.Dashboard.Listen != cfg.Dashboard.Listen {
		t.Fatalf("dashboard listen = %q, want preserved value %q", got.Dashboard.Listen, cfg.Dashboard.Listen)
	}
}
