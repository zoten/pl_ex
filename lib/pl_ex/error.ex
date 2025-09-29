defmodule PlEx.Error do
  @moduledoc """
  Standardized error types for PlEx.

  This module defines consistent error structures across the entire SDK
  to provide better error handling and debugging experience.
  """

  @type error_type ::
          :http_error
          | :auth_error
          | :config_error
          | :crypto_error
          | :network_error
          | :timeout_error
          | :invalid_response
          | :not_found

  @type t :: {error_type(), term()} | {error_type(), term(), map()}

  # HTTP-related errors
  def http_error(status, body), do: {:http_error, %{status: status, body: body}}
  def http_error(status, body, details), do: {:http_error, %{status: status, body: body}, details}

  # Authentication errors
  def auth_error(reason), do: {:auth_error, reason}
  def auth_error(reason, details), do: {:auth_error, reason, details}

  # Configuration errors
  def config_error(reason), do: {:config_error, reason}
  def config_error(reason, details), do: {:config_error, reason, details}

  # Cryptography errors
  def crypto_error(reason), do: {:crypto_error, reason}
  def crypto_error(reason, details), do: {:crypto_error, reason, details}

  # Network errors
  def network_error(reason), do: {:network_error, reason}
  def network_error(reason, details), do: {:network_error, reason, details}

  # Timeout errors
  def timeout_error(reason), do: {:timeout_error, reason}
  def timeout_error(reason, details), do: {:timeout_error, reason, details}

  # Invalid response errors
  def invalid_response(reason), do: {:invalid_response, reason}
  def invalid_response(reason, details), do: {:invalid_response, reason, details}

  # Not found errors
  def not_found(reason), do: {:not_found, reason}
  def not_found(reason, details), do: {:not_found, reason, details}

  @doc """
  Wraps an existing error with additional context.
  """
  def wrap(error, context) when is_binary(context) do
    case error do
      {type, reason} -> {type, reason, %{context: context}}
      {type, reason, details} -> {type, reason, Map.put(details, :context, context)}
      other -> other
    end
  end

  @doc """
  Extracts a human-readable message from an error.
  """
  def message({:http_error, %{status: status, body: body}}) do
    "HTTP #{status}: #{inspect(body)}"
  end

  def message({:http_error, %{status: status, body: body}, _details}) do
    "HTTP #{status}: #{inspect(body)}"
  end

  def message({:auth_error, reason}) do
    "Authentication failed: #{inspect(reason)}"
  end

  def message({:auth_error, reason, _details}) do
    "Authentication failed: #{inspect(reason)}"
  end

  def message({:config_error, reason}) do
    "Configuration error: #{inspect(reason)}"
  end

  def message({:config_error, reason, _details}) do
    "Configuration error: #{inspect(reason)}"
  end

  def message({:crypto_error, reason}) do
    "Cryptography error: #{inspect(reason)}"
  end

  def message({:crypto_error, reason, _details}) do
    "Cryptography error: #{inspect(reason)}"
  end

  def message({:network_error, reason}) do
    "Network error: #{inspect(reason)}"
  end

  def message({:network_error, reason, _details}) do
    "Network error: #{inspect(reason)}"
  end

  def message({:timeout_error, reason}) do
    "Timeout: #{inspect(reason)}"
  end

  def message({:timeout_error, reason, _details}) do
    "Timeout: #{inspect(reason)}"
  end

  def message({:invalid_response, reason}) do
    "Invalid response: #{inspect(reason)}"
  end

  def message({:invalid_response, reason, _details}) do
    "Invalid response: #{inspect(reason)}"
  end

  def message({:not_found, reason}) do
    "Not found: #{inspect(reason)}"
  end

  def message({:not_found, reason, _details}) do
    "Not found: #{inspect(reason)}"
  end

  def message(other) do
    "Unknown error: #{inspect(other)}"
  end

  @doc """
  Checks if an error is retryable based on its type and details.
  """
  def retryable?({:http_error, %{status: status}}) when status in [429, 500, 502, 503, 504],
    do: true

  def retryable?({:http_error, %{status: status}, _}) when status in [429, 500, 502, 503, 504],
    do: true

  def retryable?({:network_error, _}), do: true
  def retryable?({:network_error, _, _}), do: true
  def retryable?({:timeout_error, _}), do: true
  def retryable?({:timeout_error, _, _}), do: true
  def retryable?(_), do: false

  @doc """
  Checks if an error indicates authentication issues.
  """
  def auth_error?({:http_error, %{status: status}}) when status in [401, 498], do: true
  def auth_error?({:http_error, %{status: status}, _}) when status in [401, 498], do: true
  def auth_error?({:auth_error, _}), do: true
  def auth_error?({:auth_error, _, _}), do: true
  def auth_error?(_), do: false
end
