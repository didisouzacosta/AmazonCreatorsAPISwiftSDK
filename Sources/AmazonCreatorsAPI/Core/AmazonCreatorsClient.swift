import Foundation

private protocol CatalogResponse: Decodable {

    var errors: [APIProblem] { get }
}

extension GetItemsResponse: CatalogResponse {}
extension SearchItemsResponse: CatalogResponse {}
extension GetVariationsResponse: CatalogResponse {}
extension GetBrowseNodesResponse: CatalogResponse {}

/// Cliente concorrente e seguro para as operações de catálogo da Amazon Creators API.
public actor AmazonCreatorsClient {

    private static let baseURL = URL(string: "https://creatorsapi.amazon")!

    private var manuallyUpdatedToken: String?
    private let initialAccessToken: String?
    private let accessTokenProvider: AccessTokenProvider?
    private let credentialVersion: CredentialVersion
    private let partnerTag: PartnerTag
    private let marketplace: Marketplace
    private let configuration: AmazonCreatorsConfiguration
    private let transport: any HTTPTransport
    private let scheduler: RequestScheduler
    private let cache: ResponseCache

    /// Cria um cliente com um access token obtido externamente.
    public init(
        accessToken: String,
        credentialVersion: CredentialVersion,
        partnerTag: String,
        marketplace: Marketplace,
        configuration: AmazonCreatorsConfiguration = AmazonCreatorsConfiguration()
    ) {
        manuallyUpdatedToken = nil
        initialAccessToken = accessToken
        accessTokenProvider = nil
        self.credentialVersion = credentialVersion
        self.partnerTag = PartnerTag(partnerTag)
        self.marketplace = marketplace
        self.configuration = configuration
        transport = URLSessionTransport()
        scheduler = RequestScheduler(requestsPerSecond: configuration.requestsPerSecond)
        cache = ResponseCache(maximumEntries: configuration.maxCachedResponses)
    }

    /// Cria um cliente que solicita um access token temporário ao provider antes de cada chamada de rede.
    public init(
        accessTokenProvider: @escaping AccessTokenProvider,
        credentialVersion: CredentialVersion,
        partnerTag: String,
        marketplace: Marketplace,
        configuration: AmazonCreatorsConfiguration = AmazonCreatorsConfiguration()
    ) {
        manuallyUpdatedToken = nil
        initialAccessToken = nil
        self.accessTokenProvider = accessTokenProvider
        self.credentialVersion = credentialVersion
        self.partnerTag = PartnerTag(partnerTag)
        self.marketplace = marketplace
        self.configuration = configuration
        transport = URLSessionTransport()
        scheduler = RequestScheduler(requestsPerSecond: configuration.requestsPerSecond)
        cache = ResponseCache(maximumEntries: configuration.maxCachedResponses)
    }

    init(
        accessToken: String,
        credentialVersion: CredentialVersion,
        partnerTag: String,
        marketplace: Marketplace,
        configuration: AmazonCreatorsConfiguration,
        transport: any HTTPTransport
    ) {
        manuallyUpdatedToken = nil
        initialAccessToken = accessToken
        accessTokenProvider = nil
        self.credentialVersion = credentialVersion
        self.partnerTag = PartnerTag(partnerTag)
        self.marketplace = marketplace
        self.configuration = configuration
        self.transport = transport
        scheduler = RequestScheduler(requestsPerSecond: configuration.requestsPerSecond)
        cache = ResponseCache(maximumEntries: configuration.maxCachedResponses)
    }

    /// Substitui o token usado pelo cliente sem reconfigurar suas operações de catálogo.
    public func updateAccessToken(_ accessToken: String) throws {
        guard !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AmazonCreatorsError.invalidRequest("accessToken não pode ser vazio.")
        }

        manuallyUpdatedToken = accessToken
    }

    /// Recupera até dez produtos por ASIN.
    public func getItems(_ request: GetItemsRequest) async throws -> GetItemsResponse {
        try request.validate()

        let payload = GetItemsPayload(request: request, marketplace: marketplace, partnerTag: partnerTag)

        return try await execute(
            path: "/catalog/v1/getItems",
            payload: payload,
            resources: request.resources
        )
    }

    /// Pesquisa produtos com palavras-chave e filtros documentados pela Amazon.
    public func searchItems(_ request: SearchItemsRequest) async throws -> SearchItemsResponse {
        try request.validate()

        let payload = SearchItemsPayload(request: request, marketplace: marketplace, partnerTag: partnerTag)

        return try await execute(
            path: "/catalog/v1/searchItems",
            payload: payload,
            resources: request.options.resources
        )
    }

    /// Recupera variações e o resumo de um ASIN pai ou filho.
    public func getVariations(_ request: GetVariationsRequest) async throws -> GetVariationsResponse {
        try request.validate()

        let payload = GetVariationsPayload(request: request, marketplace: marketplace, partnerTag: partnerTag)

        return try await execute(
            path: "/catalog/v1/getVariations",
            payload: payload,
            resources: request.resources
        )
    }

    /// Recupera browse nodes e suas relações de ancestrais ou filhos.
    public func getBrowseNodes(_ request: GetBrowseNodesRequest) async throws -> GetBrowseNodesResponse {
        try request.validate()

        let payload = GetBrowseNodesPayload(request: request, marketplace: marketplace, partnerTag: partnerTag)

        return try await execute(
            path: "/catalog/v1/getBrowseNodes",
            payload: payload,
            resources: request.resources
        )
    }

    private func execute<Response: CatalogResponse, Payload: Encodable>(
        path: String,
        payload: Payload,
        resources: [CatalogResource]
    ) async throws -> Response {
        try validateClientConfiguration()

        let payloadData: Data

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            payloadData = try encoder.encode(payload)
        } catch {
            throw AmazonCreatorsError.decoding("Não foi possível serializar a requisição: \(error.localizedDescription)")
        }

        let cacheKey = path + "|" + String(decoding: payloadData, as: UTF8.self)

        if configuration.cachePolicy == .memory, let cachedData = await cache.value(for: cacheKey) {
            return try decodeResponse(Response.self, from: cachedData)
        }

        var attempt = 0

        while true {
            try Task.checkCancellation()

            do {
                let request = try await makeURLRequest(path: path, payload: payloadData)

                try await scheduler.waitForPermission()

                let response = try await transport.send(request)

                guard (200...299).contains(response.statusCode) else {
                    let error = serviceError(from: response)

                    if shouldRetry(error), attempt < configuration.maxRetryAttempts {
                        attempt += 1
                        try await waitBeforeRetry(attempt: attempt, retryAfter: retryAfter(from: response.headers))

                        continue
                    }

                    throw error
                }

                let decodedResponse = try decodeResponse(Response.self, from: response.data)

                if configuration.cachePolicy == .memory, decodedResponse.errors.isEmpty {
                    await cache.store(response.data, for: cacheKey, ttl: cacheTTL(for: resources))
                }

                return decodedResponse
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as AmazonCreatorsError {
                if shouldRetry(error), attempt < configuration.maxRetryAttempts {
                    attempt += 1
                    try await waitBeforeRetry(attempt: attempt)

                    continue
                }

                throw error
            } catch {
                let transportError = AmazonCreatorsError.transport(error.localizedDescription)

                if attempt < configuration.maxRetryAttempts {
                    attempt += 1
                    try await waitBeforeRetry(attempt: attempt)

                    continue
                }

                throw transportError
            }
        }
    }

    private func makeURLRequest(path: String, payload: Data) async throws -> URLRequest {
        let token = try await accessToken()
        let url = Self.baseURL.appending(path: path)
        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        request.httpBody = payload
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(authorizationValue(for: token))", forHTTPHeaderField: "Authorization")
        request.setValue(marketplace.rawValue, forHTTPHeaderField: "x-marketplace")

        return request
    }

    private func accessToken() async throws -> String {
        if let manuallyUpdatedToken {
            return manuallyUpdatedToken
        }

        if let initialAccessToken {
            guard !initialAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AmazonCreatorsError.unauthorized(APIProblem(message: "O access token está vazio."))
            }

            return initialAccessToken
        }

        guard let accessTokenProvider else {
            throw AmazonCreatorsError.unauthorized(APIProblem(message: "Nenhum access token foi configurado."))
        }

        do {
            let token = try await accessTokenProvider()

            guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AmazonCreatorsError.unauthorized(APIProblem(message: "O provider retornou um access token vazio."))
            }

            return token
        } catch let error as AmazonCreatorsError {
            throw error
        } catch {
            throw AmazonCreatorsError.unauthorized(APIProblem(message: error.localizedDescription))
        }
    }

    private func authorizationValue(for token: String) -> String {
        "Bearer \(token)\(credentialVersion.authorizationValueSuffix ?? "")"
    }

    private func validateClientConfiguration() throws {
        guard !partnerTag.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AmazonCreatorsError.invalidRequest("partnerTag não pode ser vazio.")
        }
    }

    private func decodeResponse<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch let error as AmazonCreatorsError {
            throw error
        } catch {
            throw AmazonCreatorsError.decoding("Não foi possível decodificar a resposta: \(error.localizedDescription)")
        }
    }

    private func serviceError(from response: TransportResponse) -> AmazonCreatorsError {
        let problem = (try? JSONDecoder().decode(APIProblem.self, from: response.data)) ?? APIProblem(message: "A Creators API retornou HTTP \(response.statusCode).")

        switch response.statusCode {
        case 400:
            return .validation(problem)
        case 401:
            return .unauthorized(problem)
        case 403:
            return .accessDenied(problem)
        case 404:
            return .notFound(problem)
        case 429:
            return .throttled(problem)
        case 500...599:
            return .server(problem)
        default:
            return .transport("A Creators API retornou HTTP \(response.statusCode).")
        }
    }

    private func shouldRetry(_ error: AmazonCreatorsError) -> Bool {
        switch error {
        case .throttled, .server:
            return true
        case .invalidRequest, .unauthorized, .validation, .accessDenied, .notFound, .transport, .decoding:
            return false
        }
    }

    private func waitBeforeRetry(attempt: Int, retryAfter: TimeInterval? = nil) async throws {
        let baseDelay = configuration.retryBaseDelay.secondsValue
        let exponentialDelay = min(baseDelay * pow(2, Double(attempt - 1)), 5)
        let serverDelay = retryAfter ?? 0
        let delay = max(exponentialDelay, serverDelay)

        guard delay > 0 else {
            return
        }

        let jitter = Double.random(in: 0...0.25)

        try await Task.sleep(for: .seconds(delay + jitter))
    }

    private func cacheTTL(for resources: [CatalogResource]) -> TimeInterval {
        let containsVolatileResource = resources.contains { resource in
            resource.rawValue.hasPrefix("offersV2.") || resource.rawValue.hasPrefix("browseNodeInfo.") || resource.rawValue.hasPrefix("browseNodes.")
        }

        return containsVolatileResource ? 60 * 60 : 60 * 60 * 24
    }

    private func retryAfter(from headers: [String: String]) -> TimeInterval? {
        guard let headerValue = headers.first(where: { $0.key.caseInsensitiveCompare("Retry-After") == .orderedSame })?.value.trimmingCharacters(in: .whitespacesAndNewlines), !headerValue.isEmpty else {
            return nil
        }

        if let seconds = Double(headerValue), seconds >= 0 {
            return seconds
        }

        let formats = [
            "EEE',' dd MMM yyyy HH':'mm':'ss zzz",
            "EEEE',' dd-MMM-yy HH':'mm':'ss zzz",
            "EEE MMM d HH':'mm':'ss yyyy"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format

            if let retryDate = formatter.date(from: headerValue) {
                return max(0, retryDate.timeIntervalSinceNow)
            }
        }

        return nil
    }
}

