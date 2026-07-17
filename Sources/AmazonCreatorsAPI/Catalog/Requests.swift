import Foundation

/// Um recurso que pode ser requisitado nas operações de catálogo compatíveis.
public enum CatalogResource: String, CaseIterable, Codable, Hashable, Sendable {
    /// Browse nodes associados ao produto.
    case browseNodes = "browseNodeInfo.browseNodes"
    /// A árvore de ancestrais dos browse nodes do produto.
    case browseNodesAncestor = "browseNodeInfo.browseNodes.ancestor"
    /// O ranking de venda por browse node.
    case browseNodesSalesRank = "browseNodeInfo.browseNodes.salesRank"
    /// O ranking global no site do marketplace.
    case websiteSalesRank = "browseNodeInfo.websiteSalesRank"
    /// A imagem principal pequena.
    case primarySmall = "images.primary.small"
    /// A imagem principal média.
    case primaryMedium = "images.primary.medium"
    /// A imagem principal grande.
    case primaryLarge = "images.primary.large"
    /// As imagens de variação pequenas.
    case variantSmall = "images.variants.small"
    /// As imagens de variação médias.
    case variantMedium = "images.variants.medium"
    /// As imagens de variação grandes.
    case variantLarge = "images.variants.large"
    /// Autores, artistas, fabricantes e colaboradores do produto.
    case byLineInfo = "itemInfo.byLineInfo"
    /// Classificações do produto.
    case classifications = "itemInfo.classifications"
    /// Informações de conteúdo, como livros e filmes.
    case contentInfo = "itemInfo.contentInfo"
    /// Classificação etária do conteúdo.
    case contentRating = "itemInfo.contentRating"
    /// Identificadores externos do produto.
    case externalIDs = "itemInfo.externalIds"
    /// Características e benefícios do produto.
    case features = "itemInfo.features"
    /// Informações de fabricação.
    case manufactureInfo = "itemInfo.manufactureInfo"
    /// Informações não técnicas do produto.
    case productInfo = "itemInfo.productInfo"
    /// Especificações técnicas do produto.
    case technicalInfo = "itemInfo.technicalInfo"
    /// O título do produto.
    case title = "itemInfo.title"
    /// Informações de trade-in.
    case tradeInInfo = "itemInfo.tradeInInfo"
    /// Disponibilidade de uma oferta.
    case offerAvailability = "offersV2.listings.availability"
    /// Condição de uma oferta.
    case offerCondition = "offersV2.listings.condition"
    /// Detalhes de promoção de uma oferta.
    case offerDealDetails = "offersV2.listings.dealDetails"
    /// Indicação de vencedora da Buy Box.
    case offerIsBuyBoxWinner = "offersV2.listings.isBuyBoxWinner"
    /// Pontos de fidelidade de uma oferta.
    case offerLoyaltyPoints = "offersV2.listings.loyaltyPoints"
    /// Informações do vendedor de uma oferta.
    case offerMerchantInfo = "offersV2.listings.merchantInfo"
    /// Preço de uma oferta.
    case offerPrice = "offersV2.listings.price"
    /// Tipo de uma oferta.
    case offerType = "offersV2.listings.type"
    /// O ASIN pai de um produto.
    case parentASIN = "parentASIN"
    /// Refinamentos dinâmicos de pesquisa.
    case searchRefinements = "searchRefinements"
    /// Maior preço entre as variações.
    case variationHighestPrice = "variationSummary.price.highestPrice"
    /// Menor preço entre as variações.
    case variationLowestPrice = "variationSummary.price.lowestPrice"
    /// Dimensões pelas quais um produto varia.
    case variationDimension = "variationSummary.variationDimension"
    /// Ancestrais de um browse node consultado diretamente.
    case nodeAncestor = "browseNodes.ancestor"
    /// Filhos de um browse node consultado diretamente.
    case nodeChildren = "browseNodes.children"

    /// Os recursos mínimos para renderizar um cartão de produto com preço quando disponível.
    public static let productCard: [CatalogResource] = [.title, .primaryMedium, .offerPrice, .offerAvailability]
}

