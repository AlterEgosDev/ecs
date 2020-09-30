/// Requires initializer with no arguments.
/// In case of component - makes sure it can be instantiated by  component provider
public protocol EmptyInitializable {
    init()
}

public typealias ComponentInitializable = Component & EmptyInitializable

/// This is the Interface for component providers. Component providers are used to supply components
/// for states within an EntityStateMachine. FirebladeECS includes three standard component providers,
/// ComponentTypeProvider, ComponentInstanceProvider and ComponentSingletonProvider. Developers
/// may wish to create more.
public protocol ComponentProvider {
    /// Returns an identifier that is used to determine whether two component providers will
    /// return the equivalent components.

    /// If an entity is changing state and the state it is leaving and the state is
    /// entering have components of the same type, then the identifiers of the component
    /// provders are compared. If the two identifiers are the same then the component
    /// is not removed. If they are different, the component from the old state is removed
    /// and a component for the new state is added.

    /// - Returns: struct/class instance that confirms to Hashable protocol
    var identifier: AnyHashable { get }
    
    /// Used to request a component from the provider.
    /// - Returns: A component for use in the state that the entity is entering
    func getComponent() -> Component
}

// MARK: -

/// This component provider always returns the same instance of the component. The instance
/// is passed to the provider at initialisation.
public class ComponentInstanceProvider {
    private var instance: Component
    
    /// Initializer
    /// - Parameter instance: The instance to return whenever a component is requested.
    public init(instance: Component) {
        self.instance = instance
    }
}

extension ComponentInstanceProvider: ComponentProvider {
    /// Used to compare this provider with others. Any provider that returns the same component
    /// instance will be regarded as equivalent.
    /// - Returns:ObjectIdentifier of instance
    public var identifier: AnyHashable {
        ObjectIdentifier(instance)
    }
    
    /// Used to request a component from this provider
    /// - Returns: The instance
    public func getComponent() -> Component {
        instance
    }
}

// MARK: -

/// This component provider always returns a new instance of a component. An instance
/// is created when requested and is of the type passed in to the initializer.
public class ComponentTypeProvider {
    private var componentType: ComponentInitializable.Type
    
    /// Used to compare this provider with others. Any ComponentTypeProvider that returns
    /// the same type will be regarded as equivalent.
    /// - Returns:ObjectIdentifier of the type of the instances created
    public let identifier: AnyHashable
    
    /// Initializer
    /// - Parameter type: The type of the instances to be created
    public init(type: ComponentInitializable.Type) {
        componentType = type
        identifier = ObjectIdentifier(componentType.self)
    }
}

extension ComponentTypeProvider: ComponentProvider {
    /// Used to request a component from this provider
    /// - Returns: A new instance of the type provided in the initializer
    public func getComponent() -> Component {
        componentType.init()
    }
}

// MARK: -

/// This component provider always returns the same instance of the component. The instance
/// is created when first required and is of the type passed in to the initializer.
public class ComponentSingletonProvider {
    lazy private var instance: Component = {
        componentType.init()
    }()
    
    private var componentType: ComponentInitializable.Type
    
    /// Initializer
    /// - Parameter type: The type of the single instance
    public init(type: ComponentInitializable.Type) {
        componentType = type
    }
}

extension ComponentSingletonProvider: ComponentProvider {
    /// Used to compare this provider with others. Any provider that returns the same single
    /// instance will be regarded as equivalent.
    /// - Returns: ObjectIdentifier of the single instance
    public var identifier: AnyHashable {
        ObjectIdentifier(instance)
    }
    
    /// Used to request a component from this provider
    /// - Returns: The single instance
    public func getComponent() -> Component {
        instance
    }
}

// MARK: -

/// This component provider calls a function to get the component instance. The function must
/// return a single component of the appropriate type.
public class DynamicComponentProvider {
    /// Wrapper for closure to make it hashable
    public class Closure {
        let closure: () -> Component
        
        /// Initializer
        /// - Parameter closure: Swift closure returning component of the appropriate type
        public init(closure: @escaping () -> Component) {
            self.closure = closure
        }
    }
    private let closure: Closure

    
    /// Initializer
    /// - Parameter closure: Instance of Closure class. A wrapper around closure that will
    /// return the component instance when called.
    public init(closure: Closure) {
        self.closure = closure
    }
}

extension DynamicComponentProvider: ComponentProvider {
    /// Used to compare this provider with others. Any provider that uses the function or method
    /// closure to provide the instance is regarded as equivalent.
    /// - Returns: ObjectIdentifier of closure
    public var identifier: AnyHashable {
        ObjectIdentifier(closure)
    }
    
    /// Used to request a component from this provider
    /// - Returns: The instance returned by calling the closure
    public func getComponent() -> Component {
        closure.closure()
    }
}

// MARK: -

/// Represents a state for an EntityStateMachine. The state contains any number of ComponentProviders which
/// are used to add components to the entity when this state is entered.
public class EntityState {
    internal var providers = [ComponentIdentifier: ComponentProvider]()
    
    public init() {}
    
    /// Add a new ComponentMapping to this state. The mapping is a utility class that is used to
    /// map a component type to the provider that provides the component.
    /// - Parameter type: The type of component to be mapped
    /// - Returns: The component mapping to use when setting the provider for the component
    @discardableResult public func add(_ type: ComponentInitializable.Type) -> StateComponentMapping {
        StateComponentMapping(creatingState: self, type: type)
    }
    
