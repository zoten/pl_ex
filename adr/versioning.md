# ADR: Plex API Versioning Strategy

**Status**: Accepted  
**Date**: 2025-09-25  
**Deciders**: Development Team  

## Context

The Plex Media Server API has evolved over time and continues to evolve, with different versions supporting different features and endpoints. We need a strategy to:

1. Support multiple Plex API versions without duplicating code
2. Maintain backward compatibility where possible
3. Minimize maintenance overhead when new API versions are released
4. Provide clear migration paths for users
5. Handle version-specific features gracefully

### Current Plex API Landscape

- **PMS API**: Uses semantic versioning (e.g., 1.1.1, 1.2.0, 1.3.0)
- **plex.tv API**: Uses v2 endpoints with incremental changes
- **Version Detection**: Available via `/` endpoint's `X-Plex-Pms-Api-Version` header
- **Feature Variations**: Different versions support different endpoints, parameters, and response formats

## Decision

We will implement a **version-adaptive architecture** with the following principles:

### 1. Single Codebase with Version Adapters

Instead of maintaining separate codebases per version, we'll use a single codebase with version-specific adapters that handle differences.

```elixir
# Core API remains version-agnostic
PlEx.request(:pms, :get, "/library/sections", [])

# Version-specific behavior handled internally
PlEx.Library.get_sections([version: "1.2.0"])
```

### 2. Version Detection and Negotiation

Automatic version detection with fallback strategies:

```elixir
defmodule PlEx.Version do
  @supported_versions ["1.1.1", "1.2.0", "1.3.0"]
  
  def detect_server_version(connection) do
    # Detect from server response headers
    # Fall back to feature probing if needed
  end
  
  def negotiate_version(detected, requested \\ :latest) do
    # Choose best compatible version
  end
end
```

### 3. Feature-Based Compatibility Layer

Use feature flags instead of version checks where possible:

```elixir
defmodule PlEx.Features do
  def supports?(connection, :collections), do: version_gte(connection, "1.2.0")
  def supports?(connection, :smart_collections), do: version_gte(connection, "1.3.0")
  def supports?(connection, :webhooks_v2), do: version_gte(connection, "1.2.5")
end
```

### 4. Modular API Modules

Organize API functionality into modules that can adapt to version differences:

```
lib/pl_ex/
├── api/
│   ├── library.ex          # Library management
│   ├── media.ex            # Media operations  
│   ├── collections.ex      # Collections (v1.2.0+)
│   ├── webhooks.ex         # Webhook management
│   └── admin.ex            # Server administration
├── version/
│   ├── adapter.ex          # Version adaptation logic
│   ├── compatibility.ex    # Compatibility checks
│   └── migration.ex        # Migration helpers
└── schemas/
    ├── v1_1_1/            # Version-specific schemas
    ├── v1_2_0/
    └── common/            # Shared schemas
```

### 5. Schema Versioning Strategy

Use versioned schemas with automatic adaptation:

```elixir
defmodule PlEx.Schemas.Library do
  @derive Jason.Encoder
  defstruct [:key, :title, :type, :agent, :scanner, :language, :uuid, :created_at, :updated_at]
  
  def from_api_response(data, version) do
    case version do
      v when v >= "1.2.0" -> from_v1_2_0(data)
      v when v >= "1.1.1" -> from_v1_1_1(data)
    end
  end
end
```

## Implementation Strategy

### Phase 1: Foundation (Current)
- ✅ Core transport and authentication
- ✅ Version detection infrastructure
- ✅ Basic compatibility layer

### Phase 2: API Modules
- Implement core API modules (Library, Media, etc.)
- Add version adapters for each module
- Create comprehensive test suite with version matrix

### Phase 3: Advanced Features
- Schema migration helpers
- Deprecation warnings
- Feature detection and graceful degradation

### Testing Strategy

#### Version Matrix Testing

```elixir
# test/support/version_matrix.ex
defmodule PlEx.Test.VersionMatrix do
  @supported_versions ["1.1.1", "1.2.0", "1.3.0"]
  
  defmacro test_across_versions(name, do: block) do
    for version <- @supported_versions do
      quote do
        test "#{unquote(name)} (v#{unquote(version)})" do
          PlEx.Test.MockServer.set_version(unquote(version))
          unquote(block)
        end
      end
    end
  end
end

# Usage in tests
defmodule PlEx.LibraryTest do
  use PlEx.Test.VersionMatrix
  
  test_across_versions "gets library sections" do
    {:ok, sections} = PlEx.Library.get_sections()
    assert is_list(sections)
  end
end
```

#### Mock Server with Version Support

```elixir
defmodule PlEx.Test.MockServer do
  def set_version(version) do
    # Configure mock responses for specific version
  end
  
  def with_version(version, fun) do
    old_version = get_version()
    set_version(version)
    try do
      fun.()
    after
      set_version(old_version)
    end
  end
end
```

### Documentation Strategy

#### Version-Aware Documentation

```elixir
@doc """
Gets all library sections from the Plex Media Server.

## Version Compatibility
- v1.1.1+: Basic library listing
- v1.2.0+: Includes collection counts
- v1.3.0+: Includes smart collection support

## Examples

    # Basic usage (works on all versions)
    {:ok, sections} = PlEx.Library.get_sections()
    
    # Version-specific features
    {:ok, sections} = PlEx.Library.get_sections(include_collections: true)  # v1.2.0+
"""
```

#### Migration Guides

Provide clear migration paths when breaking changes occur:

```markdown
## Migrating from v1.1.1 to v1.2.0

### New Features
- Collections API support
- Enhanced metadata fields

### Breaking Changes
- `library_section` field renamed to `section` in responses
- Deprecated endpoints: `/library/onDeck` (use `/hubs/home/onDeck`)

### Migration Steps
1. Update PlEx to v0.3.0+
2. Replace deprecated endpoint calls
3. Update response parsing for renamed fields
```

## Benefits

### Reduced Maintenance Overhead
- Single codebase to maintain
- Automated compatibility testing
- Shared infrastructure across versions

### Better User Experience
- Automatic version detection
- Graceful feature degradation
- Clear upgrade paths

### Future-Proof Architecture
- Easy to add new API versions
- Modular design allows selective updates
- Feature-based compatibility reduces version coupling

## Risks and Mitigations

### Risk: Version Detection Failures
**Mitigation**: Implement robust fallback mechanisms and manual version override options.

### Risk: Breaking Changes in New Versions
**Mitigation**: Comprehensive test matrix and feature flags to isolate breaking changes.

### Risk: Complexity Growth
**Mitigation**: Keep version-specific code minimal and well-documented. Regular refactoring to consolidate common patterns.

## Alternatives Considered

### Separate Packages Per Version
**Rejected**: Would lead to code duplication and maintenance burden.

### Version-Specific Branches
**Rejected**: Makes cross-version bug fixes and feature backports difficult.

### Client-Side Version Selection Only
**Rejected**: Puts too much burden on users to understand version differences.

## Implementation Timeline

- **Week 1-2**: Version detection and compatibility infrastructure
- **Week 3-4**: Core API modules with version adapters
- **Week 5-6**: Comprehensive test matrix and documentation
- **Week 7+**: Advanced features and migration tools

## Success Metrics

- Support for 3+ Plex API versions simultaneously
- <10% code duplication across version adapters
- 95%+ test coverage across version matrix
- Zero breaking changes for users when adding new API version support

---

This ADR establishes a sustainable approach to handling Plex API versioning that balances maintainability, user experience, and future extensibility.