/// A condição de produto usada para filtrar ofertas.
public enum ProductCondition: String, Codable, Sendable {
    /// Inclui ofertas novas e usadas.
    case any = "Any"
    /// Inclui somente ofertas novas.
    case new = "New"
}

/// Um filtro de disponibilidade da pesquisa.
public enum SearchAvailability: String, Codable, Sendable {
    /// Retorna itens disponíveis.
    case available = "Available"
    /// Inclui itens fora de estoque.
    case includeOutOfStock = "IncludeOutOfStock"
}

/// Um benefício de entrega usado como filtro de pesquisa.
public enum DeliveryFlag: String, Codable, Sendable {
    /// Produtos elegíveis para envio internacional.
    case amazonGlobal = "AmazonGlobal"
    /// Produtos com frete grátis.
    case freeShipping = "FreeShipping"
    /// Produtos entregues pela Amazon.
    case fulfilledByAmazon = "FulfilledByAmazon"
    /// Produtos elegíveis ao Prime.
    case prime = "Prime"
}

/// Uma ordenação aceita pela pesquisa de produtos.
public enum SearchSort: String, Codable, Sendable {
    /// Ordena pela média de avaliações dos clientes.
    case averageCustomerReviews = "AvgCustomerReviews"
    /// Ordena por produtos em destaque.
    case featured = "Featured"
    /// Ordena por lançamentos mais recentes.
    case newestArrivals = "NewestArrivals"
    /// Ordena do maior para o menor preço.
    case priceHighToLow = "Price:HighToLow"
    /// Ordena do menor para o maior preço.
    case priceLowToHigh = "Price:LowToHigh"
    /// Ordena por relevância.
    case relevance = "Relevance"
}

/// Uma consulta para recuperar produtos por ASIN.
public struct GetItemsRequest: Sendable {

    /// Os ASINs a consultar, de um a dez valores.
    public let itemIDs: [String]
    /// A condição desejada para as ofertas retornadas.
    public let condition: ProductCondition?
    /// A moeda ISO 4217 desejada para preços.
    public let currencyOfPreference: String?
    /// O idioma preferido, no formato `pt_BR`, por exemplo.
    public let languageOfPreference: String?
    /// Os recursos a retornar.
    public let resources: [CatalogResource]

    /// Cria uma consulta de itens por ASIN.
    public init(
        itemIDs: [String],
        condition: ProductCondition? = nil,
        currencyOfPreference: String? = nil,
        languageOfPreference: String? = nil,
        resources: [CatalogResource] = CatalogResource.productCard
    ) {
        self.itemIDs = itemIDs
        self.condition = condition
        self.currencyOfPreference = currencyOfPreference
        self.languageOfPreference = languageOfPreference
        self.resources = resources
    }
}

/// Opções avançadas para `SearchItems`.
public struct SearchItemsOptions: Sendable {

    /// Um ator associado ao item.
    public let actor: String?
    /// Um artista associado ao item.
    public let artist: String?
    /// Um autor associado ao item.
    public let author: String?
    /// A disponibilidade desejada.
    public let availability: SearchAvailability?
    /// Uma marca a filtrar.
    public let brand: String?
    /// Um browse node a filtrar.
    public let browseNodeID: String?
    /// A condição desejada para ofertas.
    public let condition: ProductCondition?
    /// A moeda ISO 4217 desejada para preços.
    public let currencyOfPreference: String?
    /// Programas de entrega desejados.
    public let deliveryFlags: [DeliveryFlag]?
    /// Itens por página, de um a dez.
    public let itemCount: Int?
    /// Página de resultados, de um a dez.
    public let itemPage: Int?
    /// O idioma preferido, no formato `pt_BR`, por exemplo.
    public let languageOfPreference: String?
    /// O preço máximo em unidades mínimas da moeda.
    public let maximumPrice: Int?
    /// O preço mínimo em unidades mínimas da moeda.
    public let minimumPrice: Int?
    /// A avaliação mínima de clientes.
    public let minimumReviewsRating: Int?
    /// O percentual mínimo de desconto.
    public let minimumSavingPercent: Int?
    /// Propriedades reservadas documentadas pela Amazon.
    public let properties: [String: String]?
    /// Os recursos a retornar.
    public let resources: [CatalogResource]
    /// O índice ou categoria de busca.
    public let searchIndex: String?
    /// A ordenação dos resultados.
    public let sortBy: SearchSort?
    /// Um título a filtrar.
    public let title: String?

