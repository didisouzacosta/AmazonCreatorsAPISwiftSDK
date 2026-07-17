import Foundation

/// Um valor JSON preservado para recursos da Amazon cuja estrutura varia por categoria.
public indirect enum AmazonJSONValue: Codable, Equatable, Sendable {
    /// Um valor de texto.
    case string(String)
    /// Um número inteiro.
    case integer(Int)
    /// Um número decimal.
    case decimal(Double)
    /// Um valor booleano.
    case boolean(Bool)
    /// Uma lista de valores.
    case array([AmazonJSONValue])
    /// Um objeto com chaves de texto.
    case object([String: AmazonJSONValue])
    /// Um valor nulo.
    case null

    /// Decodifica qualquer valor JSON válido.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .decimal(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: AmazonJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([AmazonJSONValue].self) {
            self = .array(value)
        } else {
            throw AmazonCreatorsError.decoding("O recurso retornou um valor JSON não suportado.")
        }
    }

    /// Codifica o valor preservado novamente como JSON.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .decimal(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

/// Um texto localizado retornado pela Amazon.
public struct LocalizedText: Codable, Equatable, Sendable {

    /// O valor apresentado ao usuário.
    public let displayValue: String
    /// O rótulo do campo.
    public let label: String?
    /// O locale do valor.
    public let locale: String?
}

/// Um atributo localizado com diversos valores de texto.
public struct LocalizedTextList: Codable, Equatable, Sendable {

    /// Os valores apresentados ao usuário.
    public let displayValues: [String]
    /// O rótulo do campo.
    public let label: String?
    /// O locale dos valores.
    public let locale: String?
}

/// Uma imagem de produto retornada pela Amazon.
public struct ProductImage: Codable, Equatable, Sendable {

    /// A altura da imagem em pixels.
    public let height: Int?
    /// A URL da imagem.
    public let url: URL
    /// A largura da imagem em pixels.
    public let width: Int?
}

/// Um conjunto de tamanhos de uma imagem de produto.
public struct ProductImageSet: Codable, Equatable, Sendable {

    /// A imagem de maior resolução quando disponível.
    public let hiRes: ProductImage?
    /// A imagem grande.
    public let large: ProductImage?
    /// A imagem média.
    public let medium: ProductImage?
    /// A imagem pequena.
    public let small: ProductImage?
}

/// As imagens principais e de variações de um produto.
public struct ProductImages: Codable, Equatable, Sendable {

    /// Os tamanhos da imagem principal.
    public let primary: ProductImageSet?
    /// Os conjuntos de imagens das variações.
    public let variants: [ProductImageSet]?
}

/// Um browse node e suas relações retornadas pela Amazon.
public struct BrowseNode: Codable, Equatable, Sendable {

    /// O identificador do browse node.
    public let id: String
    /// O nome exibido no site da Amazon.
    public let displayName: String?
    /// O nome independente de contexto.
    public let contextFreeName: String?
    /// Indica se o node é uma raiz.
    public let isRoot: Bool?
    /// O ranking de vendas do produto dentro deste browse node, quando requisitado.
    public let salesRank: Int?
    /// A cadeia de ancestrais quando requisitada.
    public let ancestor: AmazonJSONValue?
    /// Os filhos imediatos quando requisitados.
    public let children: [BrowseNode]?
}

/// Informações de browse nodes associadas a um produto.
public struct ProductBrowseNodeInfo: Codable, Equatable, Sendable {

    /// Os browse nodes associados ao produto.
    public let browseNodes: [BrowseNode]?
    /// O ranking global de vendas do site.
    public let websiteSalesRank: AmazonJSONValue?
}

/// Informações detalhadas de um produto, determinadas pelos recursos requisitados.
public struct ProductItemInfo: Codable, Equatable, Sendable {

