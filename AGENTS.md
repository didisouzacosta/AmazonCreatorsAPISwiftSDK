# Regras de Engenharia do CreatorsAPI

Estas instruções se aplicam a todo o repositório.

## Regras específicas do projeto

- Quando existir, leia `PROJECT_RULES.md` antes de alterar o projeto. Esse arquivo contém regras de domínio, integrações e decisões específicas do CreatorsAPI.
- `PROJECT_RULES.md` pode complementar estas regras ou declarar exceções explícitas. Na ausência de uma exceção explícita, estas regras globais prevalecem.
- Não adicione regras de negócio específicas do CreatorsAPI a este arquivo.

## Interface e plataforma

- Toda interface do projeto deve ser criada com SwiftUI.
- Não importe UIKit. Uma exceção só é permitida diante de uma necessidade técnica extrema sem solução equivalente em SwiftUI, deve ter justificativa explícita e ficar isolada no menor wrapper possível.
- Prefira APIs nativas e modernas de SwiftUI; não introduza componentes UIKit apenas por familiaridade ou conveniência.

## Fluxo obrigatório

- Classifique cada tarefa Swift antes de editar e use a orientação ou skill aplicável.
- Use `swiftui-expert-skill` para implementação e revisão de SwiftUI.
- Use `build-ios-apps:swiftui-ui-patterns` para navegação e composição de componentes SwiftUI.
- Use `build-ios-apps:swiftui-view-refactor` para refatorações estruturais de Views; as regras de MVVM deste arquivo prevalecem sobre preferências conflitantes da skill.
- Inicie investigações de desempenho SwiftUI com `build-ios-apps:swiftui-performance-audit`.
- Use `build-ios-apps:ios-app-intents` apenas para Siri, Atalhos, Spotlight, widgets, controles ou outras superfícies do sistema.
- Use `build-ios-apps:swiftui-liquid-glass` somente quando Liquid Glass for solicitado explicitamente.

## Swift 6 e concorrência

- Todo código novo deve ser pensado para Swift 6 ou superior e deve adotar APIs modernas e seguras da linguagem.
- Use concorrência estruturada com `async`/`await`, `Task`, grupos de tarefas e cancelamento cooperativo. Não introduza GCD, callbacks ou concorrência não estruturada quando houver uma alternativa moderna equivalente.
- Declare e respeite isolamento de ator, `Sendable` e segurança de dados. Estado e atualizações de UI devem permanecer no `MainActor`; trabalho independente deve ficar fora dele.
- Prefira `@Observable` a `ObservableObject` em código novo e use `@MainActor` em tipos observáveis quando o isolamento padrão do projeto não o garantir.
- Não use `@unchecked Sendable`, `nonisolated(unsafe)` ou supressões de verificações de concorrência sem uma necessidade comprovada, documentação da justificativa e isolamento do risco.
- Em caso de dúvida sobre Swift, SwiftUI, concorrência, disponibilidade de API ou comportamento de plataforma, consulte primeiro a documentação oficial da Apple antes de implementar.

## Testes e Simulator

- Nunca crie ou execute testes de interface. Isso inclui XCUITest, `XCUIApplication`, consultas de elementos, testes de snapshot, asserções de Views renderizadas, inspeção de hierarquia de UI e capturas automatizadas de tela.
- O iOS Simulator pode ser iniciado, controlado, inspecionado ou perfilado para executar testes unitários, depurar o app ou validar comportamento não visual.
- Testes unitários podem usar `xcodebuild` e um iOS Simulator, mas não podem interagir com UI, consultar hierarquia de interface, validar renderização ou executar qualquer comportamento de teste de interface.
- Builds e ferramentas de depuração não visuais são permitidos. Quando necessário, mantenha DerivedData e caches de pacotes em um diretório temporário gravável.
- Sempre crie os testes antes de alterar código de produção. Para toda mudança comportamental, use TDD: escreva primeiro um teste unitário que falha, implemente a menor alteração de produção, faça o teste passar e então refatore.
- A suíte de testes deve usar exclusivamente Swift Testing (`import Testing`), com `@Suite` para agrupamento e `@Test` para os casos de teste. Não crie novos testes em XCTest.
- Não invente testes para alterações apenas de documentação, organização ou visuais. Valide-as por revisão estática e build sem inicialização do app.

## Arquitetura e camadas