    /// Cria opções de pesquisa. Valores ausentes usam os padrões da Amazon.
    public init(
        actor: String? = nil,
        artist: String? = nil,
        author: String? = nil,
        availability: SearchAvailability? = nil,
        brand: String? = nil,
        browseNodeID: String? = nil,
        condition: ProductCondition? = nil,
        currencyOfPreference: String? = nil,
        deliveryFlags: [DeliveryFlag]? = nil,
        itemCount: Int? = nil,
        itemPage: Int? = nil,
        languageOfPreference: String? = nil,
        maximumPrice: Int? = nil,
        minimumPrice: Int? = nil,
        minimumReviewsRating: Int? = nil,
        minimumSavingPercent: Int? = nil,
        properties: [String: String]? = nil,
        resources: [CatalogResource] = CatalogResource.productCard,
        searchIndex: String? = nil,
        sortBy: SearchSort? = nil,
        title: String? = nil
    ) {
        self.actor = actor
        self.artist = artist
        self.author = author
        self.availability = availability
        self.brand = brand
        self.browseNodeID = browseNodeID
        self.condition = condition
        self.currencyOfPreference = currencyOfPreference
        self.deliveryFlags = deliveryFlags
        self.itemCount = itemCount
        self.itemPage = itemPage
        self.languageOfPreference = languageOfPreference
        self.maximumPrice = maximumPrice
        self.minimumPrice = minimumPrice
        self.minimumReviewsRating = minimumReviewsRating
        self.minimumSavingPercent = minimumSavingPercent
        self.properties = properties
        self.resources = resources
        self.searchIndex = searchIndex
        self.sortBy = sortBy
        self.title = title
    }
}

/// Uma consulta de pesquisa de produtos.
public struct SearchItemsRequest: Sendable {

    /// As palavras-chave da pesquisa. Use `nil` para pesquisar apenas pelos filtros avançados.
    public let keywords: String?
    /// Os filtros e recursos adicionais.
    public let options: SearchItemsOptions

    /// Cria uma consulta de pesquisa simples por palavras-chave.
    public init(keywords: String, options: SearchItemsOptions = SearchItemsOptions()) {
        self.keywords = keywords
        self.options = options
    }

    /// Cria uma consulta de pesquisa orientada apenas por filtros.
    public init(options: SearchItemsOptions) {
        self.keywords = nil
        self.options = options
    }
}

/// Uma consulta das variações de um ASIN.
public struct GetVariationsRequest: Sendable {

    /// O ASIN pai ou filho cujas variações serão retornadas.
    public let asin: String
    /// A condição desejada para as ofertas.
    public let condition: ProductCondition?
    /// A moeda ISO 4217 desejada para preços.
    public let currencyOfPreference: String?
    /// O idioma preferido, no formato `pt_BR`, por exemplo.
    public let languageOfPreference: String?
    /// Os recursos a retornar.
    public let resources: [CatalogResource]
    /// O número de variações por página, de um a dez.
    public let variationCount: Int?
    /// A página de variações.
    public let variationPage: Int?

    /// Cria uma consulta de variações.
    public init(
        asin: String,
        condition: ProductCondition? = nil,
        currencyOfPreference: String? = nil,
        languageOfPreference: String? = nil,
        resources: [CatalogResource] = CatalogResource.productCard + [.variationHighestPrice, .variationLowestPrice, .variationDimension],
        variationCount: Int? = nil,
        variationPage: Int? = nil
    ) {
        self.asin = asin
        self.condition = condition
        self.currencyOfPreference = currencyOfPreference
        self.languageOfPreference = languageOfPreference
        self.resources = resources
        self.variationCount = variationCount
        self.variationPage = variationPage
    }
}

