defmodule PlEx.Version.DetectorTest do
  use ExUnit.Case, async: true

  alias PlEx.Version.Detector

  # For now, let's test the core functionality without HTTP complexity
  # We'll add integration tests later when we have proper mock setup

  describe "supported_version?/1" do
    test "returns true for supported versions" do
      assert Detector.supported_version?("1.1.1")
      assert Detector.supported_version?("1.2.0")
      assert Detector.supported_version?("1.3.0")
    end

    test "returns false for unsupported versions" do
      refute Detector.supported_version?("1.0.0")
      refute Detector.supported_version?("2.0.0")
      refute Detector.supported_version?("invalid")
    end
  end

  describe "supported_versions/0" do
    test "returns list of supported versions" do
      versions = Detector.supported_versions()

      assert is_list(versions)
      assert "1.1.1" in versions
      assert "1.2.0" in versions
      assert "1.3.0" in versions
    end
  end

  describe "default_version/0" do
    test "returns default fallback version" do
      assert "1.1.1" = Detector.default_version()
    end
  end

  describe "detect_server_version/2 with fallback" do
    test "falls back to default version on detection failure" do
      # Simulate a connection that fails version detection
      bad_connection = %{base_url: "http://invalid", access_token: "invalid"}

      assert {:ok, "1.1.1"} = Detector.detect_server_version(bad_connection, fallback: true)
    end

    test "returns error when fallback is disabled" do
      bad_connection = %{base_url: "http://invalid", access_token: "invalid"}

      assert {:error, _} = Detector.detect_server_version(bad_connection, fallback: false)
    end
  end
end
