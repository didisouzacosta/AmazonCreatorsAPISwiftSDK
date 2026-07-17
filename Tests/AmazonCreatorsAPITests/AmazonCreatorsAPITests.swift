import Foundation
import Testing
@testable import AmazonCreatorsAPI

@Suite("Amazon Creators API client")
struct AmazonCreatorsAPIClientTests {

    @Test("GetItems cria a requisição autenticada e preserva o link afiliado")
    func getItemsBuildsAuthenticatedRequestAndPreservesAffiliateURL() async throws {
        let transport = MockTransport(responses: [
            .json("""
            {
              "errors": [{"code": "ItemNotAccessible", "message": "Unavailable"}],
              "itemsResult": {
                "items": [{
                  "asin": "B09B2SBHQK",
                  "detailPageURL": "https://www.amazon.com/dp/B09B2SBHQK?tag=store-20&linkCode=ogi",
                  "images": {"primary": {"medium": {"height": 100, "width": 100, "url": "https://images.example/item.jpg"}}},
                  "itemInfo": {"title": {"displayValue": "Echo", "label": "Title", "locale": "en_US"}}
                }]
              }
            }
            """)
        ])
        let client = makeClient(transport: transport)

        let response = try await client.getItems(
            GetItemsRequest(itemIDs: ["B09B2SBHQK"], resources: [.title, .primaryMedium])
        )
        let request = try #require(await transport.requests().first)
        let body = try #require(request.httpBody)
        let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        #expect(request.url?.absoluteString == "https://creatorsapi.amazon/catalog/v1/getItems")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-v3")
        #expect(request.value(forHTTPHeaderField: "x-marketplace") == "www.amazon.com.br")
        #expect(payload?["partnerTag"] as? String == "store-20")
        #expect(payload?["marketplace"] as? String == "www.amazon.com.br")
        #expect(payload?["resources"] as? [String] == ["itemInfo.title", "images.primary.medium"])
        #expect(response.items.first?.affiliateURL.absoluteString == "https://www.amazon.com/dp/B09B2SBHQK?tag=store-20&linkCode=ogi")
        #expect(response.errors.first?.code == "ItemNotAccessible")
    }

    @Test("A versão v2 adiciona a versão da credencial ao header Authorization")
    func v2AuthorizationIncludesCredentialVersion() async throws {
        let transport = MockTransport(responses: [.json("{\"browseNodesResult\": {\"browseNodes\": []}}")])
        let client = makeClient(
            credentialVersion: .v2NorthAmerica,
            transport: transport
        )

        _ = try await client.getBrowseNodes(GetBrowseNodesRequest(ids: ["123"]))
        let request = try #require(await transport.requests().first)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-v3, Version 2.1")
    }

    @Test("O access token pode ser atualizado sem recriar o cliente")
    func accessTokenCanBeUpdatedAtRuntime() async throws {
        let transport = MockTransport(responses: [
            .json("{\"browseNodesResult\": {\"browseNodes\": []}}"),
            .json("{\"browseNodesResult\": {\"browseNodes\": []}}")
        ])
        let client = makeClient(transport: transport)

        _ = try await client.getBrowseNodes(GetBrowseNodesRequest(ids: ["123"]))
        try await client.updateAccessToken("token-renovado")
        _ = try await client.getBrowseNodes(GetBrowseNodesRequest(ids: ["456"]))

        let authorizations = await transport.requests().compactMap {
            $0.value(forHTTPHeaderField: "Authorization")
        }

        #expect(authorizations == ["Bearer token-v3", "Bearer token-renovado"])
    }

