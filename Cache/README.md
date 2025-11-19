# Cache Module

Sistema de cache em memória para otimizar consultas de selectors, reduzindo chamadas ao banco de dados e melhorando o desempenho das transações.

## Visão Geral

O módulo `Cache` fornece uma solução leve e eficiente para cachear resultados de selectors durante uma transação. O cache é automaticamente limpo entre transações, garantindo que os dados não fiquem desatualizados.

### Características Principais

- **Cache por Transação**: Cada transação possui seu próprio cache isolado
- **Chaves Automáticas**: Geração automática de chaves baseadas em selector, método e parâmetros
- **Suporte a Superset**: Busca inteligente por caches que contêm supersets dos IDs solicitados
- **Filtragem Avançada**: Métodos para filtrar resultados por IDs ou múltiplos campos
- **Limpeza Seletiva**: Limpeza granular do cache (por entrada, método ou selector completo)

## Componentes

### SelectorCache

Classe principal que gerencia o cache de resultados de selectors.

## Uso Básico

### Exemplo 1: Método Simples com Set<Id>

```apex
public List<Quote> selectByOpportunityIds(Set<Id> opportunityIds) {
    if (opportunityIds == null || opportunityIds.isEmpty()) {
        return new List<Quote>();
    }

    // Gerar chave do cache
    String cacheKey = SelectorCache.generateCacheKey('QuotesSelector', 'selectByOpportunityIds', opportunityIds);
    
    // Verificar se existe no cache
    if (SelectorCache.containsKey(cacheKey)) {
        return (List<Quote>) SelectorCache.get(cacheKey);
    }

    // Executar query
    List<Quote> results = [
        SELECT Id, OpportunityId 
        FROM Quote 
        WHERE OpportunityId IN :opportunityIds
    ];
    
    // Armazenar no cache e retornar
    SelectorCache.put(cacheKey, results);
    return results;
}
```

### Exemplo 2: Método com Múltiplos Parâmetros

```apex
public List<Quote> selectByOpportunityIdsAndRecordType(Set<Id> opportunityIds, Id recordTypeId, Set<Id> excludeIds) {
    if (opportunityIds == null || opportunityIds.isEmpty()) {
        return new List<Quote>();
    }

    // Criar um Map com todos os parâmetros
    Map<String, Object> params = new Map<String, Object>{
        'opportunityIds' => opportunityIds,
        'recordTypeId' => recordTypeId,
        'excludeIds' => excludeIds
    };
    
    String cacheKey = SelectorCache.generateCacheKey('QuotesSelector', 'selectByOpportunityIdsAndRecordType', params);
    
    if (SelectorCache.containsKey(cacheKey)) {
        return (List<Quote>) SelectorCache.get(cacheKey);
    }

    // Executar query...
    List<Quote> results = [/* sua query aqui */];
    
    SelectorCache.put(cacheKey, results);
    return results;
}
```

### Exemplo 3: Geração Automática de Chave

```apex
public List<Account> selectByIds(Set<Id> accountIds) {
    // Usando 'this' para detectar automaticamente o nome da classe
    String cacheKey = SelectorCache.generateCacheKey(this, 'selectByIds', accountIds);
    
    if (SelectorCache.containsKey(cacheKey)) {
        return (List<Account>) SelectorCache.get(cacheKey);
    }

    List<Account> results = [SELECT Id, Name FROM Account WHERE Id IN :accountIds];
    SelectorCache.put(cacheKey, results);
    return results;
}
```

## Funcionalidades Avançadas

### Busca por Superset

Quando você solicita um conjunto de IDs, o cache pode verificar se já existe um cache que contém todos esses IDs (e possivelmente mais):

```apex
// Verificar se existe um cache que contém todos os IDs solicitados
String supersetKey = SelectorCache.findSupersetCacheKey('QuotesSelector', 'selectByOpportunityIds', requestedIds);

if (supersetKey != null) {
    List<Quote> cachedResults = (List<Quote>) SelectorCache.get(supersetKey);
    // Filtrar para retornar apenas os IDs solicitados
    return SelectorCache.filterResultsByIds(cachedResults, requestedIds, 'OpportunityId');
}
```