private struct GetItemsPayload: Encodable {

    let itemIDs: [String]
    let itemIDType: String
    let condition: ProductCondition?
    let currencyOfPreference: String?
    let languagesOfPreference: [String]?
    let marketplace: String
    let partnerTag: String
    let resources: [String]

    init(request: GetItemsRequest, marketplace: Marketplace, partnerTag: PartnerTag) {
        itemIDs = request.itemIDs
        itemIDType = "ASIN"
        condition = request.condition
        currencyOfPreference = request.currencyOfPreference
        languagesOfPreference = request.languageOfPreference.map { [$0] }
        self.marketplace = marketplace.rawValue
        self.partnerTag = partnerTag.value
        resources = request.resources.map(\.rawValue)
    }

    enum CodingKeys: String, CodingKey {
        case itemIDs = "itemIds"
        case itemIDType = "itemIdType"
        case condition
        case currencyOfPreference
        case languagesOfPreference
        case marketplace
        case partnerTag
        case resources
    }
}

private struct SearchItemsPayload: Encodable {

    let keywords: String?
    let actor: String?
    let artist: String?
    let author: String?
    let availability: SearchAvailability?
    let brand: String?
    let browseNodeID: String?
    let condition: ProductCondition?
    let currencyOfPreference: String?
    let deliveryFlags: [DeliveryFlag]?
    let itemCount: Int?
    let itemPage: Int?
    let languagesOfPreference: [String]?
    let maximumPrice: Int?
    let minimumPrice: Int?
    let minimumReviewsRating: Int?
    let minimumSavingPercent: Int?
    let marketplace: String
    let partnerTag: String
    let properties: [String: String]?
    let resources: [String]
    let searchIndex: String?
    let sortBy: SearchSort?
    let title: String?

