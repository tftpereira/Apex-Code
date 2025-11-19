/**
 * @description Unique identifier for a method signature (name + parameter types)
 */
@isTest
public class MethodId {
    public String methodName;
    public List<Type> paramTypes;
    
    public MethodId(String methodName, List<Type> paramTypes) {
        this.methodName = methodName;
        this.paramTypes = paramTypes != null ? paramTypes : new List<Type>();
    }
    
    public Boolean equals(Object obj) {
        if (obj instanceof MethodId) {
            MethodId other = (MethodId) obj;
            if (methodName != other.methodName) {
                return false;
            }
            if (paramTypes.size() != other.paramTypes.size()) {
                return false;
            }
            for (Integer i = 0; i < paramTypes.size(); i++) {
                if (paramTypes[i] != other.paramTypes[i]) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }
    
    public Integer hashCode() {
        Integer hash = methodName.hashCode();
        for (Type t : paramTypes) {
            hash = hash * 31 + (t != null ? t.hashCode() : 0);
        }
        return hash;
    }
    
    public String toString() {
        List<String> typeNames = new List<String>();
        for (Type t : paramTypes) {
            typeNames.add(t != null ? String.valueOf(t) : 'null');
        }
        return methodName + '(' + String.join(typeNames, ', ') + ')';
    }
}