    @Test("Uma resposta 401 renova o token e repete a chamada uma única vez")
    func unauthorizedResponseRefreshesTokenAndRetriesOnce() async throws {
        let transport = MockTransport(responses: [
            .status(401, "{\"code\": \"InvalidToken\", \"message\": \"Expired\"}"),
            .json("{\"browseNodesResult\": {\"browseNodes\": []}}")
        ])
        let tokenProvider = TokenProviderSpy(tokens: ["token-expirado"])
        let refreshProvider = TokenProviderSpy(tokens: ["token-renovado"])
        let client = makeProviderClient(
            transport: transport,
            accessTokenProvider: {
                try await tokenProvider.nextToken()
            },
            accessTokenRefreshProvider: {
                try await refreshProvider.nextToken()
            }
        )

        _ = try await client.getBrowseNodes(GetBrowseNodesRequest(ids: ["123"]))

        let authorizations = await transport.requests().compactMap {
            $0.value(forHTTPHeaderField: "Authorization")
        }

        #expect(authorizations == ["Bearer token-expirado", "Bearer token-renovado"])
        #expect(await tokenProvider.invocationCount() == 1)
        #expect(await refreshProvider.invocationCount() == 1)
    }

    @Test("O SDK não tenta renovar o token mais de uma vez por chamada")
    func unauthorizedResponseRefreshesTokenOnlyOnce() async throws {
        let transport = MockTransport(responses: [
            .status(401, "{\"code\": \"InvalidToken\", \"message\": \"Expired\"}"),
            .status(401, "{\"code\": \"InvalidToken\", \"message\": \"Still expired\"}")
        ])
        let tokenProvider = TokenProviderSpy(tokens: ["token-expirado"])
        let refreshProvider = TokenProviderSpy(tokens: ["token-ainda-invalido"])
        let client = makeProviderClient(
            transport: transport,
            accessTokenProvider: {
                try await tokenProvider.nextToken()
            },
            accessTokenRefreshProvider: {
                try await refreshProvider.nextToken()
            }
        )

        await #expect(throws: AmazonCreatorsError.unauthorized(APIProblem(code: "InvalidToken", message: "Still expired"))) {
            _ = try await client.getBrowseNodes(GetBrowseNodesRequest(ids: ["123"]))
        }

