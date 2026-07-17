import Foundation

/// Gera e mantém em memória um access token OAuth2 da Creators API.
///
/// O provider conserva o credential secret somente em memória. Como qualquer Secret incluído em aplicativo distribuído pode ser extraído, proteja a distribuição e a rotação das credenciais conforme o risco da integração.
public actor AmazonCreatorsOAuth2TokenProvider {

    // MARK: - Private Properties

    private let credentials: AmazonCreatorsCredentials
    private let transport: any HTTPTransport
    private var cachedToken: CachedAccessToken?
    private var tokenRequestInFlight: Task<CachedAccessToken, Error>?

    // MARK: - Initializer

    /// Cria um provider que usa `URLSession` para requisitar tokens OAuth2.
    public init(_ credentials: AmazonCreatorsCredentials) {
        self.credentials = credentials
        transport = URLSessionTransport()
        cachedToken = nil
        tokenRequestInFlight = nil
    }

    init(_ credentials: AmazonCreatorsCredentials, transport: any HTTPTransport) {
        self.credentials = credentials
        self.transport = transport
        cachedToken = nil
        tokenRequestInFlight = nil
    }

    // MARK: - Public Methods

    /// Retorna o token em cache enquanto válido; caso contrário, solicita um novo token à Amazon.
    public func accessToken() async throws -> String {
        if let cachedToken, cachedToken.expirationDate > .now {

            return cachedToken.value
        }

        let newToken = try await requestToken()

        cachedToken = newToken

        return newToken.value
    }

    /// Descarta o token em cache e solicita um novo token à Amazon.
    public func refreshAccessToken() async throws -> String {
        cachedToken = nil

        let newToken = try await requestToken()

        cachedToken = newToken

        return newToken.value
    }

    // MARK: - Private Methods

    private func requestToken() async throws -> CachedAccessToken {
        if let tokenRequestInFlight {

            return try await tokenRequestInFlight.value
        }

        let request = try makeTokenRequest()
        let transport = transport
        let tokenRequest: Task<CachedAccessToken, Error> = Task {
            try await Self.fetchToken(from: request, transport: transport)
        }

        tokenRequestInFlight = tokenRequest

        do {
            let token = try await tokenRequest.value

            tokenRequestInFlight = nil

            return token
        } catch {
            tokenRequestInFlight = nil

            throw error
        }
    }

    private func makeTokenRequest() throws -> URLRequest {
        try validateCredentials()

        var request = URLRequest(url: credentials.credentialVersion.oauth2TokenEndpoint)

        request.httpMethod = "POST"
        request.timeoutInterval = 30

        if credentials.credentialVersion.isLoginWithAmazon {
            let body = OAuth2TokenRequest(
                credentials.credentialID,
                clientSecret: credentials.credentialSecret,
                scope: credentials.credentialVersion.oauth2Scope
            )

            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else {
            var components = URLComponents()
            components.queryItems = [
                URLQueryItem(name: "grant_type", value: "client_credentials"),
                URLQueryItem(name: "client_id", value: credentials.credentialID),
                URLQueryItem(name: "client_secret", value: credentials.credentialSecret),
                URLQueryItem(name: "scope", value: credentials.credentialVersion.oauth2Scope)
            ]

            guard let encodedForm = components.percentEncodedQuery else {
                throw AmazonCreatorsError.decoding("Não foi possível serializar a requisição OAuth2.")
            }

            request.httpBody = Data(encodedForm.utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    private func validateCredentials() throws {
        guard !credentials.credentialID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AmazonCreatorsError.invalidRequest("credentialID não pode ser vazio.")
        }

        guard !credentials.credentialSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AmazonCreatorsError.invalidRequest("credentialSecret não pode ser vazio.")
        }
    }

    private static func fetchToken(
        from request: URLRequest,
        transport: any HTTPTransport
    ) async throws -> CachedAccessToken {
        let response = try await transport.send(request)

        guard (200...299).contains(response.statusCode) else {
            throw serviceError(from: response)
        }

        let tokenResponse: OAuth2TokenResponse

        do {
            tokenResponse = try JSONDecoder().decode(OAuth2TokenResponse.self, from: response.data)
        } catch {
            throw AmazonCreatorsError.decoding("Não foi possível decodificar a resposta OAuth2: \(error.localizedDescription)")
        }

        guard !tokenResponse.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AmazonCreatorsError.unauthorized(APIProblem(message: "A Amazon não retornou um access token OAuth2."))
        }

        let lifetime = max(0, (tokenResponse.expiresIn ?? 3_600) - 30)

        return CachedAccessToken(
            value: tokenResponse.accessToken,
            expirationDate: .now.addingTimeInterval(TimeInterval(lifetime))
        )
    }

    private static func serviceError(from response: TransportResponse) -> AmazonCreatorsError {
        let decoder = JSONDecoder()
        let problem: APIProblem

        if let oauth2Error = try? decoder.decode(OAuth2ErrorResponse.self, from: response.data), let oauth2Problem = oauth2Error.apiProblem {
            problem = oauth2Problem
        } else {
            problem = (try? decoder.decode(APIProblem.self, from: response.data)) ?? APIProblem(message: "A autenticação OAuth2 retornou HTTP \(response.statusCode).")
        }

        switch response.statusCode {
        case 400, 401:

            return .unauthorized(problem)
        case 403:

            return .accessDenied(problem)
        case 429:

            return .throttled(problem)
        case 500...599:

            return .server(problem)
        default:

            return .transport("A autenticação OAuth2 retornou HTTP \(response.statusCode).")
        }
    }
}

private struct CachedAccessToken: Sendable {

    // MARK: - Private Properties

    fileprivate let value: String
    fileprivate let expirationDate: Date
}

private struct OAuth2TokenRequest: Encodable {

    // MARK: - Private Properties

    private let grantType = "client_credentials"
    private let clientID: String
    private let clientSecret: String
    private let scope: String

    // MARK: - Initializer

    init(_ clientID: String, clientSecret: String, scope: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.scope = scope
    }

    // MARK: - Private Properties

    private enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case clientID = "client_id"
        case clientSecret = "client_secret"
        case scope
    }
}

private struct OAuth2TokenResponse: Decodable {

    // MARK: - Private Properties

    fileprivate let accessToken: String
    fileprivate let expiresIn: Int?

    // MARK: - Private Properties

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private struct OAuth2ErrorResponse: Decodable {

    // MARK: - Private Properties

    private let code: String?
    private let message: String?

    // MARK: - Private Properties

    fileprivate var apiProblem: APIProblem? {
        guard code != nil || message != nil else {

            return nil
        }

        return APIProblem(code: code, message: message)
    }

    // MARK: - Private Properties

    private enum CodingKeys: String, CodingKey {
        case code = "error"
        case message = "error_description"
    }
}
