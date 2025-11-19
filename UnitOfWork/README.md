# UnitOfWork Module

Implementação standalone do padrão Unit of Work para gerenciar operações DML em batch, resolução de relacionamentos, publicação de Platform Events e execução de trabalho genérico dentro de uma transação.

## Visão Geral

O módulo `UnitOfWork` fornece uma abstração poderosa para gerenciar múltiplas operações DML de forma eficiente e organizada. É inspirado no padrão fflib, mas implementado como uma solução standalone sem dependências externas.

### Características Principais

- **DML em Batch**: Agrupa operações DML por tipo de objeto para eficiência
- **Resolução de Relacionamentos**: Resolve automaticamente relacionamentos entre objetos, incluindo External IDs
- **Platform Events**: Suporte para publicação de eventos em diferentes fases (antes, após sucesso, após falha)
- **Estratégias DML Pluggáveis**: Suporte para System Mode e User Mode
- **Trabalho Genérico**: Interface para executar trabalho customizado após DML
- **Envio de Emails**: Gerenciamento automático de fila de emails

## Componentes

- **UnitOfWork**: Classe principal que implementa o padrão
- **IUnitOfWork**: Interface pública para abstração
- **Application**: Factory para criar instâncias configuradas

## Uso Básico

### Configuração Inicial

Primeiro, configure os tipos de objetos que serão gerenciados (em ordem de dependência):

```apex
// Em Application.cls
public static final Application.UnitOfWorkFactory unitOfWork =
    new Application.UnitOfWorkFactory(new List<Schema.SObjectType>{
        QuoteLineItem.SObjectType,  // Menos dependente primeiro
        Quote.SObjectType            // Mais dependente depois
    });
```

### Uso Simples

```apex
// Obter instância do UnitOfWork
IUnitOfWork uow = Application.unitOfWork.newInstance();

// Registrar operações
Account acc = new Account(Name = 'Acme Corp');
uow.registerNew(acc);

Contact con = new Contact(LastName = 'Doe');
uow.registerNew(con, Contact.AccountId, acc);  // Relacionamento automático

// Executar tudo em uma transação
uow.commitWork();
```

## Operações DML

### Registrar Novos Registros

```apex
// Registro simples
Account acc = new Account(Name = 'Test');
uow.registerNew(acc);

// Registro em lote
List<Account> accounts = new List<Account>{
    new Account(Name = 'Account 1'),
    new Account(Name = 'Account 2')
};
uow.registerNew(accounts);

// Com relacionamento
Contact con = new Contact(LastName = 'Doe');
uow.registerNew(con, Contact.AccountId, acc);
```

### Registrar Atualizações

```apex
// Atualização simples
Account acc = [SELECT Id, Name FROM Account LIMIT 1];
acc.Name = 'Updated Name';
uow.registerDirty(acc);

// Atualização em lote
List<Account> accounts = [SELECT Id FROM Account LIMIT 10];
for (Account a : accounts) {
    a.Name = 'Updated';
}
uow.registerDirty(accounts);

// Atualização com campos específicos
Account acc = [SELECT Id, Name, BillingCity FROM Account LIMIT 1];
acc.BillingCity = 'New York';
uow.registerDirty(acc, new List<Schema.SObjectField>{Account.BillingCity});

// Com relacionamento
uow.registerDirty(con, Contact.AccountId, acc);
```

### Registrar Exclusões

```apex
// Exclusão simples
Account acc = [SELECT Id FROM Account LIMIT 1];
uow.registerDeleted(acc);

// Exclusão em lote
List<Account> accounts = [SELECT Id FROM Account LIMIT 10];
uow.registerDeleted(accounts);

// Exclusão permanente (esvazia lixeira)
uow.registerPermanentlyDeleted(acc);
```

### Upsert

```apex
// Upsert automático (insert se Id null, update se Id existe)
SObject record = /* seu objeto */;
uow.registerUpsert(record);

List<SObject> records = /* sua lista */;
uow.registerUpsert(records);
```

## Relacionamentos

### Relacionamento por SObject