/// Uma consulta da hierarquia de browse nodes.
public struct GetBrowseNodesRequest: Sendable {

    /// Os IDs de browse node a consultar, de um a dez valores.
    public let ids: [String]
    /// O idioma preferido, no formato `pt_BR`, por exemplo.
    public let languageOfPreference: String?
    /// Os recursos de árvore a retornar.
    public let resources: [CatalogResource]

    /// Cria uma consulta de browse nodes.
    public init(
        ids: [String],
        languageOfPreference: String? = nil,
        resources: [CatalogResource] = [.nodeAncestor, .nodeChildren]
    ) {
        self.ids = ids
        self.languageOfPreference = languageOfPreference
        self.resources = resources
    }
}

extension GetItemsRequest {

    func validate() throws {
        guard (1...10).contains(itemIDs.count) else {
            throw AmazonCreatorsError.invalidRequest("itemIDs deve conter entre 1 e 10 valores.")
        }

        guard itemIDs.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AmazonCreatorsError.invalidRequest("itemIDs não pode conter valores vazios.")
        }

        try validateCurrencyOfPreference(currencyOfPreference)
        try validateLanguageOfPreference(languageOfPreference)
        try validateResources(resources, allowed: CatalogResource.itemResources)
    }
}

extension SearchItemsRequest {

    func validate() throws {
        let searchTerms = [
            ("keywords", keywords),
            ("actor", options.actor),
            ("artist", options.artist),
            ("author", options.author),
            ("brand", options.brand),
            ("title", options.title)
        ]

        for (parameter, value) in searchTerms {
            try validateOptionalNonEmpty(value, parameter: parameter)
        }

        guard searchTerms.contains(where: { $0.1 != nil }) else {
            throw AmazonCreatorsError.invalidRequest("SearchItems exige ao menos um de keywords, actor, artist, author, brand ou title.")
        }

        try validateOptionalNonEmpty(options.searchIndex, parameter: "searchIndex")
        try validateCurrencyOfPreference(options.currencyOfPreference)
        try validateLanguageOfPreference(options.languageOfPreference)

        if let browseNodeID = options.browseNodeID {
            try validatePositiveBrowseNodeID(browseNodeID, parameter: "browseNodeID")
        }

        if let itemCount = options.itemCount, !(1...10).contains(itemCount) {
            throw AmazonCreatorsError.invalidRequest("itemCount deve estar entre 1 e 10.")
        }

        if let itemPage = options.itemPage, !(1...10).contains(itemPage) {
            throw AmazonCreatorsError.invalidRequest("itemPage deve estar entre 1 e 10.")
        }

        if let minimumReviewsRating = options.minimumReviewsRating, !(1...4).contains(minimumReviewsRating) {
            throw AmazonCreatorsError.invalidRequest("minimumReviewsRating deve estar entre 1 e 4.")
        }

        if let minimumSavingPercent = options.minimumSavingPercent, !(1...99).contains(minimumSavingPercent) {
            throw AmazonCreatorsError.invalidRequest("minimumSavingPercent deve estar entre 1 e 99.")
        }

        if let minimumPrice = options.minimumPrice, minimumPrice <= 0 {
            throw AmazonCreatorsError.invalidRequest("minimumPrice deve ser positivo.")
        }

        if let maximumPrice = options.maximumPrice, maximumPrice <= 0 {
            throw AmazonCreatorsError.invalidRequest("maximumPrice deve ser positivo.")
        }

        if let minimumPrice = options.minimumPrice, let maximumPrice = options.maximumPrice, minimumPrice > maximumPrice {
            throw AmazonCreatorsError.invalidRequest("minimumPrice não pode ser maior que maximumPrice.")
        }

        try validateResources(options.resources, allowed: CatalogResource.searchResources)
    }
}

extension GetVariationsRequest {

    func validate() throws {
        guard !asin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AmazonCreatorsError.invalidRequest("asin não pode ser vazio.")
        }

        try validateCurrencyOfPreference(currencyOfPreference)
        try validateLanguageOfPreference(languageOfPreference)

