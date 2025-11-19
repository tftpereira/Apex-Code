public with sharing class Application {
    /**
     * Factory to create configured UnitOfWork instances.
     * Mirrors the fflib pattern while using our standalone UnitOfWork.
     */
    public class UnitOfWorkFactory {
        private List<Schema.SObjectType> types;
        private UnitOfWork.IDML dml;

        public UnitOfWorkFactory(List<Schema.SObjectType> types) {
            this(types, new UnitOfWork.SimpleDML());
        }

        public UnitOfWorkFactory(List<Schema.SObjectType> types, UnitOfWork.IDML dml) {
            this.types = types == null ? new List<Schema.SObjectType>() : types.clone();
            this.dml = dml == null ? new UnitOfWork.SimpleDML() : dml;
        }

        public IUnitOfWork newInstance() {
            return new UnitOfWork(types, dml);
        }
    }

    // Configure once for your org; add your dependency-ordered types here
    public static final Application.UnitOfWorkFactory unitOfWork =
        new Application.UnitOfWorkFactory(new List<Schema.SObjectType>{
            QuoteLineItem.SObjectType,
            Quote.SObjectType
        });
}