    /// Get the ComponentProvider for a particular component type.
    /// - Parameter type: The type of component to get the provider for
    /// - Returns: The ComponentProvider
    public func get(_ type: ComponentInitializable.Type) -> ComponentProvider? {
        providers[type.identifier]
    }
    
    /// To determine whether this state has a provider for a specific component type.
    /// - Parameter type: The type of component to look for a provider for
    /// - Returns: true if there is a provider for the given type, false otherwise
    public func has(_ type: ComponentInitializable.Type) -> Bool {
        providers[type.identifier] != nil
    }
}
// MARK: -


/// Used by the EntityState class to create the mappings of components to providers via a fluent interface.
public class StateComponentMapping {
    private var componentType: ComponentInitializable.Type
    private let creatingState: EntityState
    private var provider: ComponentProvider
    
    /// Used internally, the initializer creates a component mapping. The constructor
    /// creates a ComponentTypeProvider as the default mapping, which will be replaced
    /// by more specific mappings if other methods are called.

    /// - Parameter creatingState: The EntityState that the mapping will belong to
    /// - Parameter type: The component type for the mapping
    internal init(creatingState: EntityState, type: ComponentInitializable.Type) {
        self.creatingState = creatingState
        componentType = type
        provider = ComponentTypeProvider(type: type)
    }
    
    /// Creates a mapping for the component type to a specific component instance. A
    /// ComponentInstanceProvider is used for the mapping.
    /// - Parameter component: The component instance to use for the mapping
    /// - Returns: This ComponentMapping, so more modifications can be applied
    @discardableResult public func withInstance(_ component: Component) -> StateComponentMapping {
        setProvider(ComponentInstanceProvider(instance: component))
        return self
    }
    
    /// Creates a mapping for the component type to new instances of the provided type.
    /// The type should be the same as or extend the type for this mapping. A ComponentTypeProvider
    /// is used for the mapping.
    /// - Parameter type: The type of components to be created by this mapping
    /// - Returns: This ComponentMapping, so more modifications can be applied
    @discardableResult public func withType(_ type: ComponentInitializable.Type) -> Self {
        setProvider(ComponentTypeProvider(type: type))
        return self
    }
    
    /// Creates a mapping for the component type to a single instance of the provided type.
    /// The instance is not created until it is first requested. The type should be the same
    /// as or extend the type for this mapping. A ComponentSingletonProvider is used for
    /// the mapping.
    /// - Parameter type: The type of the single instance to be created. If omitted, the type of the
    /// mapping is used.
    /// - Returns: This ComponentMapping, so more modifications can be applied
    @discardableResult public func withSingleton(_ type: ComponentInitializable.Type?) -> Self {
        setProvider(ComponentSingletonProvider(type: type ?? componentType))
        return self
    }
    
    /// Creates a mapping for the component type to a method call. A
    /// DynamicComponentProvider is used for the mapping.
    /// - Parameter method: The method to return the component instance
    /// - Returns: This ComponentMapping, so more modifications can be applied
    @discardableResult public func withMethod(_ closure: DynamicComponentProvider.Closure) -> Self {
        setProvider(DynamicComponentProvider(closure: closure))
        return self
    }
    
    /// Creates a mapping for the component type to any ComponentProvider.
    /// - Parameter provider: The component provider to use.
    /// - Returns: This ComponentMapping, so more modifications can be applied.
    @discardableResult public func withProvider(_ provider: ComponentProvider) -> Self {
        setProvider(provider)
        return self
    }
    
    /// Maps through to the add method of the EntityState that this mapping belongs to
    /// so that a fluent interface can be used when configuring entity states.
    /// - Parameter type: The type of component to add a mapping to the state for
    /// - Returns: The new ComponentMapping for that type
    public func add(_ type: ComponentInitializable.Type) -> StateComponentMapping {
        creatingState.add(type)
    }
    
    private func setProvider(_ provider: ComponentProvider) {
        self.provider = provider
        creatingState.providers[componentType.identifier] = provider
    }
}

// MARK: -

public class EntityStateMachine<StateName: Hashable> {
    private var states: [StateName: EntityState]
    
    private var currentState: EntityState?
    
    public var entity: Entity
    
    public init(entity: Entity) {
        self.entity = entity
        states = [:]
    }
    
    @discardableResult public func addState(name: StateName, state: EntityState) -> Self {
        states[name] = state
        return self
    }
    
    public func createState(name: StateName) -> EntityState {
        let state = EntityState()
        states[name] = state
        return state
    }
    
    public func changeState(name: StateName) {
        guard let newState = states[name] else {
            fatalError("Entity state '\(name)' doesn't exist")
        }
        
        if newState === currentState {
            return
        }
        var toAdd: [ComponentIdentifier: ComponentProvider]
        if let currentState = currentState {
            toAdd = .init()
            for t in newState.providers {
                toAdd[t.key] = t.value
            }
            
            for t in currentState.providers {
                if let other = toAdd[t.key], let current = currentState.providers[t.key],
                   current.identifier == other.identifier {
                    toAdd[t.key] = nil
                } else {
                    entity.remove(t.key)
                }
            }
        } else {
            toAdd = newState.providers
        }
        
        for t in toAdd {
            guard let component = toAdd[t.key]?.getComponent() else {
                continue
            }
            entity.assign(component)
        }
        currentState = newState
    }
}
