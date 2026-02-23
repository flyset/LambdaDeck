import Foundation

extension GemmaBPETokenizer: Tokenizer {
    var specialTokenIDs: [SpecialToken: Int] {
        var mapping: [SpecialToken: Int] = [:]
        if let bos = bosTokenID {
            mapping[.bos] = bos
        }
        if let eos = eosTokenID {
            mapping[.eos] = eos
        }
        if let startOfTurn = tokenID(for: "<start_of_turn>") {
            mapping[.startOfTurn(.user)] = startOfTurn
            mapping[.startOfTurn(.assistant)] = startOfTurn
            mapping[.startOfTurn(.system)] = startOfTurn
        }
        if let endOfTurn = tokenID(for: "<end_of_turn>") {
            mapping[.endOfTurn] = endOfTurn
        }
        if let endOfText = tokenID(for: "<|endoftext|>") {
            mapping[.endOfText] = endOfText
        }
        if let eot = tokenID(for: "<|eot_id|>") {
            mapping[.eotID] = eot
        }
        if let pad = tokenID(for: "<pad>") {
            mapping[.pad] = pad
        }
        if let unk = tokenID(for: "<unk>") {
            mapping[.unk] = unk
        }
        if let startOfImage = tokenID(for: "<start_of_image>") {
            mapping[.startOfImage] = startOfImage
        }
        if let imageSoftToken = tokenID(for: "<image_soft_token>") {
            mapping[.imageSoftToken] = imageSoftToken
        }
        return mapping
    }

    func encode(text: String) -> [Int] {
        encode(text)
    }

    func encode(segments: [PromptSegment]) throws -> [Int] {
        var tokenIDs: [Int] = []
        for segment in segments {
            switch segment {
            case .text(let value):
                tokenIDs.append(contentsOf: encode(value))
            case .special(let token):
                switch token {
                case .startOfTurn(let role):
                    let startID = try requireTokenID(for: token)
                    tokenIDs.append(startID)
                    let roleLabel = gemmaRoleLabel(for: role)
                    tokenIDs.append(contentsOf: encode(roleLabel + "\n"))
                case .endOfTurn:
                    let endID = try requireTokenID(for: token)
                    tokenIDs.append(endID)
                    tokenIDs.append(contentsOf: encode("\n"))
                default:
                    let id = try requireTokenID(for: token)
                    tokenIDs.append(id)
                }
            }
        }
        return tokenIDs
    }

    private func requireTokenID(for token: SpecialToken) throws -> Int {
        guard let id = specialTokenIDs[token] else {
            throw LambdaDeckRuntimeError.invalidModelBundle("Missing special token mapping for \(token)")
        }
        return id
    }

    private func gemmaRoleLabel(for role: Role) -> String {
        switch role {
        case .assistant:
            return "model"
        case .user:
            return "user"
        case .system:
            return "system"
        }
    }
}