    init(request: SearchItemsRequest, marketplace: Marketplace, partnerTag: PartnerTag) {
        let options = request.options

        keywords = request.keywords
        actor = options.actor
        artist = options.artist
        author = options.author
        availability = options.availability
        brand = options.brand
        browseNodeID = options.browseNodeID
        condition = options.condition
        currencyOfPreference = options.currencyOfPreference
        deliveryFlags = options.deliveryFlags
        itemCount = options.itemCount
        itemPage = options.itemPage
        languagesOfPreference = options.languageOfPreference.map { [$0] }
        maximumPrice = options.maximumPrice
        minimumPrice = options.minimumPrice
        minimumReviewsRating = options.minimumReviewsRating
        minimumSavingPercent = options.minimumSavingPercent
        self.marketplace = marketplace.rawValue
        self.partnerTag = partnerTag.value
        properties = options.properties
        resources = options.resources.map(\.rawValue)
        searchIndex = options.searchIndex
        sortBy = options.sortBy
        title = options.title
    }

    enum CodingKeys: String, CodingKey {
        case keywords
        case actor
        case artist
        case author
        case availability
        case brand
        case browseNodeID = "browseNodeId"
        case condition
        case currencyOfPreference
        case deliveryFlags
        case itemCount
        case itemPage
        case languagesOfPreference
        case maximumPrice = "maxPrice"
        case minimumPrice = "minPrice"
        case minimumReviewsRating
        case minimumSavingPercent
        case marketplace
        case partnerTag
        case properties
        case resources
        case searchIndex
        case sortBy
        case title
    }
}