        if let variationCount, !(1...10).contains(variationCount) {
            throw AmazonCreatorsError.invalidRequest("variationCount deve estar entre 1 e 10.")
        }

        if let variationPage, variationPage < 1 {
            throw AmazonCreatorsError.invalidRequest("variationPage deve ser maior que zero.")
        }

        try validateResources(resources, allowed: CatalogResource.variationResources)
    }
}

extension GetBrowseNodesRequest {

    func validate() throws {
        guard (1...10).contains(ids.count) else {
            throw AmazonCreatorsError.invalidRequest("ids deve conter entre 1 e 10 valores.")
        }

        for id in ids {
            try validatePositiveBrowseNodeID(id, parameter: "ids")
        }

        try validateLanguageOfPreference(languageOfPreference)
        try validateResources(resources, allowed: CatalogResource.browseNodeResources)
    }
}

private extension CatalogResource {

    static let itemResources: Set<CatalogResource> = Set(allCases.filter { resource in
        resource != .searchRefinements && resource != .variationHighestPrice && resource != .variationLowestPrice && resource != .variationDimension && resource != .nodeAncestor && resource != .nodeChildren
    })
    static let searchResources: Set<CatalogResource> = itemResources.union([.searchRefinements])
    static let variationResources: Set<CatalogResource> = itemResources.subtracting([.parentASIN]).union([.variationHighestPrice, .variationLowestPrice, .variationDimension])
    static let browseNodeResources: Set<CatalogResource> = [.nodeAncestor, .nodeChildren]
}

private func validateResources(_ resources: [CatalogResource], allowed: Set<CatalogResource>) throws {
    guard resources.allSatisfy(allowed.contains) else {
        throw AmazonCreatorsError.invalidRequest("Um ou mais recursos não são compatíveis com esta operação.")
    }
}

private func validateOptionalNonEmpty(_ value: String?, parameter: String) throws {
    guard let value else {
        return
    }

    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw AmazonCreatorsError.invalidRequest("\(parameter) não pode ser vazio.")
    }
}

private func validateCurrencyOfPreference(_ value: String?) throws {
    guard let value else {
        return
    }

    try validateOptionalNonEmpty(value, parameter: "currencyOfPreference")

    guard value.count == 3, value == value.uppercased(), containsOnlyASCIIAlphabeticCharacters(value) else {
        throw AmazonCreatorsError.invalidRequest("currencyOfPreference deve usar um código ISO 4217 em maiúsculas.")
    }
}

private func validateLanguageOfPreference(_ value: String?) throws {
    guard let value else {
        return
    }

    try validateOptionalNonEmpty(value, parameter: "languageOfPreference")

    let components = value.split(separator: "_", omittingEmptySubsequences: false)
    guard components.count == 2 else {
        throw AmazonCreatorsError.invalidRequest("languageOfPreference deve usar o formato ll_CC.")
    }

    let language = String(components[0])
    let country = String(components[1])
    guard (2...3).contains(language.count), country.count == 2, language == language.lowercased(), country == country.uppercased(), containsOnlyASCIIAlphabeticCharacters(language), containsOnlyASCIIAlphabeticCharacters(country) else {
        throw AmazonCreatorsError.invalidRequest("languageOfPreference deve usar o formato ll_CC.")
    }
}

private func validatePositiveBrowseNodeID(_ value: String, parameter: String) throws {
    guard !value.isEmpty, containsOnlyASCIIDigits(value), let identifier = UInt64(value), identifier > 0, identifier <= UInt64(Int64.max) else {
        throw AmazonCreatorsError.invalidRequest("\(parameter) deve conter apenas Browse Node IDs numéricos ASCII positivos.")
    }
}

private func containsOnlyASCIIAlphabeticCharacters(_ value: String) -> Bool {
    value.unicodeScalars.allSatisfy { scalar in
        (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }
}

private func containsOnlyASCIIDigits(_ value: String) -> Bool {
    value.unicodeScalars.allSatisfy { scalar in
        (48...57).contains(scalar.value)
    }
}
