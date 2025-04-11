# Core System Architecture

## Overview
The core system is built around a modular, plugin-based architecture that enables efficient service management, state handling, and navigation. The system is designed to be extensible, maintainable, and performant.

## Core Components

### 1. Managers
The system uses several manager classes to handle different aspects of the application:

#### Module Manager
- Singleton pattern implementation
- Handles module registration and retrieval
- Supports multiple instances of the same module type
- Key features:
  - `registerModule()`: Registers a module with optional instance key
  - `getModuleInstance()`: Retrieves specific module instance
  - `getLatestModule()`: Gets the most recent instance of a module type
  - `deregisterModule()`: Removes module instances
  - `disposeModules()`: Cleans up all modules

#### Plugin Manager
- Manages plugin lifecycle and initialization
- Supports hook registration for cross-plugin communication
- Key features:
  - `registerPlugin()`: Registers and initializes plugins
  - `initializePlugins()`: Sets up all required plugins
  - `getPlugin()`: Retrieves plugin instances
  - Hook system for inter-plugin communication

#### Services Manager
- Singleton pattern implementation
- Handles service registration and lifecycle
- Key features:
  - `autoRegisterAllServices()`: Registers default services
  - `registerService()`: Adds new services
  - `getService()`: Retrieves service instances
  - Automatic service initialization

### 2. Base Classes
Located in `00_base/`, these provide foundation for the system:

- `ModuleBase`: Base class for all modules
- `PluginBase`: Foundation for plugin implementation
- `ServiceBase`: Base class for services
- `ScreenBase`: Base for screen implementations
- `DrawerBase`: Base for drawer implementations

### 3. Services
Core services providing essential functionality:

- `SharedPreferences`: Persistent storage service
- `TickerTimer`: Time-based service for game mechanics

## System Flow

1. **Initialization**
   - App starts and initializes core managers
   - Services are auto-registered
   - Plugins are initialized with their dependencies
   - Modules are registered as needed

2. **Runtime**
   - Services provide core functionality
   - Plugins handle specific features
   - Modules manage UI and business logic
   - State management handles data flow

3. **Cleanup**
   - Managers handle proper disposal
   - Services are cleaned up
   - Modules are disposed
   - Plugins are deregistered

## Best Practices

1. **Module Registration**
   - Register modules with unique keys
   - Use instance keys for multiple instances
   - Properly dispose modules when done

2. **Plugin Usage**
   - Initialize plugins early
   - Use hooks for cross-plugin communication
   - Follow plugin lifecycle methods

3. **Service Management**
   - Register services before use
   - Use type-safe service retrieval
   - Handle service initialization properly

4. **State Management**
   - Use provided state management system
   - Follow unidirectional data flow
   - Properly handle state updates

## Performance Considerations

1. **Module Management**
   - Efficient instance retrieval
   - Proper cleanup to prevent memory leaks
   - Smart instance caching

2. **Service Access**
   - Singleton pattern for services
   - Lazy initialization where appropriate
   - Efficient service lookup

3. **Plugin System**
   - Hook-based communication
   - Efficient plugin initialization
   - Proper resource management

## Error Handling

- Comprehensive logging system
- Graceful degradation
- Clear error messages
- Proper exception handling

## Extension Points

1. **Adding New Services**
   - Extend `ServiceBase`
   - Register in `ServicesManager`
   - Implement required methods

2. **Creating New Plugins**
   - Extend `PluginBase`
   - Implement initialization
   - Register hooks as needed

3. **Adding Modules**
   - Extend `ModuleBase`
   - Implement required functionality
   - Register with `ModuleManager`

This documentation serves as a reference for understanding and working with the core system architecture. For specific implementation details, refer to the individual class files and their documentation. 