```apex
Account acc = new Account(Name = 'Parent');
Contact con = new Contact(LastName = 'Child');

// Relacionar após registro
uow.registerNew(acc);
uow.registerNew(con);
uow.registerRelationship(con, Contact.AccountId, acc);
```

### Relacionamento por External ID

```apex
// Quando você tem um External ID em vez do Id
Contact con = new Contact(LastName = 'Doe');
uow.registerNew(con);

// Relacionar usando External ID
uow.registerRelationship(
    con, 
    Contact.AccountId,           // Campo de relacionamento
    Account.ExternalId__c,      // Campo External ID no Account
    'EXT-12345'                  // Valor do External ID
);
```

### Relacionamento com Email

```apex
Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
email.setSubject('Test');
email.setPlainTextBody('Body');

Account acc = new Account(Name = 'Test');
uow.registerNew(acc);
uow.registerEmail(email);
uow.registerRelationship(email, acc);  // Define WhatId automaticamente
```

## Platform Events

### Publicar Antes da Transação

```apex
MyEvent__e event = new MyEvent__e(Data__c = 'Before transaction');
uow.registerPublishBeforeTransaction(event);

// Eventos serão publicados ANTES de qualquer DML
uow.commitWork();
```

### Publicar Após Sucesso

```apex
MyEvent__e event = new MyEvent__e(Data__c = 'After success');
uow.registerPublishAfterSuccessTransaction(event);

// Eventos serão publicados APENAS se a transação for bem-sucedida
uow.commitWork();
```

### Publicar Após Falha

```apex
MyEvent__e event = new MyEvent__e(Data__c = 'After failure');
uow.registerPublishAfterFailureTransaction(event);

// Eventos serão publicados APENAS se a transação falhar
uow.commitWork();
```

## Trabalho Customizado

### Registrar Trabalho Genérico

```apex
// Implementar interface IDoWork
public class MyCustomWork implements UnitOfWork.IDoWork {
    public void doWork() {
        // Seu código customizado aqui
        System.debug('Executando trabalho customizado');
    }
}

// Registrar e executar
uow.registerWork(new MyCustomWork());
uow.commitWork();  // doWork() será chamado após DML
```

## Estratégias DML

### System Mode (Padrão)

```apex
// Usa System Mode (ignora permissões de campo/objeto)
IUnitOfWork uow = Application.unitOfWork.newInstance();
```

### User Mode

```apex
// Configurar para usar User Mode
UnitOfWork.UserModeDML userModeDML = new UnitOfWork.UserModeDML();
UnitOfWork uow = new UnitOfWork(
    new List<Schema.SObjectType>{Account.SObjectType, Contact.SObjectType},
    userModeDML
);

// Ou com nível de acesso específico
UnitOfWork.UserModeDML customDML = new UnitOfWork.UserModeDML(System.AccessLevel.USER_MODE);
```

## Ordem de Execução

Quando `commitWork()` é chamado, as operações são executadas nesta ordem:

1. **Hook**: `onCommitWorkStarting()`
2. **Publicar Eventos Antes**: `onPublishBeforeEventsStarting()` → Publica eventos → `onPublishBeforeEventsFinished()`
3. **DML Operations**: `onDMLStarting()` → Insert → Update → Delete → Empty Recycle Bin → Resolve Email Relationships → `onDMLFinished()`
4. **Trabalho Customizado**: `onDoWorkStarting()` → Executa `IDoWork` → Envia emails → `onDoWorkFinished()`
5. **Hook**: `onCommitWorkFinishing()`
6. **Após Commit**:
   - Se sucesso: `onPublishAfterSuccessEventsStarting()` → Publica eventos → `onPublishAfterSuccessEventsFinished()`
   - Se falha: `onPublishAfterFailureEventsStarting()` → Publica eventos → `onPublishAfterFailureEventsFinished()`
7. **Hook Final**: `onCommitWorkFinished(Boolean wasSuccessful)`

## Hooks Customizados

Você pode estender `UnitOfWork` e sobrescrever hooks para adicionar lógica customizada:

