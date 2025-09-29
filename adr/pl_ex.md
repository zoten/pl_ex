# PlEx, an Elixir Plex SDK

[Plex](https://www.plex.tv) has publicly shared their API.

We want to create a library that is both flexible, ergonomic and maintainable, all while leveraging Elixir's best capabilities (concurrency, fault tolerance etc).

The SDK should:

 * support custom HTTP clients through a common Behaviour and implement basic behaviours adapters for the most common Elixir HTTP libraries (Finch, Mint, Tesla, :hackney at least)
 * support multiple Json libraries (Jason, Poison and Elixir's built in JSON module from version 1.18 OTP 27 only)
 * support multiple OpenApi specification versions at the same time, starting from the current 1.1.1 but ready for other future implementations. The versioning should be ergonomically maintainable (e.g. patch versions that only add methods should be handled by the same unit of code, not duplicating old one)
 * usage should be via use macro, e.g.
   ``` elixir
   defmodule MyPlex do
     use PlEx,
       version: "1.1.1",
       http_adapter: MintAdapter
   ```
 * should use [Open API Spex library](https://hexdocs.pm/open_api_spex/readme.html) goodies
 * Open Api specifications can be found at [../openapi](../openapi/) folder