    /// Autores, artistas, fabricantes e colaboradores.
    public let byLineInfo: AmazonJSONValue?
    /// Classificações de produto.
    public let classifications: AmazonJSONValue?
    /// Dados de conteúdo, como livros e filmes.
    public let contentInfo: AmazonJSONValue?
    /// Classificação etária.
    public let contentRating: AmazonJSONValue?
    /// Identificadores externos.
    public let externalIds: AmazonJSONValue?
    /// Características e benefícios.
    public let features: LocalizedTextList?
    /// Informações de fabricação.
    public let manufactureInfo: AmazonJSONValue?
    /// Informações não técnicas do produto.
    public let productInfo: AmazonJSONValue?
    /// Informações técnicas do produto.
    public let technicalInfo: AmazonJSONValue?
    /// O título do produto.
    public let title: LocalizedText?
    /// Dados de trade-in.
    public let tradeInInfo: AmazonJSONValue?
}

/// Uma oferta de produto retornada pela Amazon.
public struct ProductOffer: Codable, Equatable, Sendable {

    /// Informações de disponibilidade.
    public let availability: AmazonJSONValue?
    /// A condição da oferta.
    public let condition: AmazonJSONValue?
    /// Detalhes de promoção.
    public let dealDetails: AmazonJSONValue?
    /// Indica se a oferta venceu a Buy Box.
    public let isBuyBoxWinner: AmazonJSONValue?
    /// Pontos de fidelidade, quando suportados.
    public let loyaltyPoints: AmazonJSONValue?
    /// Dados do vendedor.
    public let merchantInfo: AmazonJSONValue?
    /// Dados do preço da oferta.
    public let price: AmazonJSONValue?
    /// O tipo da oferta.
    public let type: AmazonJSONValue?
}

/// O conjunto de ofertas de um produto.
public struct ProductOffers: Codable, Equatable, Sendable {

    /// As ofertas retornadas para o produto.
    public let listings: [ProductOffer]?
}

/// Um produto de catálogo e seu link de afiliado.
public struct Product: Codable, Equatable, Sendable {

    /// O ASIN do produto.
    public let asin: String
    /// A URL de detalhes emitida pela Amazon.
    public let detailPageURL: URL
    /// O link de afiliado emitido pela Amazon; use-o sem modificar parâmetros.
    public var affiliateURL: URL {
        detailPageURL
    }
    /// Os browse nodes associados ao produto.
    public let browseNodeInfo: ProductBrowseNodeInfo?
    /// As imagens requisitadas.
    public let images: ProductImages?
    /// As informações do produto requisitadas.
    public let itemInfo: ProductItemInfo?
    /// As ofertas requisitadas.
    public let offersV2: ProductOffers?
    /// O ASIN pai, quando requisitado.
    public let parentASIN: String?
    /// A pontuação de relevância retornada pela pesquisa.
    public let score: Double?
    /// Os atributos que distinguem esta variação.
    public let variationAttributes: AmazonJSONValue?
}

/// Uma dimensão usada para diferenciar variações de um produto.
public struct VariationDimension: Codable, Equatable, Sendable {

    /// O nome da dimensão visível ao usuário.
    public let displayName: String?
    /// O locale do nome de exibição.
    public let locale: String?
    /// O identificador estável da dimensão.
    public let name: String
    /// Os valores disponíveis para a dimensão.
    public let values: [String]
}

/// Um resumo de variações de um produto.
public struct VariationSummary: Codable, Equatable, Sendable {

    /// O número de páginas de variações disponíveis.
    public let pageCount: Int?
    /// O maior preço entre as variações.
    public let highestPrice: AmazonJSONValue?
    /// O menor preço entre as variações.
    public let lowestPrice: AmazonJSONValue?
    /// O número total de variações disponíveis.
    public let variationCount: Int?
    /// As dimensões estruturadas disponíveis para selecionar uma variação.
    public let variationDimensions: [VariationDimension]?
    /// As dimensões de variação disponíveis.
    public let variationDimension: AmazonJSONValue?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let price = try container.decodeIfPresent(AmazonJSONValue.self, forKey: DynamicCodingKey("price"))
        let pluralDimensions = try container.decodeIfPresent(AmazonJSONValue.self, forKey: DynamicCodingKey("variationDimensions"))
        let directHighestPrice = try container.decodeIfPresent(AmazonJSONValue.self, forKey: DynamicCodingKey("highestPrice"))
        let directLowestPrice = try container.decodeIfPresent(AmazonJSONValue.self, forKey: DynamicCodingKey("lowestPrice"))