```apex
public class MyUnitOfWork extends UnitOfWork {
    public MyUnitOfWork(List<Schema.SObjectType> types) {
        super(types);
    }
    
    public override void onDMLStarting() {
        System.debug('Iniciando DML operations');
    }
    
    public override void onDMLFinished() {
        System.debug('DML operations concluídas');
    }
    
    public override void onCommitWorkFinished(Boolean wasSuccessful) {
        if (wasSuccessful) {
            System.debug('Transação bem-sucedida');
        } else {
            System.debug('Transação falhou');
        }
    }
}
```

## Exemplo Completo

```apex
public class AccountService {
    public void createAccountWithContacts(String accountName, List<String> contactNames) {
        IUnitOfWork uow = Application.unitOfWork.newInstance();
        
        // Criar Account
        Account acc = new Account(Name = accountName);
        uow.registerNew(acc);
        
        // Criar Contacts relacionados
        for (String contactName : contactNames) {
            Contact con = new Contact(LastName = contactName);
            uow.registerNew(con, Contact.AccountId, acc);
        }
        
        // Publicar evento após sucesso
        AccountCreated__e event = new AccountCreated__e(AccountName__c = accountName);
        uow.registerPublishAfterSuccessTransaction(event);
        
        // Enviar email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setSubject('Account Created');
        email.setPlainTextBody('Account ' + accountName + ' was created');
        uow.registerEmail(email);
        uow.registerRelationship(email, acc);
        
        // Executar tudo
        uow.commitWork();
    }
}
```

## API Reference

### IUnitOfWork Interface

```apex
void registerNew(SObject record);
void registerNew(List<SObject> records);
void registerDirty(SObject record);
void registerDirty(List<SObject> records);
void registerDeleted(SObject record);
void registerDeleted(List<SObject> records);
void registerPublishAfterSuccessTransaction(SObject eventRecord);
void commitWork();
```

### UnitOfWork Class (Métodos Adicionais)

- `registerNew(SObject, Schema.SObjectField, SObject)` - Registrar novo com relacionamento
- `registerDirty(SObject, List<Schema.SObjectField>)` - Atualizar campos específicos
- `registerDirty(SObject, Schema.SObjectField, SObject)` - Atualizar com relacionamento
- `registerUpsert(SObject)` - Upsert automático
- `registerPermanentlyDeleted(SObject)` - Exclusão permanente
- `registerPublishBeforeTransaction(SObject)` - Evento antes da transação
- `registerPublishAfterFailureTransaction(SObject)` - Evento após falha
- `registerWork(IDoWork)` - Trabalho customizado
- `registerEmail(Messaging.Email)` - Enviar email
- `registerRelationship(...)` - Vários overloads para relacionamentos
- `getRegisteredNew(String)` - Acessar registros registrados
- `getRegisteredDirty(String)` - Acessar registros sujos
- `getRegisteredDeleted(String)` - Acessar registros deletados

## Boas Práticas

1. **Ordem de Dependência**: Configure os tipos de objetos na ordem correta (menos dependente primeiro)
2. **Uma Transação**: Use um `UnitOfWork` por transação lógica
3. **Rollback Automático**: O `commitWork()` usa savepoint e faz rollback automático em caso de erro
4. **Hooks para Logging**: Use hooks para adicionar logging ou telemetria
5. **User Mode quando Apropriado**: Use User Mode DML para respeitar permissões em produção

## Limitações

- **Limite de DML**: Respeita os limites do Salesforce (150 DML statements por transação)
- **Tipos de Objetos**: Deve registrar os tipos de objetos no construtor
- **Platform Events**: Apenas objetos que terminam com `__e`
- **Relacionamentos**: External IDs devem estar marcados como External ID no schema

## Compatibilidade

- **API Version**: 60.0+
- **Namespaces**: Funciona em orgs com e sem namespace
- **Platform Events**: Requer objetos Platform Event configurados
- **External IDs**: Requer campos marcados como External ID

## Testes

Veja as classes de teste incluídas para exemplos de uso:
- `UnitOfWorkTest.cls`
- `UnitOfWorkSimpleDMLTest.cls`
- `UnitOfWorkUserModeDMLTest.cls`
- `UnitOfWorkEventRegistrationTest.cls`

