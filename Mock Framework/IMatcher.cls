/**
 * @description Interface for argument matchers
 */
@isTest
public interface IMatcher {
    /**
     * @description Returns true if the value matches
     */
    Boolean matches(Object value);
    
    /**
     * @description Returns the specificity score (higher = more specific)
     * literal/eq = 2, matches = 1, any = 0
     */
    Integer getSpecificity();
}

