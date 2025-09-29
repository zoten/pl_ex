defmodule PlEx.Version.CompatibilityTest do
  use ExUnit.Case, async: true

  alias PlEx.Version.Compatibility

  describe "supports?/2" do
    test "checks feature support correctly for different versions" do
      # Test with v1.1.1 connection
      connection_v1_1_1 = %{version: "1.1.1"}

      # Core features should be supported in all versions
      assert Compatibility.supports?(connection_v1_1_1, :library_sections)
      assert Compatibility.supports?(connection_v1_1_1, :media_metadata)
      assert Compatibility.supports?(connection_v1_1_1, :basic_search)

      # v1.2.0+ features should not be supported in v1.1.1
      refute Compatibility.supports?(connection_v1_1_1, :collections)
      refute Compatibility.supports?(connection_v1_1_1, :hubs)

      # Test with v1.2.0 connection
      connection_v1_2_0 = %{version: "1.2.0"}

      # Core features still supported
      assert Compatibility.supports?(connection_v1_2_0, :library_sections)
      assert Compatibility.supports?(connection_v1_2_0, :media_metadata)

      # v1.2.0+ features should be supported
      assert Compatibility.supports?(connection_v1_2_0, :collections)
      assert Compatibility.supports?(connection_v1_2_0, :hubs)

      # v1.3.0+ features should not be supported yet
      refute Compatibility.supports?(connection_v1_2_0, :smart_collections)
    end
  end

  describe "supports_version?/2" do
    test "correctly identifies version support for features" do
      # Core features
      assert Compatibility.supports_version?("1.1.1", :library_sections)
      assert Compatibility.supports_version?("1.2.0", :library_sections)
      assert Compatibility.supports_version?("1.3.0", :library_sections)

      # v1.2.0+ features
      refute Compatibility.supports_version?("1.1.1", :collections)
      assert Compatibility.supports_version?("1.2.0", :collections)
      assert Compatibility.supports_version?("1.3.0", :collections)

      # v1.3.0+ features
      refute Compatibility.supports_version?("1.1.1", :smart_collections)
      refute Compatibility.supports_version?("1.2.0", :smart_collections)
      assert Compatibility.supports_version?("1.3.0", :smart_collections)
    end
  end

  describe "supported_features/1" do
    test "returns correct features for different versions" do
      # Test v1.1.1
      connection_v1_1_1 = %{version: "1.1.1"}
      features_v1_1_1 = Compatibility.supported_features(connection_v1_1_1)

      # All versions should support core features
      assert :library_sections in features_v1_1_1
      assert :media_metadata in features_v1_1_1
      assert :basic_search in features_v1_1_1

      # v1.2.0+ features should not be in v1.1.1
      refute :collections in features_v1_1_1
      refute :hubs in features_v1_1_1

      # Test v1.2.0
      connection_v1_2_0 = %{version: "1.2.0"}
      features_v1_2_0 = Compatibility.supported_features(connection_v1_2_0)

      # Should have core + v1.2.0 features
      assert :library_sections in features_v1_2_0
      assert :collections in features_v1_2_0
      assert :hubs in features_v1_2_0

      # But not v1.3.0+ features
      refute :smart_collections in features_v1_2_0
    end
  end

  describe "deprecated?/2" do
    test "identifies deprecated features correctly" do
      # Test with v1.1.1 - library_on_deck should not be deprecated yet
      connection_v1_1_1 = %{version: "1.1.1"}
      assert Compatibility.deprecated?(connection_v1_1_1, :library_on_deck) == false

      # Test with v1.2.0 - library_on_deck should be deprecated
      connection_v1_2_0 = %{version: "1.2.0"}

      case Compatibility.deprecated?(connection_v1_2_0, :library_on_deck) do
        {:deprecated, info} ->
          assert info.replacement == :hubs
          assert info.deprecated_in == "1.2.0"

        false ->
          # This shouldn't happen in v1.2.0+
          flunk("library_on_deck should be deprecated in v1.2.0")
      end
    end
  end

  describe "compatibility_report/1" do
    test "generates comprehensive compatibility report" do
      connection = %{version: "1.2.0"}
      report = Compatibility.compatibility_report(connection)

      assert is_binary(report.version)
      assert is_list(report.supported_features)
      assert is_list(report.deprecated_features)
      assert is_list(report.missing_features)
      assert is_list(report.upgrade_recommendations)

      # Core features should always be supported
      assert :library_sections in report.supported_features
    end
  end

  describe "suggest_alternative/2" do
    test "suggests alternatives for unsupported features" do
      # Test collections support in v1.1.1 (not supported)
      connection_v1_1_1 = %{version: "1.1.1"}

      case Compatibility.suggest_alternative(connection_v1_1_1, :collections) do
        {:upgrade_required, required_version} ->
          assert required_version == "1.2.0"

        {:alternative, message} ->
          assert is_binary(message)

        :supported ->
          flunk("Collections should not be supported in v1.1.1")
      end

      # Test collections support in v1.2.0 (supported)
      connection_v1_2_0 = %{version: "1.2.0"}
      assert Compatibility.suggest_alternative(connection_v1_2_0, :collections) == :supported
    end
  end

  describe "required_version/1" do
    test "returns correct minimum version for features" do
      assert {:ok, "1.1.1"} = Compatibility.required_version(:library_sections)
      assert {:ok, "1.2.0"} = Compatibility.required_version(:collections)
      assert {:ok, "1.3.0"} = Compatibility.required_version(:smart_collections)

      assert {:error, :feature_not_found} = Compatibility.required_version(:nonexistent_feature)
    end
  end
end
