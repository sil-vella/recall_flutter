
# Plugin and Module System Documentation

This document describes the structure and function of the plugin and module system in the application.

## Overview

The plugin and module system is designed to provide a modular architecture where plugins can add functionality to the application dynamically. Each plugin can register its own modules, which are only available when the plugin is enabled and initialized. This design ensures that features are conditionally loaded and executed based on plugin availability, improving both performance and scalability.

## Core Components

### 1. `AppPlugin`

Located in: `/plugins/base/app_plugin.dart`

`AppPlugin` is the abstract base class for all plugins. Each plugin must implement the `AppPlugin` interface, providing the following methods:

- **`initialize(BuildContext context)`**: Called when the plugin is initialized with access to the Flutter `BuildContext`. Plugins should use this method to register any dependencies or modules.
- **`onStartup()`**: A hook that runs when the app starts up, allowing plugins to perform pre-initialization tasks (e.g., module registration) without requiring a context.
- **`registerModules()`**: A method for registering any associated modules within the plugin. Modules registered by a plugin are only available when that plugin is active.

This design ensures that plugins can perform setup operations both during app startup and on initialization with context.

### 2. `PluginManager`

Located in: `/plugins/base/plugin_manager.dart`

`PluginManager` is responsible for managing and initializing all registered plugins within the application. It provides methods to register plugins and execute their lifecycle methods.

- **`registerPlugin(AppPlugin plugin)`**: Registers a plugin without initializing it immediately.
- **`runOnStartup()`**: Calls the `onStartup` method for each registered plugin, allowing them to register modules or perform other setup tasks before initialization.
- **`initializeAllPlugins(BuildContext context)`**: Initializes each plugin with a given `BuildContext`. This method is called after the first frame is rendered to ensure `BuildContext` availability.

The `PluginManager` provides centralized management of plugin lifecycle events, ensuring that all plugins follow a standardized setup flow.

### 3. `ModuleManager`

Located in: `/plugins/base/module_manager.dart`

`ModuleManager` is a singleton class that provides a centralized registry for all modules registered by plugins. Modules are only accessible through `ModuleManager` once registered by an active plugin.

- **`registerModule(String name, dynamic module)`**: Registers a module by name. This method typically stores a factory function or an instance, enabling lazy initialization or conditional loading.
- **`getModule<T>(String name)`**: Retrieves a registered module by name. This method allows other parts of the app to access modules conditionally, based on the plugin’s availability.

By using `ModuleManager`, the application ensures that modules are only available when their parent plugin has registered them, maintaining modularity and reducing unnecessary resource usage.

## Plugin and Module Example

### `AdmobsPlugin`

Located in: `/plugins/shared_plugin/admobs_main.dart`

The `AdmobsPlugin` is an example plugin that integrates with AdMob for displaying ads within the application. It registers a `BannerAdWidget` module that is only accessible when the plugin is active.

#### Key Elements of `AdmobsPlugin`

- **`onStartup()`**: Marks the plugin as registered and registers modules needed for startup.
- **`initialize(BuildContext context)`**: Registers the `BannerAdWidget` with the `ModuleManager`, making it accessible to other parts of the app if the plugin is active.
- **`registerModules()`**: Registers `BannerAdWidget` as a module within the plugin, ensuring that it is only available when `AdmobsPlugin` is registered and initialized.

### Example Usage of Modules

Any part of the app can access a module like `BannerAdWidget` via `ModuleManager`, checking if it’s available through the plugin system.

Example:

```dart
void displayBannerAd() {
  final bannerAdWidget = ModuleManager().getModule<BannerAdWidget>("BannerModule");

  if (bannerAdWidget != null) {
    // Display banner widget as required
  } else {
    print("BannerAdWidget is not available; AdmobsPlugin might be inactive.");
  }
}
```

## Plugin Registration

### `PluginRegistry`

Located in: `/plugins/plugin_registry.dart`

`PluginRegistry` is responsible for registering all plugins in the application. Each plugin is added to `PluginManager` using `registerPlugin`.

Example:

```dart
void registerPlugins() {
  PluginManager().registerPlugin(ExamplePlugin());
  PluginManager().registerPlugin(AdmobsPlugin());
  // Register other plugins as needed
}
```

By centralizing plugin registration, `PluginRegistry` allows for easy addition and removal of plugins.

## Additional Examples

### `ConnectionModule`

Located in: `/plugins/shared_plugin/connection_module.dart`

The `ConnectionModule` is an example of a module that could be registered by a plugin to handle network connections. It demonstrates how modules can encapsulate specific functionality and be conditionally loaded based on plugin availability.

## Summary

This plugin and module system enables the application to maintain a modular architecture. Each plugin encapsulates specific features, registers modules conditionally, and only initializes when required. This approach provides:

- **Performance Optimization**: Only loads modules and plugins when needed.
- **Scalability**: New plugins and modules can be added with minimal impact on the core app structure.
- **Modularity**: Keeps each plugin’s functionality self-contained, enhancing maintainability.

By leveraging `PluginManager`, `ModuleManager`, and `AppPlugin` interfaces, this system ensures a robust foundation for extending application functionality in a clean, organized manner.
