/**
 * @description       : Exemplos de implementação inline do SelectorCache
 * @author            : 
 * @group             : 
 * @last modified on  : 
 * @last modified by  : 
 * 
 * EXEMPLOS DE USO DO SELECTORCACHE:
 * 
 * Este arquivo demonstra como implementar cache inline nos selectores.
 * Use estes exemplos como referência ao implementar cache nos seus selectores.
**/
public with sharing class SelectorCacheExample {
    
    /**
     * EXEMPLO 1: Método simples com um parâmetro Set<Id>
     * 
     * Padrão de implementação:
     * 1. Validar parâmetros
     * 2. Gerar chave do cache
     * 3. Verificar se existe no cache
     * 4. Se existir, retornar do cache
     * 5. Se não existir, executar query e armazenar no cache
     */
    public List<Quote> selectByOpportunityIds_EXEMPLO(Set<Id> opportunityIds) {
        // 1. Validação padrão
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return new List<Quote>();
        }

        // 2. Gerar chave do cache
        String cacheKey = SelectorCache.generateCacheKey('QuotesSelector', 'selectByOpportunityIds', opportunityIds);
        
        // 3. Verificar se existe no cache
        if (SelectorCache.containsKey(cacheKey)) {
            return (List<Quote>) SelectorCache.get(cacheKey);
        }

        // 4. Executar query
        List<Quote> results = [
            SELECT Id, OpportunityId 
            FROM Quote 
            WHERE OpportunityId IN :opportunityIds
        ];
        
        // 5. Armazenar no cache e retornar
        SelectorCache.put(cacheKey, results);
        return results;
    }
    
    /**
     * EXEMPLO 2: Método com múltiplos parâmetros
     * 
     * Para métodos com múltiplos parâmetros, crie um Map com os parâmetros
     */
    public List<Quote> selectByOpportunityIdsAndRecordType_EXEMPLO(Set<Id> opportunityIds, Id recordTypeId, Set<Id> excludeIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return new List<Quote>();
        }

        // Criar um Map com todos os parâmetros para a chave do cache
        Map<String, Object> params = new Map<String, Object>{
            'opportunityIds' => opportunityIds,
            'recordTypeId' => recordTypeId,
            'excludeIds' => excludeIds
        };
        
        String cacheKey = SelectorCache.generateCacheKey('QuotesSelector', 'selectByOpportunityIdsAndRecordType', params);
        
        if (SelectorCache.containsKey(cacheKey)) {
            return (List<Quote>) SelectorCache.get(cacheKey);
        }

        List<Quote> results;
        if (excludeIds != null && !excludeIds.isEmpty()) {
            results = [
                SELECT Id 
                FROM Quote 
                WHERE OpportunityId IN :opportunityIds 
                AND Opportunity.RecordTypeId = :recordTypeId 
                AND Id NOT IN :excludeIds
            ];
        } else {
            results = [
                SELECT Id 
                FROM Quote 
                WHERE OpportunityId IN :opportunityIds 
                AND Opportunity.RecordTypeId = :recordTypeId
            ];
        }
        
        SelectorCache.put(cacheKey, results);
        return results;
    }
    
    /**
     * EXEMPLO 2B: Alternativa mais simples para múltiplos parâmetros
     * 
     * Você também pode passar apenas o parâmetro principal e incluir os outros na chave manualmente
     */
    public List<Opportunity> selectByIdsWithQuotes_EXEMPLO_ALTERNATIVO(Set<Id> opportunityIds, Set<Id> excludeQuoteIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return new List<Opportunity>();
        }

        // Usar o parâmetro principal e incluir excludeQuoteIds na chave
        Map<String, Object> params = new Map<String, Object>{
            'opportunityIds' => opportunityIds,
            'excludeQuoteIds' => excludeQuoteIds
        };
        
        String cacheKey = SelectorCache.generateCacheKey('OpportunitiesSelector', 'selectByIdsWithQuotes', params);
        
        if (SelectorCache.containsKey(cacheKey)) {
            return (List<Opportunity>) SelectorCache.get(cacheKey);
        }

        List<Opportunity> results;
        if (excludeQuoteIds != null && !excludeQuoteIds.isEmpty()) {
            results = [
                SELECT Id, StageName, RecordTypeId,
                    (SELECT Id, OpportunityId 
                     FROM Quotes 
                     WHERE Id NOT IN :excludeQuoteIds)
                FROM Opportunity 
                WHERE Id IN :opportunityIds
            ];
        } else {
            results = [
                SELECT Id, StageName, RecordTypeId,
                    (SELECT Id, OpportunityId 
                     FROM Quotes)
                FROM Opportunity 
                WHERE Id IN :opportunityIds
            ];
        }
        
        SelectorCache.put(cacheKey, results);
        return results;
    }
    
    /**
     * EXEMPLO 3: Método com parâmetro Set<String>
     * 
     * O SelectorCache já trata Set<String> automaticamente
     */
    public List<Pricebook2> selectByNames_EXEMPLO(Set<String> names) {
        if (names == null || names.isEmpty()) {
            return new List<Pricebook2>();
        }

        String cacheKey = SelectorCache.generateCacheKey('Pricebook2Selector', 'selectByNames', names);
        
        if (SelectorCache.containsKey(cacheKey)) {
            return (List<Pricebook2>) SelectorCache.get(cacheKey);
        }

        List<Pricebook2> results = [
            SELECT Id, Name, Description, IsActive, IsStandard
            FROM Pricebook2
            WHERE Name IN :names
        ];
        
        SelectorCache.put(cacheKey, results);
        return results;
    }
    
    /**
     * EXEMPLO 4: Limpar cache quando necessário
     * 
     * Use quando souber que os dados mudaram e o cache precisa ser invalidado
     */
    public void exemploLimparCache() {
        // Opção 1: Limpar uma entrada específica do cache
        Set<Id> quoteIds = new Set<Id>{'001xx000003DGbQAAW'};
        SelectorCache.removeCacheEntry('QuotesSelector', 'selectByOpportunityIds', quoteIds);
        
        // Opção 2: Limpar cache de um método específico
        SelectorCache.clearMethodCache('QuotesSelector', 'selectByOpportunityIds');
        
        // Opção 3: Limpar cache de um seletor inteiro
        SelectorCache.clearSelectorCache('QuotesSelector');
        
        // Opção 4: Limpar todo o cache
        SelectorCache.clear();
    }
    
    /**
     * EXEMPLO 5: Forçar nova query ignorando o cache
     * 
     * Quando você precisa de dados atualizados, limpe o cache antes de chamar o método
     */
    public List<Quote> exemploForcarNovaQuery(Set<Id> opportunityIds) {
        // Limpar o cache antes de chamar o método
        SelectorCache.removeCacheEntry('QuotesSelector', 'selectByOpportunityIds', opportunityIds);
        
        // Agora quando o método for chamado, fará a query novamente
        QuotesSelector selector = new QuotesSelector();
        return selector.selectByOpportunityIds(opportunityIds);
    }
    
    /**
     * EXEMPLO 6: Implementação com parâmetro opcional para bypass do cache
     * 
     * Você pode adicionar um parâmetro opcional para ignorar o cache quando necessário
     */
    public List<Quote> selectByOpportunityIds_COM_BYPASS(Set<Id> opportunityIds, Boolean bypassCache) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return new List<Quote>();
        }

        String cacheKey = SelectorCache.generateCacheKey('QuotesSelector', 'selectByOpportunityIds', opportunityIds);
        
        // Se bypassCache for true, remove do cache antes de verificar
        if (bypassCache != null && bypassCache) {
            SelectorCache.remove(cacheKey);
        }
        
        if (SelectorCache.containsKey(cacheKey)) {
            return (List<Quote>) SelectorCache.get(cacheKey);
        }

        List<Quote> results = [
            SELECT Id, OpportunityId 
            FROM Quote 
            WHERE OpportunityId IN :opportunityIds
        ];
        
        SelectorCache.put(cacheKey, results);
        return results;
    }
}

