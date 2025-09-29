defmodule PlEx.Performance do
  @moduledoc """
  Performance monitoring and optimization utilities for PlEx.

  Provides tools to monitor request performance, detect bottlenecks,
  and optimize common operations.
  """

  require Logger

  @doc """
  Measures the execution time of a function and logs performance metrics.

  ## Examples

      PlEx.Performance.measure("library_sections", fn ->
        PlEx.API.Library.get_sections()
      end)
  """
  def measure(operation_name, fun) when is_function(fun, 0) do
    start_time = System.monotonic_time(:microsecond)

    try do
      result = fun.()
      end_time = System.monotonic_time(:microsecond)
      duration_ms = (end_time - start_time) / 1000

      log_performance(operation_name, duration_ms, :success)
      result
    rescue
      error ->
        end_time = System.monotonic_time(:microsecond)
        duration_ms = (end_time - start_time) / 1000

        log_performance(operation_name, duration_ms, :error)
        reraise error, __STACKTRACE__
    end
  end

  @doc """
  Measures pagination performance and provides optimization suggestions.
  """
  def measure_pagination(operation_name, total_items, page_count, duration_ms) do
    items_per_second = total_items / (duration_ms / 1000)
    avg_page_time = duration_ms / page_count

    Logger.info([
      "Pagination Performance: ",
      operation_name,
      " - #{total_items} items, #{page_count} pages, ",
      "#{Float.round(duration_ms, 2)}ms total, ",
      "#{Float.round(items_per_second, 0)} items/sec, ",
      "#{Float.round(avg_page_time, 2)}ms/page"
    ])

    # Provide optimization suggestions
    cond do
      avg_page_time > 1000 ->
        Logger.warning(
          "Slow pagination detected. Consider increasing page size or checking network latency."
        )

      items_per_second < 50 ->
        Logger.warning(
          "Low throughput detected. Consider connection pooling or concurrent requests."
        )

      true ->
        :ok
    end
  end

  @doc """
  Analyzes memory usage patterns and suggests optimizations.
  """
  def analyze_memory_usage do
    memory_info = :erlang.memory()

    %{
      total: memory_info[:total],
      processes: memory_info[:processes],
      system: memory_info[:system],
      atom: memory_info[:atom],
      binary: memory_info[:binary],
      ets: memory_info[:ets]
    }
  end

  @doc """
  Provides performance recommendations based on current configuration.
  """
  def performance_recommendations do
    recommendations = []

    # Check cache TTL
    recommendations =
      case PlEx.Config.cache_ttl() do
        ttl when ttl < 60 ->
          [
            "Consider increasing cache_ttl (currently #{ttl}s) for better performance"
            | recommendations
          ]

        _ ->
          recommendations
      end

    # Check connection pool size
    recommendations =
      case PlEx.Config.connection_pool_size() do
        size when size < 5 ->
          [
            "Consider increasing connection_pool_size (currently #{size}) for concurrent requests"
            | recommendations
          ]

        _ ->
          recommendations
      end

    # Check retry configuration
    recommendations =
      case PlEx.Config.retries() do
        retries when retries > 5 ->
          [
            "Consider reducing retries (currently #{retries}) to avoid excessive delays"
            | recommendations
          ]

        _ ->
          recommendations
      end

    if Enum.empty?(recommendations) do
      ["Configuration looks optimal for performance"]
    else
      recommendations
    end
  end

  @doc """
  Benchmarks common operations and returns performance metrics.
  """
  def benchmark_operations do
    operations = [
      {"Header Building", fn -> PlEx.Config.plex_headers() end},
      {"Config Access", fn -> PlEx.Config.client_identifier() end},
      {"Storage Get",
       fn ->
         storage = PlEx.Config.storage()
         storage.get(:test_key)
       end}
    ]

    Enum.map(operations, fn {name, fun} ->
      # Warm up
      fun.()

      # Benchmark
      times =
        for _ <- 1..1000 do
          start = System.monotonic_time(:microsecond)
          fun.()
          System.monotonic_time(:microsecond) - start
        end

      avg_time = Enum.sum(times) / length(times)
      min_time = Enum.min(times)
      max_time = Enum.max(times)

      %{
        operation: name,
        avg_microseconds: Float.round(avg_time, 2),
        min_microseconds: min_time,
        max_microseconds: max_time,
        ops_per_second: Float.round(1_000_000 / avg_time, 0)
      }
    end)
  end

  # Private functions

  defp log_performance(operation, duration_ms, status) do
    level =
      case {status, duration_ms} do
        {:error, _} -> :error
        {_, ms} when ms > 5000 -> :warning
        {_, ms} when ms > 1000 -> :info
        _ -> :debug
      end

    Logger.log(level, [
      "Performance: ",
      operation,
      " completed in #{Float.round(duration_ms, 2)}ms ",
      "(#{status})"
    ])
  end
end