private struct GetVariationsPayload: Encodable {

    let asin: String
    let condition: ProductCondition?
    let currencyOfPreference: String?
    let languagesOfPreference: [String]?
    let marketplace: String
    let partnerTag: String
    let resources: [String]
    let variationCount: Int?
    let variationPage: Int?

    init(request: GetVariationsRequest, marketplace: Marketplace, partnerTag: PartnerTag) {
        asin = request.asin
        condition = request.condition
        currencyOfPreference = request.currencyOfPreference
        languagesOfPreference = request.languageOfPreference.map { [$0] }
        self.marketplace = marketplace.rawValue
        self.partnerTag = partnerTag.value
        resources = request.resources.map(\.rawValue)
        variationCount = request.variationCount
        variationPage = request.variationPage
    }
}

private struct GetBrowseNodesPayload: Encodable {

    let browseNodeIDs: [String]
    let languagesOfPreference: [String]?
    let marketplace: String
    let partnerTag: String
    let resources: [String]

    init(request: GetBrowseNodesRequest, marketplace: Marketplace, partnerTag: PartnerTag) {
        browseNodeIDs = request.ids
        languagesOfPreference = request.languageOfPreference.map { [$0] }
        self.marketplace = marketplace.rawValue
        self.partnerTag = partnerTag.value
        resources = request.resources.map(\.rawValue)
    }

    enum CodingKeys: String, CodingKey {
        case browseNodeIDs = "browseNodeIds"
        case languagesOfPreference
        case marketplace
        case partnerTag
        case resources
    }
}

private extension Duration {

    var secondsValue: Double {
        let components = components

        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