        #expect(await transport.requests().count == 2)
        #expect(await refreshProvider.invocationCount() == 1)
    }

    @Test("SearchItems, GetVariations e GetBrowseNodes usam as rotas de catálogo corretas")
    func catalogOperationsUseExpectedRoutes() async throws {
        let transport = MockTransport(responses: [
            .json("{\"searchResult\": {\"items\": [], \"totalResultCount\": 0, \"searchURL\": \"https://www.amazon.com/s?k=echo\"}}"),
            .json("{\"variationsResult\": {\"items\": []}}"),
            .json("{\"browseNodesResult\": {\"browseNodes\": []}}")
        ])
        let client = makeClient(transport: transport)

        _ = try await client.searchItems(SearchItemsRequest(keywords: "echo"))
        _ = try await client.getVariations(GetVariationsRequest(asin: "B09B2SBHQK"))
        _ = try await client.getBrowseNodes(GetBrowseNodesRequest(ids: ["123"]))

        let paths = await transport.requests().compactMap(\.url?.path)

        #expect(paths == ["/catalog/v1/searchItems", "/catalog/v1/getVariations", "/catalog/v1/getBrowseNodes"])
    }

    @Test("O cliente bloqueia limites locais antes de enviar a requisição")
    func validationPreventsInvalidRequests() async throws {
        let transport = MockTransport(responses: [])
        let client = makeClient(transport: transport)

        await #expect(throws: AmazonCreatorsError.invalidRequest("itemIDs deve conter entre 1 e 10 valores.")) {
            _ = try await client.getItems(GetItemsRequest(itemIDs: []))
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test("O cliente tenta novamente uma falha transitória e armazena respostas em memória")
    func retryAndCacheAreManagedInsideSDK() async throws {
        let transport = MockTransport(responses: [
            .status(500, "{\"message\": \"Temporary\"}"),
            .json("{\"searchResult\": {\"items\": [], \"totalResultCount\": 0, \"searchURL\": \"https://www.amazon.com/s?k=echo\"}}")
        ])
        let configuration = AmazonCreatorsConfiguration(
            cachePolicy: .memory,
            requestsPerSecond: 1_000,
            maxRetryAttempts: 1,
            retryBaseDelay: .zero
        )
        let client = makeClient(configuration: configuration, transport: transport)
        let request = SearchItemsRequest(keywords: "echo")

        _ = try await client.searchItems(request)
        _ = try await client.searchItems(request)

        #expect(await transport.requests().count == 2)
    }

    @Test("Erros HTTP e o resumo de variações são decodificados pelo SDK")
    func serviceErrorsAndVariationSummaryAreTyped() async throws {
        let unauthorizedTransport = MockTransport(responses: [
            .status(401, "{\"code\": \"InvalidToken\", \"message\": \"Expired\"}")
        ])
        let unauthorizedClient = makeClient(transport: unauthorizedTransport)

        await #expect(throws: AmazonCreatorsError.unauthorized(APIProblem(code: "InvalidToken", message: "Expired"))) {
            _ = try await unauthorizedClient.getBrowseNodes(GetBrowseNodesRequest(ids: ["123"]))
        }

        let variationTransport = MockTransport(responses: [
            .json("""
            {
              "variationsResult": {
                "items": [],
                "variationSummary": {
                  "price": {
                    "highestPrice": {"amount": 2999},
                    "lowestPrice": {"amount": 1999}
                  },
                  "variationDimension": {"name": "color"}
                }
              }
            }
            """)
        ])
        let variationClient = makeClient(transport: variationTransport)
        let response = try await variationClient.getVariations(GetVariationsRequest(asin: "B09B2SBHQK"))

        #expect(response.variationSummary?.highestPrice == .object(["amount": .integer(2999)]))
        #expect(response.variationSummary?.lowestPrice == .object(["amount": .integer(1999)]))
    }

    @Test("O scheduler reserva slots distintos para chamadas concorrentes")
    func requestSchedulerSerializesConcurrentRequests() async throws {
        let scheduler = RequestScheduler(requestsPerSecond: 20)
        let completionDates = try await withThrowingTaskGroup(of: Date.self, returning: [Date].self) { group in
            for _ in 0..<3 {
                group.addTask {
                    try await scheduler.waitForPermission()

                    return .now
                }
            }

            var dates: [Date] = []

            for try await date in group {
                dates.append(date)
            }

            return dates.sorted()
        }

        #expect(completionDates[1].timeIntervalSince(completionDates[0]) >= 0.035)
        #expect(completionDates[2].timeIntervalSince(completionDates[1]) >= 0.035)
    }

    @Test("Uma resposta inválida não contamina o cache")
    func invalidResponseIsNotCached() async throws {
        let transport = MockTransport(responses: [
            .json("resposta inválida"),
            .json("{\"searchResult\": {\"items\": []}}")
        ])
        let configuration = AmazonCreatorsConfiguration(
            cachePolicy: .memory,
            requestsPerSecond: 1_000,
            maxRetryAttempts: 0
        )
        let client = makeClient(configuration: configuration, transport: transport)
        let request = SearchItemsRequest(keywords: "echo")

        await #expect(throws: AmazonCreatorsError.self) {
            _ = try await client.searchItems(request)
        }

        let response = try await client.searchItems(request)

        #expect(response.items.isEmpty)
        #expect(await transport.requests().count == 2)
    }

    @Test("Respostas parciais não são reutilizadas pelo cache")
    func partialResponsesAreNotCached() async throws {
        let transport = MockTransport(responses: [
            .json("{\"errors\": [{\"code\": \"Temporary\"}], \"searchResult\": {\"items\": []}}"),
            .json("{\"searchResult\": {\"items\": []}}")
        ])
        let configuration = AmazonCreatorsConfiguration(
            cachePolicy: .memory,
            requestsPerSecond: 1_000,
            maxRetryAttempts: 0
        )
        let client = makeClient(configuration: configuration, transport: transport)
        let request = SearchItemsRequest(keywords: "echo")

        let firstResponse = try await client.searchItems(request)
        let secondResponse = try await client.searchItems(request)

        #expect(firstResponse.errors.count == 1)
        #expect(secondResponse.errors.isEmpty)
        #expect(await transport.requests().count == 2)
    }

    @Test("O cache em memória descarta a entrada menos recentemente usada")
    func responseCacheEvictsLeastRecentlyUsedEntry() async throws {
        let cache = ResponseCache()

        for index in 0..<256 {
            await cache.store(Data([UInt8(index % 255)]), for: "key-\(index)", ttl: 60)
        }

        _ = await cache.value(for: "key-0")
        await cache.store(Data([255]), for: "key-256", ttl: 60)

        #expect(await cache.value(for: "key-0") != nil)
        #expect(await cache.value(for: "key-1") == nil)
    }

    @Test("Retry-After define o atraso mínimo de nova tentativa")
    func retryAfterHeaderDefinesMinimumRetryDelay() async throws {
        let transport = MockTransport(responses: [
            .status(429, "{\"message\": \"Too many requests\"}", headers: ["retry-after": "1"]),
            .json("{\"searchResult\": {\"items\": []}}")
        ])
        let configuration = AmazonCreatorsConfiguration(
            cachePolicy: .disabled,
            requestsPerSecond: 1_000,
            maxRetryAttempts: 1,
            retryBaseDelay: .zero
        )
        let client = makeClient(configuration: configuration, transport: transport)
        let startDate = Date.now

        _ = try await client.searchItems(SearchItemsRequest(keywords: "echo"))

        #expect(Date.now.timeIntervalSince(startDate) >= 0.9)
    }

    @Test("O resumo de variações preserva dimensões plurais")
    func variationSummaryPreservesPluralDimensions() async throws {
        let source = Data("""
        {
          "variationsResult": {
            "items": [],
            "variationSummary": {
              "pageCount": 2,
              "variationCount": 13,
              "variationDimensions": [{
                "displayName": "Color",
                "name": "color_name",
                "values": ["Blue", "Red"]
              }]
            }
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(GetVariationsResponse.self, from: source)

        #expect(response.variationSummary?.variationDimension == .array([
            .object([
                "displayName": .string("Color"),
                "name": .string("color_name"),
                "values": .array([.string("Blue"), .string("Red")])
            ])
        ]))
        #expect(response.variationSummary?.pageCount == 2)
        #expect(response.variationSummary?.variationCount == 13)
        #expect(response.variationSummary?.variationDimensions?.first?.name == "color_name")
    }

    @Test("Sales rank requisitado é preservado pelo modelo")
    func productPreservesBrowseNodeSalesRank() throws {
        let source = Data("""
        {
          "asin": "B09B2SBHQK",
          "detailPageURL": "https://www.amazon.com/dp/B09B2SBHQK?tag=store-20",
          "browseNodeInfo": {
            "browseNodes": [{
              "id": "123",
              "salesRank": 42
            }]
          }
        }
        """.utf8)
        let product = try JSONDecoder().decode(Product.self, from: source)
        let encoded = try JSONEncoder().encode(product)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let browseNodeInfo = try #require(object["browseNodeInfo"] as? [String: Any])
        let browseNodes = try #require(browseNodeInfo["browseNodes"] as? [[String: Any]])

        #expect(browseNodes.first?["salesRank"] as? Int == 42)
    }

    @Test("Validações semânticas impedem requisições inválidas")
    func semanticValidationPreventsInvalidRequests() async throws {
        let transport = MockTransport(responses: [])
        let client = makeClient(transport: transport)

        await #expect(throws: AmazonCreatorsError.invalidRequest("SearchItems exige ao menos um de keywords, actor, artist, author, brand ou title.")) {
            _ = try await client.searchItems(SearchItemsRequest(options: SearchItemsOptions(browseNodeID: "123")))
        }
        await #expect(throws: AmazonCreatorsError.invalidRequest("keywords não pode ser vazio.")) {
            _ = try await client.searchItems(SearchItemsRequest(keywords: " \n"))
        }
        await #expect(throws: AmazonCreatorsError.invalidRequest("minimumPrice deve ser positivo.")) {
            _ = try await client.searchItems(
                SearchItemsRequest(
                    keywords: "echo",
                    options: SearchItemsOptions(minimumPrice: 0)
                )
            )
        }
        await #expect(throws: AmazonCreatorsError.invalidRequest("minimumPrice não pode ser maior que maximumPrice.")) {
            _ = try await client.searchItems(
                SearchItemsRequest(
                    keywords: "echo",
                    options: SearchItemsOptions(maximumPrice: 99, minimumPrice: 100)
                )
            )
        }
        await #expect(throws: AmazonCreatorsError.invalidRequest("ids deve conter apenas Browse Node IDs numéricos ASCII positivos.")) {
            _ = try await client.getBrowseNodes(GetBrowseNodesRequest(ids: [""]))
        }
        await #expect(throws: AmazonCreatorsError.invalidRequest("ids deve conter apenas Browse Node IDs numéricos ASCII positivos.")) {
            _ = try await client.getBrowseNodes(GetBrowseNodesRequest(ids: ["0"]))
        }
        await #expect(throws: AmazonCreatorsError.invalidRequest("ids deve conter apenas Browse Node IDs numéricos ASCII positivos.")) {
            _ = try await client.getBrowseNodes(GetBrowseNodesRequest(ids: ["١٢٣"]))
        }

        #expect(await transport.requests().isEmpty)
    }

    private func makeClient(
        credentialVersion: CredentialVersion = .v3NorthAmerica,
        configuration: AmazonCreatorsConfiguration = .testDefault,
        transport: MockTransport
    ) -> AmazonCreatorsClient {
        AmazonCreatorsClient(
            accessToken: "token-v3",
            credentialVersion: credentialVersion,
            partnerTag: "store-20",
            marketplace: .brazil,
            configuration: configuration,
            transport: transport
        )
    }

    private func makeProviderClient(
        transport: MockTransport,
        accessTokenProvider: @escaping AccessTokenProvider,
        accessTokenRefreshProvider: @escaping AccessTokenRefreshProvider
    ) -> AmazonCreatorsClient {
        AmazonCreatorsClient(
            accessTokenProvider: accessTokenProvider,
            accessTokenRefreshProvider: accessTokenRefreshProvider,
            credentialVersion: .v3NorthAmerica,
            partnerTag: "store-20",
            marketplace: .brazil,
            configuration: .testDefault,
            transport: transport
        )
    }
}

private actor TokenProviderSpy {

    private var tokens: [String]
    private var count = 0

    init(tokens: [String]) {
        self.tokens = tokens
    }

    func nextToken() throws -> String {
        guard !tokens.isEmpty else {
            throw AmazonCreatorsError.unauthorized(APIProblem(message: "Nenhum token simulado foi configurado."))
        }

        count += 1

        return tokens.removeFirst()
    }

    func invocationCount() -> Int {
        count
    }
}

private actor MockTransport: HTTPTransport {

    private var queuedResponses: [TransportResponse]
    private var capturedRequests: [URLRequest]

    init(responses: [TransportResponse]) {
        self.queuedResponses = responses
        self.capturedRequests = []
    }

    func send(_ request: URLRequest) async throws -> TransportResponse {
        capturedRequests.append(request)

        guard !queuedResponses.isEmpty else {
            throw AmazonCreatorsError.transport("Nenhuma resposta simulada foi configurada.")
        }

        return queuedResponses.removeFirst()
    }

    func requests() -> [URLRequest] {
        capturedRequests
    }
}

private extension TransportResponse {

    static func json(_ source: String) -> TransportResponse {
        TransportResponse(data: Data(source.utf8), statusCode: 200, headers: [:])
    }

    static func status(_ code: Int, _ source: String, headers: [String: String] = [:]) -> TransportResponse {
        TransportResponse(data: Data(source.utf8), statusCode: code, headers: headers)
    }
}