- MVVM é obrigatório para telas e componentes com comportamento.
- A camada de apresentação contém Views e ViewModels. Views apenas renderizam estado pronto e encaminham ações; ViewModels mantêm estado de apresentação, transformam dados para a UI e coordenam casos de uso.
- Uma View não pode conter regra de negócio nem acessar diretamente serviços, gerenciadores, persistência, repositórios ou abstrações de banco de dados.
- Uma View não pode criar um ViewModel ou qualquer dependência dele.
- Toda tela ou componente que possui estado, executa uma ação, trata gesto, inicia trabalho assíncrono ou toma uma decisão deve ter ViewModel dedicado. Uma View folha puramente visual pode receber valores prontos para exibição e callbacks.
- A camada de domínio contém entidades, regras de negócio, casos de uso e contratos. Ela não depende de SwiftUI, UIKit, rede, persistência ou implementações de infraestrutura.
- A camada de infraestrutura implementa serviços, repositórios e persistência. Essas dependências devem ser injetadas por abstrações; não use singletons globais nem oculte dependências em inicializadores de conveniência.
- Dependências fluem da apresentação para os contratos do domínio e da infraestrutura para os contratos que ela implementa. Regras de negócio nunca dependem de detalhes de UI ou infraestrutura.
- Navegação entre features e montagem do grafo da aplicação pertencem a um `AppRouter`. A criação de dependências de longa duração pertence a um `AppContainer`.
- Views e ViewModels navegam apenas pela abstração `AppRouting`; nunca instanciam Views ou ViewModels de destino.
- `AppRootView` é a única View que pode observar `AppRouter` diretamente e deve apenas renderizar o estado de rota fornecido por ele.

## Bibliotecas externas

- Nunca use uma biblioteca de terceiros diretamente fora de sua integração. Crie um wrapper próprio, organizado na camada adequada, e faça o restante do projeto depender somente da abstração local.
- Apenas o wrapper pode importar a biblioteca. Não exponha tipos, erros, callbacks ou detalhes de implementação da dependência para Views, ViewModels, domínio ou APIs internas do projeto.
- O wrapper deve ser injetado por contrato, concentrar configuração e adaptação de dados/erros e tornar a substituição ou remoção da biblioteca possível sem alterar os consumidores.

## Regras para Views

- `body` pode ler apenas valores já preparados pelo ViewModel e chamar ações do ViewModel.
- Não use ternários, comparações, fallbacks opcionais, formatação, filtragem, `Binding(get:set:)` ou decisões de negócio inline na declaração de um componente.
- Prefira uma propriedade pronta para UI no ViewModel. Quando a adaptação for exclusivamente visual, use uma propriedade computada privada e descritiva na View, como `private var captureOpacity: Double`.
- Todas as propriedades armazenadas e computadas de uma View são `private`, exceto quando uma API externa exigir visibilidade maior.
- Mantenha `body` puro, pequeno, estável e sem efeitos colaterais.
- Resolva o layout com a composição mais simples e limpa de SwiftUI antes de recorrer a `GeometryReader`. Prefira layouts relativos e APIs como `containerRelativeFrame`, `ViewThatFits`, `Layout`, `visualEffect` e modificadores nativos quando aplicáveis.
- Use `GeometryReader` apenas quando nenhuma alternativa nativa atender à necessidade. Mantenha-o no menor escopo possível e não o use para inferir tamanho de tela ou como solução padrão de layout.
- Toda View deve declarar `#Preview` para cada estado visual relevante, incluindo carregamento, conteúdo, vazio, erro, estados desabilitados e variações de dados quando existirem. Os previews devem usar valores e dependências de demonstração, sem rede, persistência ou efeitos colaterais.

## Organização de código Swift

- Use exatamente `// MARK: -` e a ordem de seções definida neste arquivo. Omita seções vazias, mas nunca renomeie ou reordene seções aplicáveis.
- Views usam, quando aplicável: `Environments`, `Bindables`, `Bindings`, `App Storage`, `Scene Storage`, `Focus State`, `Gesture State`, `Namespaces`, `States`, `Public Properties`, `Body`, `Private Properties`, `Initializer`, `Public Methods`, `Private Methods`.
- Tipos que não são Views usam, quando aplicável: `Public Properties`, `Private Properties`, `Initializer`, `Public Methods`, `Private Methods`.
- Todo inicializador explícito deve ter o primeiro parâmetro sem label.
- Callbacks e detalhes de implementação devem ser `private` por padrão. Exponha somente APIs reais.
- Use exatamente uma linha em branco antes e depois de cada declaração `// MARK: -`, inclusive quando for o primeiro ou último item do escopo.
- Use exatamente uma linha em branco antes de cada `return`, inclusive quando ele for a primeira instrução do escopo.
- Use exatamente uma linha em branco antes e depois de `guard`, `if`, `switch`, loops, `do`, `catch` e `defer` apenas quando houver outra linha de código não vazia antes ou depois no mesmo escopo. As linhas em branco de blocos de controle ficam fora do bloco.
- Mantenha propriedades armazenadas consecutivas `let` e `var` em um único grupo contínuo na mesma seção de visibilidade ou property wrapper. Separe o grupo do restante por exatamente uma linha em branco, sem reordenar propriedades nem movê-las entre seções quando isso puder afetar o comportamento.
- Exceto pelos espaços obrigatórios ao redor de `// MARK: -` e antes de `return`, não adicione linha em branco imediatamente após uma chave de abertura ou antes de uma chave de fechamento. Quando uma declaração contextual for o primeiro ou último item do escopo, omita a linha em branco correspondente. A primeira e a última linha de funções, propriedades, closures, inicializadores, classes, structs, enums, protocolos, extensions e blocos de controle devem conter código funcional ou uma declaração.
- Escreva escopos vazios como `{}`.
