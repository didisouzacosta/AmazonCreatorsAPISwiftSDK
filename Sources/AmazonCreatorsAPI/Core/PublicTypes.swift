import Foundation

/// A versão da credencial usada para obter o access token da Creators API.
public enum CredentialVersion: String, CaseIterable, Codable, Sendable {
    /// Credencial v2 para a região da América do Norte.
    case v2NorthAmerica = "2.1"
    /// Credencial v2 para a região da Europa.
    case v2Europe = "2.2"
    /// Credencial v2 para a região do Extremo Oriente.
    case v2FarEast = "2.3"
    /// Credencial v3 para a região da América do Norte.
    case v3NorthAmerica = "3.1"
    /// Credencial v3 para a região da Europa.
    case v3Europe = "3.2"
    /// Credencial v3 para a região do Extremo Oriente.
    case v3FarEast = "3.3"

    var authorizationValueSuffix: String? {
        switch self {
        case .v2NorthAmerica, .v2Europe, .v2FarEast:
            return ", Version \(rawValue)"
        case .v3NorthAmerica, .v3Europe, .v3FarEast:
            return nil
        }
    }
}

/// Um marketplace da Amazon aceito pela Creators API.
public enum Marketplace: String, CaseIterable, Codable, Sendable {
    /// Amazon Austrália.
    case australia = "www.amazon.com.au"
    /// Amazon Bélgica.
    case belgium = "www.amazon.com.be"
    /// Amazon Brasil.
    case brazil = "www.amazon.com.br"
    /// Amazon Canadá.
    case canada = "www.amazon.ca"
    /// Amazon Egito.
    case egypt = "www.amazon.eg"
    /// Amazon França.
    case france = "www.amazon.fr"
    /// Amazon Alemanha.
    case germany = "www.amazon.de"
    /// Amazon Índia.
    case india = "www.amazon.in"
    /// Amazon Irlanda.
    case ireland = "www.amazon.ie"
    /// Amazon Itália.
    case italy = "www.amazon.it"
    /// Amazon Japão.
    case japan = "www.amazon.co.jp"
    /// Amazon México.
    case mexico = "www.amazon.com.mx"
    /// Amazon Países Baixos.
    case netherlands = "www.amazon.nl"
    /// Amazon Polônia.
    case poland = "www.amazon.pl"
    /// Amazon Singapura.
    case singapore = "www.amazon.sg"
    /// Amazon Arábia Saudita.
    case saudiArabia = "www.amazon.sa"
    /// Amazon Espanha.
    case spain = "www.amazon.es"
    /// Amazon Suécia.
    case sweden = "www.amazon.se"
    /// Amazon Turquia.
    case turkey = "www.amazon.com.tr"
    /// Amazon Emirados Árabes Unidos.
    case unitedArabEmirates = "www.amazon.ae"
    /// Amazon Reino Unido.
    case unitedKingdom = "www.amazon.co.uk"
    /// Amazon Estados Unidos.
    case unitedStates = "www.amazon.com"
}

/// Um identificador de atribuição da conta Amazon Associates.
public struct PartnerTag: Codable, Hashable, Sendable {

    /// O valor enviado no parâmetro `partnerTag` de cada chamada.
    public let value: String

    /// Cria um partner tag que será validado antes da primeira chamada de rede.
    public init(_ value: String) {
        self.value = value
    }
}

/// Uma fonte assíncrona de access tokens temporários.
public typealias AccessTokenProvider = @Sendable () async throws -> String

/// Uma fonte assíncrona de um novo access token após uma falha de autenticação.
public typealias AccessTokenRefreshProvider = @Sendable () async throws -> String

/// As opções de cache de respostas do SDK.
public enum CachePolicy: Sendable {
    /// Não armazena respostas da Creators API.
    case disabled
    /// Armazena respostas somente em memória pelo TTL permitido pela Amazon.
    case memory
}

/// Configurações de rede aplicadas por um cliente da Creators API.
public struct AmazonCreatorsConfiguration: Sendable {

    /// A política de cache para respostas de catálogo.
    public let cachePolicy: CachePolicy
    /// O máximo de respostas mantidas no cache em memória.
    public let maxCachedResponses: Int
    /// O máximo de requisições que esse cliente fará por segundo.
    public let requestsPerSecond: Int
    /// O número de novas tentativas após a tentativa inicial para respostas transitórias.
    public let maxRetryAttempts: Int
    /// O atraso base usado para backoff exponencial.
    public let retryBaseDelay: Duration
    /// O timeout de cada requisição HTTP, em segundos.
    public let requestTimeout: TimeInterval

    /// Cria uma configuração conservadora compatível com os limites iniciais da Amazon.
    public init(
        cachePolicy: CachePolicy = .memory,
        maxCachedResponses: Int = 256,
        requestsPerSecond: Int = 1,
        maxRetryAttempts: Int = 2,
        retryBaseDelay: Duration = .seconds(1),
        requestTimeout: TimeInterval = 30
    ) {
        self.cachePolicy = cachePolicy
        self.maxCachedResponses = max(1, maxCachedResponses)
        self.requestsPerSecond = max(1, requestsPerSecond)
        self.maxRetryAttempts = max(0, maxRetryAttempts)
        self.retryBaseDelay = max(.zero, retryBaseDelay)
        self.requestTimeout = max(1, requestTimeout)
    }

    static let testDefault = AmazonCreatorsConfiguration(
        cachePolicy: .disabled,
        requestsPerSecond: 1_000,
        maxRetryAttempts: 0,
        retryBaseDelay: .zero
    )
}

/// Um erro parcial ou de serviço retornado pela Creators API.
public struct APIProblem: Codable, Equatable, Sendable {

    /// O código de erro retornado pela Amazon, quando disponível.
    public let code: String?
    /// A razão estruturada retornada pela Amazon, quando disponível.
    public let reason: String?
    /// A mensagem legível retornada pela Amazon, quando disponível.
    public let message: String?
    /// Os campos que falharam na validação, quando disponíveis.
    public let fieldList: [String]?

    /// Cria uma representação de erro para testes ou integrações customizadas.
    public init(code: String? = nil, reason: String? = nil, message: String? = nil, fieldList: [String]? = nil) {
        self.code = code
        self.reason = reason
        self.message = message
        self.fieldList = fieldList
    }
}

/// Erros que podem ocorrer durante uma chamada da Creators API.
public enum AmazonCreatorsError: Error, Equatable, LocalizedError, Sendable {
    /// A solicitação não atende às restrições locais da API.
    case invalidRequest(String)
    /// O token está ausente, inválido ou expirado.
    case unauthorized(APIProblem)
    /// A Amazon rejeitou campos da solicitação.
    case validation(APIProblem)
    /// A credencial ou o partner tag não tem acesso à operação.
    case accessDenied(APIProblem)
    /// A chamada excedeu a cota da API.
    case throttled(APIProblem)
    /// A rota ou recurso requisitado não foi encontrado.
    case notFound(APIProblem)
    /// A Amazon apresentou uma falha transitória ou interna.
    case server(APIProblem)
    /// O transporte de rede falhou antes de obter uma resposta válida.
    case transport(String)
    /// A resposta recebida não corresponde ao contrato esperado.
    case decoding(String)

    /// Uma descrição apropriada para apresentação em logs controlados pelo integrador.
    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message), .transport(let message), .decoding(let message):
            return message
        case .unauthorized(let problem), .validation(let problem), .accessDenied(let problem), .throttled(let problem), .notFound(let problem), .server(let problem):
            return problem.message ?? problem.code ?? "A Creators API retornou um erro."
        }
    }
}
