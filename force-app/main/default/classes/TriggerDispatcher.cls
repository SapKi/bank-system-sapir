/**
 * Routes Trigger context events to the correct ITriggerHandler method.
 * Triggers stay one-liners: TriggerDispatcher.run(new XyzTriggerHandler());
 * All routing logic lives here so object handlers focus purely on business rules.
 */
public class TriggerDispatcher {

    public static void run(ITriggerHandler handler) {
        if (!Trigger.isExecuting) return;

        if (Trigger.isAfter) {
            if      (Trigger.isInsert) handler.afterInsert(Trigger.new);
            else if (Trigger.isUpdate) handler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
