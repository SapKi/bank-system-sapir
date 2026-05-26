/**
 * Trigger handler contract.
 * Every object-specific handler implements this interface and is registered
 * with TriggerDispatcher in a one-line trigger. Adding a new object trigger
 * requires only a new ITriggerHandler implementation — TriggerDispatcher never changes.
 */
public interface ITriggerHandler {
    void afterInsert(List<SObject> newRecords);
    void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldRecords);
}
