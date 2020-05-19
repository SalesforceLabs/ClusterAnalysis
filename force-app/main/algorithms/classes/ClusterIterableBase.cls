public with sharing abstract class ClusterIterableBase implements Database.Batchable<Object>, Database.Stateful, ClusterAlgorithmStep {
    public ClusterAlgorithmRunner runner;
    private Integer batchSize;
    private Boolean hadErrorsDuringProcessing = false;
    private String lastProcessingError;

    public static Logger log = LogFactory.getLogger();

    public ClusterIterableBase() {

    }

    public ClusterIterableBase(Integer batchSize) {
        this.batchSize = batchSize;
    }   
    
    public virtual void init(ClusterAlgorithmRunner runner) {
        this.runner = runner;
    }

    public virtual void run() {
        ClusterJobState jobState = this.runner.getJobState();
        jobState.currentJobId = Database.executeBatch(this, this.batchSize);
        log.debug('Started batch job: ' + jobState.currentJobId);
    }

    public virtual void done(){
        runner.processNextSteps();
    }

    public Boolean isAsync(){
        return true;
    }   

    protected abstract Object[] getRecords();

    public virtual Object[] start(Database.BatchableContext bc) {
        Object[] records = this.getRecords();
        log.debug('Entering batch start, processing ' + records.size() + ' records');
        return records;
    }

    public virtual void execute(Database.BatchableContext bc, Object[] scope) {
        ClusterJobState jobState = this.runner.getJobState();
        log.debug('Entering execute, processing ' + scope.size() + ' records');
        try {
            this.processRecords(bc, scope);
        }
        catch (Exception ex) {
            this.hadErrorsDuringProcessing = true;
            this.lastProcessingError = ex.getMessage();
            log.error('Exception caught while processing ' + scope.size() + ' records', ex);
            ClusterJobManager.saveJobState(jobState, ClusterConstants.JOBSTATUS_FAILED, ex.getMessage());
            throw ex;
        }
        log.debug('Finished processing the chunk, current heap size: ' + Limits.getHeapSize());
    }

    public abstract void processRecords(Database.BatchableContext bc, Object[] scope);

    public virtual void finish(Database.BatchableContext bc){
        ClusterJobState jobState = this.runner.getJobState();
        try {
            if (this.hadErrorsDuringProcessing) {
                throw new ClusterException('The following errors reported during processing: ' + this.lastProcessingError);
            }
            ClusterJobManager.saveJobState(jobState, ClusterConstants.JOBSTATUS_IN_PROGRESS, '');
            log.debug('Finishing batch job: ' + jobState.currentJobId);
            this.done();
        }
        catch (Exception ex) {
            String logMessage = 'Exception caught during finalization of step ' + jobState.currentAlgorithmStep;
            log.error(logMessage, ex);
            ClusterJobManager.saveJobState(jobState, ClusterConstants.JOBSTATUS_FAILED, logMessage + ': ' + ex.getMessage());
        }
    }    

}
