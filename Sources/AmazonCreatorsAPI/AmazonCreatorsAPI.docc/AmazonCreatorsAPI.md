# ``AmazonCreatorsAPI``

Um cliente Swift concorrente para operações de catálogo da Amazon Creators API.

## Overview

`AmazonCreatorsAPI` suporta iOS 18 ou posterior e centraliza todas as regras de rede necessárias para consultar produtos, variações e categorias. O pacote pode gerar e renovar o access token OAuth2 diretamente a partir das credenciais da Creators API.

Crie um ``AmazonCreatorsClient`` com ``AmazonCreatorsCredentials``, marketplace e partner tag. Em seguida, use ``AmazonCreatorsClient/getItems(_:)``, ``AmazonCreatorsClient/searchItems(_:)``, ``AmazonCreatorsClient/getVariations(_:)`` ou ``AmazonCreatorsClient/getBrowseNodes(_:)``.

### Obter as credenciais

1. Entre na [console da Amazon Creators API](https://affiliate-program.amazon.com/creatorsapi) com a conta Amazon Associates que será dona da integração.
2. Em **Applications**, escolha **Create App**.
3. No aplicativo criado, escolha **Add New Credential**.
4. Copie o **Credential ID**, o **Credential Secret** e a **Version** gerados. Use a `Version` recebida exatamente como emitida pela Amazon.

Você também precisa de um ``PartnerTag`` válido para o marketplace das chamadas. A Amazon relaciona o acesso à API ao cadastro no programa Associates, ao registro para a API e à elegibilidade da conta.

Para usar uma fonte de token personalizada, forneça um ``AccessTokenProvider`` e, quando essa fonte diferenciar uma renovação forçada da leitura em cache, um ``AccessTokenRefreshProvider``. O SDK chama o provider de renovação após um HTTP 401 e repete a operação uma única vez.

``AmazonCreatorsOAuth2TokenProvider`` adapta o fluxo OAuth2 do SDK PHP: reutiliza o token em memória até 30 segundos antes do vencimento, gera um token novo com `client_credentials` quando necessário e força uma nova emissão após um HTTP 401. O cliente criado com credenciais o configura automaticamente. Como todo Secret incluído em aplicativo distribuído pode ser extraído, proteja a distribuição e a rotação das credenciais conforme o risco da integração.

```swift
let credentials = AmazonCreatorsCredentials(
    "seu-credential-id",
    credentialSecret: "seu-credential-secret",
    credentialVersion: .v3NorthAmerica
)
let client = AmazonCreatorsClient(
    credentials,
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
- ``AmazonCreatorsCredentials``
- ``AmazonCreatorsOAuth2TokenProvider``
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
