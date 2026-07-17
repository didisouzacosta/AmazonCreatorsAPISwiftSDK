# ``AmazonCreatorsAPI``

Um cliente Swift concorrente para operações de catálogo da Amazon Creators API.

## Overview

`AmazonCreatorsAPI` suporta iOS 18 ou posterior e centraliza todas as regras de rede necessárias para consultar produtos, variações e categorias. O pacote recebe somente um access token temporário: credenciais de longa duração e segredos permanecem fora do aplicativo iOS.

Crie um ``AmazonCreatorsClient`` com marketplace, partner tag e versão da credencial. Em seguida, use ``AmazonCreatorsClient/getItems(_:)``, ``AmazonCreatorsClient/searchItems(_:)``, ``AmazonCreatorsClient/getVariations(_:)`` ou ``AmazonCreatorsClient/getBrowseNodes(_:)``.

Para renovar tokens, forneça um ``AccessTokenProvider`` e, quando o backend diferenciar uma renovação forçada da leitura em cache, um ``AccessTokenRefreshProvider``. O SDK chama o provider de renovação após um HTTP 401 e repete a operação uma única vez.

```swift
let client = AmazonCreatorsClient(
    accessToken: accessToken,
    credentialVersion: .v3NorthAmerica,
    partnerTag: "seu-tag-20",
    marketplace: .brazil
)

let response = try await client.searchItems(
    SearchItemsRequest(keywords: "café")
)
```

Os links em ``Product/affiliateURL`` são emitidos pela Amazon e devem ser apresentados sem alterar parâmetros.

## Topics

### Cliente

- ``AmazonCreatorsClient``
- ``AmazonCreatorsConfiguration``
- ``CredentialVersion``
- ``Marketplace``
- ``PartnerTag``
- ``AccessTokenProvider``
- ``AccessTokenRefreshProvider``

### Operações de catálogo

- ``GetItemsRequest``
- ``SearchItemsRequest``
- ``SearchItemsOptions``
- ``GetVariationsRequest``
- ``GetBrowseNodesRequest``

### Respostas e recursos

- ``Product``
- ``CatalogResource``
- ``GetItemsResponse``
- ``SearchItemsResponse``
- ``GetVariationsResponse``
- ``GetBrowseNodesResponse``

### Tratamento de falhas

- ``AmazonCreatorsError``
- ``APIProblem``
