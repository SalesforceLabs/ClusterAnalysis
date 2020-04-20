/*
 * Base class for all batch apex based steps
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing abstract class ClusterBatchBase implements Database.Batchable<sObject>, Database.Stateful, ClusterAlgorithmStep {
    public ClusterAlgorithmRunner runner;
    public static Logger log = LogFactory.getLogger();

    public ClusterBatchBase() {
    }   
    
    public virtual void init(ClusterAlgorithmRunner runner) {
        this.runner = runner;
        ClusterJobState jobState = this.runner.getJobState();
        jobState = this.runner.getJobState();
    }

    public virtual void run(){
        Integer batchSize = Test.isRunningTest() ? ClusterConstants.TEST_BATCH_SIZE : ClusterConstants.getBatchSize();
        ClusterJobState jobState = this.runner.getJobState();
        jobState.currentJobId = Database.executeBatch(this, batchSize);
        log.debug('Started batch job: ' + jobState.currentJobId);
    }

    public virtual void done(){
        runner.processNextSteps();
    }

    public Boolean isAsync(){
        return true;
    }   

    protected abstract Database.QueryLocator getBatchQueryLocator();

    public virtual Database.QueryLocator start(Database.BatchableContext bc) {
        Database.QueryLocator query = this.getBatchQueryLocator();
        log.debug('Entering batch start, processing soql query: ' + query.getQuery());
        return query;
    }

    public virtual void execute(Database.BatchableContext bc, List<SObject> scope) {
        log.debug('Entering execute, processing ' + scope.size() + ' records');
        ClusterJobState jobState = this.runner.getJobState();
        try {
            this.processRecords(bc, scope);
        }
        catch (Exception ex) {
            log.error('Exception caught while processing ' + scope.size() + ' records', ex);
            ClusterJobManager.saveJobState(jobState, ClusterConstants.JOBSTATUS_FAILED, ex.getMessage());
            throw ex; //TODO: this will probably rollback everything, maybe abort job instead
        }
    }

    public abstract void processRecords(Database.BatchableContext bc, List<SObject> scope);

    public virtual void finish(Database.BatchableContext bc){
        ClusterJobState jobState = this.runner.getJobState();
        try {
            ClusterJobManager.saveJobState(jobState, ClusterConstants.JOBSTATUS_IN_PROGRESS, '');
            this.done();
            log.debug('Finishing batch job: ' + jobState.currentJobId);
        }
        catch (Exception ex) {
            String logMessage = 'Exception caught during finalization of step ' + jobState.currentAlgorithmStep;
            log.error(logMessage, ex);
            ClusterJobManager.saveJobState(jobState, ClusterConstants.JOBSTATUS_FAILED, logMessage + ': ' + ex.getMessage());
        }
    }    

}