### Filtragem por Múltiplos Campos

Para queries complexas com condições OR:

```apex
List<String> idFieldNames = new List<String>{
    'Proposal__c',
    'ProposalLineItem__r.QuoteId'
};

List<SObject> filtered = SelectorCache.filterResultsByMultipleIdFields(
    cachedResults, 
    requestedIds, 
    idFieldNames
);
```

## Gerenciamento do Cache

### Limpar Entrada Específica

```apex
Set<Id> quoteIds = new Set<Id>{'001xx000003DGbQAAW'};
SelectorCache.removeCacheEntry('QuotesSelector', 'selectByOpportunityIds', quoteIds);
```

### Limpar Cache de um Método

```apex
SelectorCache.clearMethodCache('QuotesSelector', 'selectByOpportunityIds');
```

### Limpar Cache de um Selector Completo

```apex
SelectorCache.clearSelectorCache('QuotesSelector');
```

### Limpar Todo o Cache

```apex
SelectorCache.clear();
```

### Resetar Transação

```apex
// Útil em testes para garantir isolamento
SelectorCache.resetTransaction();
```

## API Reference

### Métodos Estáticos Principais

#### `generateCacheKey(String selectorName, String methodName, Object params)`
Gera uma chave única de cache baseada no selector, método e parâmetros.

#### `generateCacheKey(Object selectorInstance, String methodName, Object params)`
Gera chave automaticamente detectando o nome da classe do selector.

#### `generateCacheKey(Object selectorInstance, Object params)`
Gera chave detectando automaticamente classe e método (via stack trace).

#### `get(String cacheKey)`
Retorna o valor armazenado no cache ou `null` se não existir.

#### `put(String cacheKey, Object value)`
Armazena um valor no cache.

#### `containsKey(String cacheKey)`
Verifica se uma chave existe no cache.

#### `findSupersetCacheKey(String selectorName, String methodName, Set<Id> requestedIds)`
Busca um cache que contenha um superset dos IDs solicitados.

#### `filterResultsByIds(List<SObject> results, Set<Id> requestedIds, String idFieldName)`
Filtra resultados para incluir apenas os objetos com IDs correspondentes.

#### `filterResultsByMultipleIdFields(List<SObject> results, Set<Id> requestedIds, List<String> idFieldNames)`
Filtra resultados verificando múltiplos campos (suporta relacionamentos).

#### `remove(String cacheKey)`
Remove uma entrada específica do cache.

#### `clear()`
Limpa todo o cache e reseta a transação.

#### `clearSelectorCache(String selectorName)`
Limpa todo o cache de um selector específico.

#### `clearMethodCache(String selectorName, String methodName)`
Limpa o cache de um método específico de um selector.

#### `removeCacheEntry(String selectorName, String methodName, Object params)`
Remove uma entrada específica do cache baseada em selector, método e parâmetros.

## Tipos de Parâmetros Suportados

O `SelectorCache` suporta os seguintes tipos de parâmetros:

- `Set<Id>` - Ordenado automaticamente para garantir consistência
- `Set<String>` - Ordenado automaticamente
- `Map<String, Object>` - Chaves ordenadas alfabeticamente
- `List<Object>` - Serializado como JSON
- Tipos primitivos - Convertidos para String

## Boas Práticas

1. **Sempre valide parâmetros** antes de gerar a chave do cache
2. **Use cache para queries frequentes** que são chamadas múltiplas vezes na mesma transação
3. **Limpe o cache quando necessário** após operações DML que afetam os dados
4. **Use superset quando apropriado** para reduzir queries redundantes
5. **Evite cachear queries muito grandes** que podem consumir muita memória

## Limitações

- O cache é **por transação** e é limpo automaticamente entre transações
- O cache é armazenado em memória estática, então não persiste entre diferentes contextos de execução
- Para queries muito grandes, considere paginação em vez de cachear tudo

## Exemplos Completos

Veja a classe `SelectorCacheExample.cls` para exemplos detalhados de implementação.

## Compatibilidade

- **API Version**: 60.0+
- **Namespaces**: Funciona em orgs com e sem namespace
- **Governor Limits**: Não consome limites adicionais além do uso de memória