        pageCount = try container.decodeIfPresent(Int.self, forKey: DynamicCodingKey("pageCount"))
        highestPrice = price?.objectValue?["highestPrice"] ?? directHighestPrice
        lowestPrice = price?.objectValue?["lowestPrice"] ?? directLowestPrice
        variationCount = try container.decodeIfPresent(Int.self, forKey: DynamicCodingKey("variationCount"))
        variationDimensions = try container.decodeIfPresent([VariationDimension].self, forKey: DynamicCodingKey("variationDimensions"))
        variationDimension = try container.decodeIfPresent(AmazonJSONValue.self, forKey: DynamicCodingKey("variationDimension")) ?? pluralDimensions
    }
}

/// A resposta da operação GetItems.
public struct GetItemsResponse: Decodable, Sendable {

    /// Os produtos encontrados.
    public let items: [Product]
    /// Erros parciais de itens que não puderam ser retornados.
    public let errors: [APIProblem]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let result = try container.decodeIfPresent(ItemsContainer.self, forKey: DynamicCodingKey("itemsResult")) ?? container.decodeIfPresent(ItemsContainer.self, forKey: DynamicCodingKey("itemResults"))

        items = result?.items ?? []
        errors = try container.decodeIfPresent([APIProblem].self, forKey: DynamicCodingKey("errors")) ?? []
    }
}

/// A resposta da operação SearchItems.
public struct SearchItemsResponse: Decodable, Sendable {

    /// Os produtos encontrados na página atual.
    public let items: [Product]
    /// O total de resultados da pesquisa.
    public let totalResultCount: Int?
    /// A URL de resultados da pesquisa no site da Amazon.
    public let searchURL: URL?
    /// Os refinamentos dinâmicos requisitados.
    public let searchRefinements: AmazonJSONValue?
    /// Erros parciais de pesquisa.
    public let errors: [APIProblem]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let result = try container.decodeIfPresent(SearchContainer.self, forKey: DynamicCodingKey("searchResult"))

        items = result?.items ?? []
        totalResultCount = result?.totalResultCount
        searchURL = result?.searchURL
        searchRefinements = result?.searchRefinements
        errors = try container.decodeIfPresent([APIProblem].self, forKey: DynamicCodingKey("errors")) ?? []
    }
}

/// A resposta da operação GetVariations.
public struct GetVariationsResponse: Decodable, Sendable {

    /// Os produtos de variação encontrados.
    public let items: [Product]
    /// O resumo de preços e dimensões quando requisitado.
    public let variationSummary: VariationSummary?
    /// Erros parciais de variações.
    public let errors: [APIProblem]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let result = try container.decodeIfPresent(VariationsContainer.self, forKey: DynamicCodingKey("variationsResult"))

        items = result?.items ?? []
        variationSummary = result?.variationSummary
        errors = try container.decodeIfPresent([APIProblem].self, forKey: DynamicCodingKey("errors")) ?? []
    }
}

/// A resposta da operação GetBrowseNodes.
public struct GetBrowseNodesResponse: Decodable, Sendable {

    /// Os browse nodes encontrados.
    public let browseNodes: [BrowseNode]
    /// Erros parciais de browse nodes.
    public let errors: [APIProblem]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let result = try container.decodeIfPresent(BrowseNodesContainer.self, forKey: DynamicCodingKey("browseNodesResult"))

        browseNodes = result?.browseNodes ?? []
        errors = try container.decodeIfPresent([APIProblem].self, forKey: DynamicCodingKey("errors")) ?? []
    }
}

private struct ItemsContainer: Decodable {

    let items: [Product]
}

private struct SearchContainer: Decodable {

    let items: [Product]
    let totalResultCount: Int?
    let searchURL: URL?
    let searchRefinements: AmazonJSONValue?
}

private struct VariationsContainer: Decodable {

    let items: [Product]
    let variationSummary: VariationSummary?
}

private struct BrowseNodesContainer: Decodable {

    let browseNodes: [BrowseNode]
}

private struct DynamicCodingKey: CodingKey {

    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension AmazonJSONValue {

    var objectValue: [String: AmazonJSONValue]? {
        guard case .object(let value) = self else {
            return nil
        }

        return value
    }
}
