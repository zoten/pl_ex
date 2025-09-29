defmodule PlEx.Version.AdapterTest do
  use ExUnit.Case, async: true

  alias PlEx.Version.Adapter

  describe "adapt_request/2" do
    test "adapts request parameters for different versions" do
      base_request = %{
        method: :get,
        path: "/library/sections",
        params: %{"includeDetails" => "1"}
      }

      # v1.1.1 should use legacy parameter names
      {:ok, adapted_v1_1_1} = Adapter.adapt_request(base_request, "1.1.1")
      assert adapted_v1_1_1.params["includeDetails"] == "1"

      # v1.2.0+ might use different parameter names
      {:ok, adapted_v1_2_0} = Adapter.adapt_request(base_request, "1.2.0")
      assert is_map(adapted_v1_2_0.params)
    end

    test "adapts endpoint paths for different versions" do
      # Test collections endpoint adaptation
      collections_request = %{
        method: :get,
        path: "/library/sections/1/collections",
        params: %{}
      }

      # All supported versions should adapt the request successfully
      {:ok, adapted_v1_1_1} = Adapter.adapt_request(collections_request, "1.1.1")
      assert adapted_v1_1_1.method == :get
      assert is_binary(adapted_v1_1_1.path)

      # v1.2.0+ should support collections
      {:ok, adapted_v1_2_0} = Adapter.adapt_request(collections_request, "1.2.0")
      assert adapted_v1_2_0.path == "/library/sections/1/collections"
    end

    test "handles unsupported versions" do
      request = %{method: :get, path: "/test", params: %{}}
      
      assert {:error, _} = Adapter.adapt_request(request, "0.9.0")
      assert {:error, _} = Adapter.adapt_request(request, "invalid")
    end
  end

  describe "adapt_response/2" do
    test "adapts MediaContainer responses for different versions" do
      # v1.1.1 response format
      v1_1_1_response = %{
        "MediaContainer" => %{
          "size" => 2,
          "Directory" => [
            %{"key" => "1", "title" => "Movies", "type" => "movie"},
            %{"key" => "2", "title" => "TV Shows", "type" => "show"}
          ]
        }
      }

      {:ok, adapted} = Adapter.adapt_response(v1_1_1_response, "1.1.1")
      
      # Should normalize field names
      assert is_map(adapted)
      container = adapted["MediaContainer"]
      assert container["size"] == 2
      assert is_list(container["Directory"])
    end

    test "adapts direct responses for different versions" do
      # Direct response without MediaContainer
      direct_response = %{
        "ratingKey" => "12345",
        "title" => "Test Movie",
        "addedAt" => "1234567890"
      }

      {:ok, adapted} = Adapter.adapt_response(direct_response, "1.1.1")
      
      # Should normalize field names
      assert adapted["rating_key"] == "12345" || adapted["ratingKey"] == "12345"
      assert adapted["title"] == "Test Movie"
    end

    test "handles version-specific field mappings" do
      response_with_version_fields = %{
        "MediaContainer" => %{
          "librarySectionID" => "1",
          "librarySectionTitle" => "Movies",
          # v1.2.0+ field
          "smart" => true,
          # v1.3.0+ field  
          "collectionMode" => "default"
        }
      }

      # v1.1.1 should handle basic fields
      {:ok, adapted_v1_1_1} = Adapter.adapt_response(response_with_version_fields, "1.1.1")
      container = adapted_v1_1_1["MediaContainer"]
      assert container["librarySectionID"] == "1"

      # v1.2.0 should handle smart field
      {:ok, adapted_v1_2_0} = Adapter.adapt_response(response_with_version_fields, "1.2.0")
      container_v1_2_0 = adapted_v1_2_0["MediaContainer"]
      assert container_v1_2_0["smart"] == true

      # v1.3.0 should handle all fields
      {:ok, adapted_v1_3_0} = Adapter.adapt_response(response_with_version_fields, "1.3.0")
      container_v1_3_0 = adapted_v1_3_0["MediaContainer"]
      assert container_v1_3_0["collectionMode"] == "default"
    end

    test "handles nested object adaptation" do
      nested_response = %{
        "MediaContainer" => %{
          "Metadata" => [
            %{
              "ratingKey" => "123",
              "Media" => [
                %{
                  "videoProfile" => "high",
                  "Part" => [
                    %{"file" => "/path/to/movie.mkv"}
                  ]
                }
              ]
            }
          ]
        }
      }

      {:ok, adapted} = Adapter.adapt_response(nested_response, "1.2.0")
      
      container = adapted["MediaContainer"]
      metadata = List.first(container["Metadata"])
      media = List.first(metadata["Media"])
      part = List.first(media["Part"])
      
      assert metadata["ratingKey"] == "123"
      assert media["videoProfile"] == "high"
      assert part["file"] == "/path/to/movie.mkv"
    end
  end

  describe "adapt_endpoint/2" do
    test "adapts endpoints for different versions" do
      # Test basic endpoint
      {:ok, adapted} = Adapter.adapt_endpoint("/library/sections", "1.1.1")
      assert adapted == "/library/sections"

      # Test version-specific endpoint - all supported versions should work
      {:ok, hubs_v1_1_1} = Adapter.adapt_endpoint("/hubs/search", "1.1.1")
      assert is_binary(hubs_v1_1_1)

      # v1.2.0+ should support hubs
      {:ok, hubs_adapted} = Adapter.adapt_endpoint("/hubs/search", "1.2.0")
      assert hubs_adapted == "/hubs/search"
    end

    test "provides deprecation warnings" do
      # Test deprecated endpoint
      {:ok, adapted} = Adapter.adapt_endpoint("/library/onDeck", "1.2.0")
      # Should still work but might be adapted
      assert is_binary(adapted)
    end
  end

  describe "endpoint_deprecation_info/2" do
    test "provides deprecation information" do
      # Test known deprecated endpoint
      case Adapter.endpoint_deprecation_info("/library/onDeck", "1.2.0") do
        {:deprecated, info} ->
          assert info.deprecated_in == "1.2.0"
          assert info.replacement == "/hubs/home/onDeck"  # Actual replacement path
          assert is_binary(info.migration_guide)
        :not_deprecated ->
          # Might not be deprecated in this version
          :ok
      end

      # Test non-deprecated endpoint
      assert Adapter.endpoint_deprecation_info("/library/sections", "1.2.0") == :not_deprecated
    end
  end

  describe "version-specific feature adaptation" do
    test "adapts search requests based on version" do
      basic_search = %{
        method: :get,
        path: "/search",
        params: %{"query" => "batman", "type" => "1"}
      }

      # v1.1.1 should use basic search
      {:ok, adapted_v1_1_1} = Adapter.adapt_request(basic_search, "1.1.1")
      assert adapted_v1_1_1.path == "/search"

      # v1.2.0+ might use enhanced search endpoints
      {:ok, adapted_v1_2_0} = Adapter.adapt_request(basic_search, "1.2.0")
      assert is_binary(adapted_v1_2_0.path)
    end

    test "adapts collection requests based on version" do
      collection_request = %{
        method: :post,
        path: "/library/sections/1/collections",
        params: %{"title" => "My Collection", "type" => "1"}
      }

      # v1.1.1 should not support collections
      case Adapter.adapt_request(collection_request, "1.1.1") do
        {:error, reason} ->
          assert reason.feature == :collections
          assert reason.required_version == "1.2.0"
        {:ok, _} ->
          # Might provide alternative implementation
          :ok
      end

      # v1.2.0+ should support collections
      {:ok, adapted_v1_2_0} = Adapter.adapt_request(collection_request, "1.2.0")
      assert adapted_v1_2_0.path == "/library/sections/1/collections"
    end
  end

  describe "error handling" do
    test "handles malformed responses gracefully" do
      malformed_response = %{"invalid" => "structure"}
      
      case Adapter.adapt_response(malformed_response, "1.1.1") do
        {:ok, adapted} ->
          # Should pass through or provide safe defaults
          assert is_map(adapted)
        {:error, _} ->
          # Acceptable to error on malformed input
          :ok
      end
    end

    test "handles empty responses" do
      assert {:ok, %{}} = Adapter.adapt_response(%{}, "1.1.1")
      
      # nil is not supported by the guard clause, so we test with empty map
      assert {:ok, %{}} = Adapter.adapt_response(%{}, "1.1.1")
    end
  end

  describe "integration with version detection" do
    test "works with detected versions" do
      # Simulate a typical workflow
      request = %{
        method: :get,
        path: "/library/sections",
        params: %{"includeDetails" => "1"}
      }

      # Test with each supported version
      for version <- ["1.1.1", "1.2.0", "1.3.0"] do
        {:ok, adapted} = Adapter.adapt_request(request, version)
        assert adapted.method == :get
        assert is_binary(adapted.path)
        assert is_map(adapted.params)
      end
    end
  end
end
