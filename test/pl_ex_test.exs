defmodule PlExTest do
  use ExUnit.Case
  doctest PlEx

  test "provides main module functionality" do
    # Test that the main PlEx module has the convenience functions
    assert function_exported?(PlEx, :get_library_sections, 0)
    assert function_exported?(PlEx, :get_library_sections, 1)
    assert function_exported?(PlEx, :get_media_metadata, 1)
    assert function_exported?(PlEx, :search, 1)
  end

  test "use PlEx macro compiles successfully" do
    # Test that the macro can be used without compilation errors
    defmodule TestClient do
      use PlEx

      def test_function do
        # This should compile without errors, demonstrating that the imports work
        :ok
      end
    end

    # Test that the module compiles and has our test function
    assert function_exported?(TestClient, :test_function, 0)
    assert TestClient.test_function() == :ok
  end

  test "use PlEx macro allows direct API calls" do
    defmodule TestApp do
      use PlEx

      def test_library_access do
        # These should compile without errors (though they may fail at runtime without proper setup)
        case get_library_sections() do
          {:ok, _sections} -> :ok
          {:error, _reason} -> :ok
        end
      end

      def test_media_access do
        case get_media_metadata("12345") do
          {:ok, _metadata} -> :ok
          {:error, _reason} -> :ok
        end
      end

      def test_search_access do
        case search("batman") do
          {:ok, _results} -> :ok
          {:error, _reason} -> :ok
        end
      end
    end

    # Test that the functions exist and can be called
    assert function_exported?(TestApp, :test_library_access, 0)
    assert function_exported?(TestApp, :test_media_access, 0)
    assert function_exported?(TestApp, :test_search_access, 0)
  end
end
