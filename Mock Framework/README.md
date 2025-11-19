# Mock Framework

Framework de mocking para testes Apex baseado na Stub API do Salesforce. Fornece uma API fluente e intuitiva (`when/thenReturn/thenThrow/verify`) para criar mocks e verificar interações em testes unitários.

## Visão Geral

O Mock Framework simplifica a criação de mocks e stubs para interfaces Apex, permitindo isolar unidades de código durante testes. A API é inspirada em frameworks populares como Mockito, mas adaptada para as limitações e capacidades da plataforma Salesforce.

### Características Principais

- **API Fluente**: Sintaxe intuitiva `when().method().thenReturn()`
- **Matchers Flexíveis**: Suporte a matchers como `any()`, `eq()`, `isNull()`, etc.
- **Verificação de Interações**: Verifique quantas vezes um método foi chamado
- **Stubbing Avançado**: Suporte a `thenReturn`, `thenThrow`, e `thenAnswer`
- **Baseado em Stub API**: Utiliza a API nativa do Salesforce para máxima compatibilidade

## Componentes Principais

- **MockService**: Ponto de entrada para criar mocks
- **When**: Inicia o processo de stubbing
- **StubbingBuilder**: Configura o comportamento do mock
- **Verify**: Verifica interações com o mock
- **Matchers**: Utilitários para matching de argumentos

## Uso Básico

### Criar um Mock

```apex
@isTest
private class MyServiceTest {
    @isTest
    static void testWithMock() {
        // Criar um mock de uma interface
        IMyService mockService = (IMyService) MockService.createMock(IMyService.class);
        
        // Configurar comportamento
        when(mockService).method('calculate', eq(5), eq(10)).thenReturn(15);
        
        // Usar o mock
        Integer result = mockService.calculate(5, 10);
        System.assertEquals(15, result);
        
        // Verificar interação
        verify(mockService).method('calculate', eq(5), eq(10)).times(1);
    }
}
```

### Stubbing com Diferentes Comportamentos

```apex
// Retornar um valor
when(mockService).method('getName').thenReturn('Test Name');

// Lançar uma exceção
when(mockService).method('process', anyString()).thenThrow(new CustomException('Error'));

// Executar código customizado
when(mockService).method('transform', anyString()).thenAnswer(new Answer() {
    public Object answer(InvocationContext ctx) {
        String input = (String) ctx.getArgument(0);
        return input.toUpperCase();
    }
});
```

## Matchers

### Matchers Disponíveis

```apex
// Qualquer valor do tipo
anyString()
anyInteger()
anyBoolean()
anyId()
any(Type.class)  // Para tipos customizados

// Igualdade
eq(value)        // Valor exato
isNull()         // Valor null
isNotNull()      // Valor não-null

// Strings
contains(substring)
startsWith(prefix)
endsWith(suffix)
matches(pattern)  // Regex (se suportado)
```

### Exemplos de Uso de Matchers

```apex
// Aceitar qualquer string
when(mockService).method('process', anyString()).thenReturn(true);

// Aceitar qualquer ID
when(mockService).method('findById', anyId()).thenReturn(new Account());

// Aceitar valor específico
when(mockService).method('calculate', eq(10), eq(20)).thenReturn(30);

// Aceitar null
when(mockService).method('handle', isNull()).thenReturn('null-handled');

// Combinar matchers e valores literais
when(mockService).method('update', any(Account.class), eq('Active')).thenReturn(true);
```

## Verificação de Interações

### Verificar Chamadas

```apex
// Verificar que foi chamado pelo menos uma vez
verify(mockService).method('process', anyString());

// Verificar número exato de chamadas
verify(mockService).method('calculate', eq(5), eq(10)).times(2);

// Verificar que nunca foi chamado
verify(mockService).method('delete', anyId()).never();

// Verificar que foi chamado pelo menos N vezes
verify(mockService).method('update', any(Account.class)).atLeast(1);

// Verificar que foi chamado no máximo N vezes
verify(mockService).method('send', anyString()).atMost(3);
```

### Exemplo Completo de Verificação

```apex
@isTest
static void testServiceInteraction() {
    IMyService mockService = (IMyService) MockService.createMock(IMyService.class);
    MyController controller = new MyController(mockService);
    
    // Executar ação
    controller.processAccount('001xx000003DGbQAAW');
    
    // Verificar interações
    verify(mockService).method('findById', eq('001xx000003DGbQAAW')).times(1);
    verify(mockService).method('update', any(Account.class)).times(1);
    verify(mockService).method('sendEmail', anyString()).never();
}
```

## Stubbing Avançado

### Múltiplos Retornos (Sequência)

```apex
// Retornar valores diferentes em chamadas consecutivas
when(mockService).method('getNext').thenReturn(1).thenReturn(2).thenReturn(3);

Integer first = mockService.getNext();   // 1
Integer second = mockService.getNext();  // 2
Integer third = mockService.getNext();   // 3
```

