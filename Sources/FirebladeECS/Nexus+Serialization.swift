//
//  Nexus+Serialization.swift
//
//
//  Created by Christian Treffs on 26.06.20.
//

#if canImport(Foundation)
import struct Foundation.Data

extension Nexus {
    final func serialize() throws -> SNexus {
        let version = Version(major: 1, minor: 0, patch: 0)

        var componentInstances: [ComponentIdentifier.StableId: SComponent<SNexus>] = [:]
        var entityComponentsMap: [EntityIdentifier: Set<ComponentIdentifier.StableId>] = [:]

        for entitId in self.entityStorage {
            entityComponentsMap[entitId] = []
            let componentIds = self.get(components: entitId) ?? []

            for componentId in componentIds {
                let component = self.get(unsafeComponent: componentId, for: entitId)
                let componentStableInstanceHash = ComponentIdentifier.makeStableInstanceHash(component: component, entityId: entitId)
                componentInstances[componentStableInstanceHash] = SComponent.component(component)
                entityComponentsMap[entitId]?.insert(componentStableInstanceHash)
            }
        }

        return SNexus(version: version,
                      entities: entityComponentsMap,
                      components: componentInstances)
    }

    convenience init(from sNexus: SNexus) throws {
        let entityIds = sNexus.entities.map { $0.key }.reversed()

        // FIXME: this does not respect the generator of the target nexus!
        self.init(entityStorage: UnorderedSparseSet(),
                  componentsByType: [:],
                  componentsByEntity: [:],
                  entityIdGenerator: DefaultEntityIdGenerator(startProviding: entityIds),
                  familyMembersByTraits: [:],
                  codingStrategy: DefaultCodingStrategy())

        for componentSet in sNexus.entities.values {
            let entity = self.createEntity()
            for sCompId in componentSet {
                guard let sComp = sNexus.components[sCompId] else {
                    // FIXME: we want a dedicated error
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Could not find component instance for \(sCompId)."))
                }

                switch sComp {
                case let .component(comp):
                    entity.assign(comp)
                }
            }
        }
    }
}

extension EntityIdentifier: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}
extension EntityIdentifier: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(UInt32.self)
        self.init(id)
    }
}

internal struct SNexus {
    let version: Version
    let entities: [EntityIdentifier: Set<ComponentIdentifier.StableId>]
    let components: [ComponentIdentifier.StableId: SComponent<SNexus>]
}
extension SNexus: Encodable { }
extension SNexus: Decodable { }

protocol ComponentEncoding {
    static func encode(component: Component, to encoder: Encoder) throws
}

protocol ComponentDecoding {
    static func decode(from decoder: Decoder) throws -> Component
}
typealias ComponentCodable = ComponentEncoding & ComponentDecoding

extension SNexus: ComponentEncoding {
    static func encode(component: Component, to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let bytes = withUnsafeBytes(of: component) {
            Data(bytes: $0.baseAddress!, count: MemoryLayout.stride(ofValue: component))
        }
        try container.encode(bytes)
    }
}

extension SNexus: ComponentDecoding {
    static func decode(from decoder: Decoder) throws -> Component {
        let container = try decoder.singleValueContainer()
        let instanceData = try container.decode(Data.self)
        return instanceData.withUnsafeBytes {
            $0.baseAddress!.load(as: Component.self)
        }
    }
}

enum SComponent<CodingStrategy: ComponentCodable> {
    case component(Component)
}

extension SComponent: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .component(comp):
            try CodingStrategy.encode(component: comp, to: encoder)
        }
    }
}

extension SComponent: Decodable {
    public init(from decoder: Decoder) throws {
        self = .component(try CodingStrategy.decode(from: decoder))
    }
}

#endif