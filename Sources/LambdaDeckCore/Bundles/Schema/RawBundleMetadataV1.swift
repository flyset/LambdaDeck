struct RawBundleMetadataV1: Decodable {
    struct RawModel: Decodable {
        let id: String
    }

    struct RawTokenizer: Decodable {
        let directory: String
        let family: String?
    }

    struct RawAdapter: Decodable {
        let kind: String
    }

    struct RawRuntime: Decodable {
        let monolithicModel: String?
        let contextLength: Int?
        let slidingWindow: Int?
        let batchSize: Int?
        let architecture: String?

        enum CodingKeys: String, CodingKey {
            case monolithicModel = "monolithic_model"
            case contextLength = "context_length"
            case slidingWindow = "sliding_window"
            case batchSize = "batch_size"
            case architecture
        }
    }

    struct RawPrompt: Decodable {
        let format: String?
        let systemPolicy: String?

        enum CodingKeys: String, CodingKey {
            case format
            case systemPolicy = "system_policy"
        }
    }

    let schemaVersion: Int
    let model: RawModel
    let tokenizer: RawTokenizer
    let adapter: RawAdapter
    let runtime: RawRuntime
    let prompt: RawPrompt?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case model
        case tokenizer
        case adapter
        case runtime
        case prompt
    }
}
