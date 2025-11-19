/**
 * @description Simple test interface for mocking framework tests
 */
@isTest
public interface TestInterface {
    Integer sum(Integer a, Integer b);
    String lookup(String key);
    void save(Object record);
    String process(String input, Integer count);
    Object getValue();
    void doNothing();
}

