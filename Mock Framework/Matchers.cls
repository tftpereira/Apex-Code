/**
 * @description Utility class for creating argument matchers
 */
@isTest
public class Matchers {
    
    /**
     * @description Matches any value
     */
    public static IMatcher any() {
        return new AnyMatcher();
    }
    
    /**
     * @description Matches exact value
     */
    public static IMatcher eq(Object value) {
        return new EqMatcher(value);
    }
    
    /**
     * @description Matches null
     */
    public static IMatcher isNull() {
        return new IsNullMatcher();
    }
    
    /**
     * @description Matches using a custom predicate function
     */
    public static IMatcher matches(Function predicate) {
        return new MatchesMatcher(predicate);
    }
    
    // Implementation classes
    
    private class AnyMatcher implements IMatcher {
        public Boolean matches(Object value) {
            return true;
        }
        public Integer getSpecificity() {
            return 0;
        }
    }
    
    private class EqMatcher implements IMatcher {
        private Object expected;
        
        public EqMatcher(Object expected) {
            this.expected = expected;
        }
        
        public Boolean matches(Object value) {
            if (expected == null) {
                return value == null;
            }
            return expected.equals(value);
        }
        
        public Integer getSpecificity() {
            return 2;
        }
    }
    
    private class IsNullMatcher implements IMatcher {
        public Boolean matches(Object value) {
            return value == null;
        }
        
        public Integer getSpecificity() {
            return 2;
        }
    }
    
    private class MatchesMatcher implements IMatcher {
        private Function predicate;
        
        public MatchesMatcher(Function predicate) {
            this.predicate = predicate;
        }
        
        public Boolean matches(Object value) {
            try {
                Object result = predicate.call(new List<Object>{value});
                return result instanceof Boolean ? (Boolean) result : false;
            } catch (Exception e) {
                return false;
            }
        }
        
        public Integer getSpecificity() {
            return 1;
        }
    }
}