### Respostas Customizadas com thenAnswer

```apex
when(mockService).method('transform', anyString()).thenAnswer(new Answer() {
    public Object answer(InvocationContext ctx) {
        String input = (String) ctx.getArgument(0);
        List<String> args = ctx.getArguments();
        
        // Lógica customizada
        if (input.startsWith('A')) {
            return input.toUpperCase();
        }
        return input.toLowerCase();
    }
});
```

### Acessar Argumentos no thenAnswer

```apex
when(mockService).method('process', anyString(), anyInteger()).thenAnswer(new Answer() {
    public Object answer(InvocationContext ctx) {
        String name = (String) ctx.getArgument(0);
        Integer count = (Integer) ctx.getArgument(1);
        
        // Usar os argumentos para lógica customizada
        return name + '-' + count;
    }
});
```

## Padrões de Uso

### Teste de Serviço com Dependências

```apex
@isTest
private class AccountServiceTest {
    @isTest
    static void testCreateAccountWithValidation() {
        // Criar mocks das dependências
        IValidator mockValidator = (IValidator) MockService.createMock(IValidator.class);
        IRepository mockRepo = (IRepository) MockService.createMock(IRepository.class);
        
        // Configurar comportamento
        when(mockValidator).method('validate', any(Account.class)).thenReturn(true);
        when(mockRepo).method('save', any(Account.class)).thenReturn(new Account(Id = '001xx000003DGbQAAW'));
        
        // Criar serviço com mocks injetados
        AccountService service = new AccountService(mockValidator, mockRepo);
        
        // Executar
        Account acc = new Account(Name = 'Test');
        Account result = service.createAccount(acc);
        
        // Verificar
        System.assertNotEquals(null, result.Id);
        verify(mockValidator).method('validate', any(Account.class)).times(1);
        verify(mockRepo).method('save', any(Account.class)).times(1);
    }
}
```

### Teste de Exceções

```apex
@isTest
static void testHandlesException() {
    IMyService mockService = (IMyService) MockService.createMock(IMyService.class);
    
    // Configurar para lançar exceção
    when(mockService).method('process', anyString())
        .thenThrow(new CustomException('Processing failed'));
    
    // Testar tratamento de exceção
    try {
        mockService.process('test');
        System.assert(false, 'Should have thrown exception');
    } catch (CustomException e) {
        System.assertEquals('Processing failed', e.getMessage());
    }
}
```

## API Reference

### MockService

#### `createMock(Type typeToMock)`
Cria um mock para a interface especificada.

```apex
Object mock = MockService.createMock(IMyService.class);
```

### When

#### `when(Object mock)`
Inicia o processo de stubbing para um mock.

```apex
When when = when(mock);
```

#### `method(String methodName)`
Stub para método sem argumentos.

#### `method(String methodName, Object... args)`
Stub para método com argumentos (suporta até 4 argumentos ou uma lista).

### StubbingBuilder

#### `thenReturn(Object value)`
Configura o mock para retornar um valor específico.

#### `thenThrow(Exception exception)`
Configura o mock para lançar uma exceção.

#### `thenAnswer(Answer answer)`
Configura o mock para executar código customizado.

### Verify

#### `verify(Object mock)`
Inicia a verificação de interações.

#### `times(Integer count)`
Verifica que o método foi chamado exatamente N vezes.

#### `never()`
Verifica que o método nunca foi chamado.

#### `atLeast(Integer count)`
Verifica que o método foi chamado pelo menos N vezes.

#### `atMost(Integer count)`
Verifica que o método foi chamado no máximo N vezes.

## Limitações

1. **Limite de Stubs**: A Stub API do Salesforce permite no máximo 10 stubs por método de teste
2. **Apenas Interfaces**: Só é possível criar mocks de interfaces, não de classes concretas
3. **Métodos Estáticos**: Não é possível fazer mock de métodos estáticos
4. **Tipos Primitivos**: Alguns matchers podem ter limitações com tipos primitivos

## Boas Práticas

1. **Use Interfaces**: Projete suas classes para depender de interfaces, facilitando o mocking
2. **Um Mock por Teste**: Tente limitar o número de mocks por teste para manter os testes simples
3. **Verifique o Essencial**: Verifique apenas as interações críticas, não todas as chamadas
4. **Stub o Mínimo Necessário**: Configure apenas o comportamento necessário para o teste
5. **Nomes Descritivos**: Use nomes claros para mocks e variáveis de teste

## Exemplos Adicionais

Veja a classe `MockFrameworkTest.cls` para exemplos completos de uso do framework.

## Compatibilidade

- **API Version**: 60.0+
- **Stub API**: Requer Salesforce Stub API (disponível desde API 40.0)
- **Namespaces**: Funciona em orgs com e sem namespace
- **Test Context**: Apenas disponível em métodos `@isTest`

