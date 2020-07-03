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
        log.debug('Entering batch start, processing ' + records.size() + ' records, current heap size: ' + Limits.getHeapSize());
        return records;
    }

    public virtual void execute(Database.BatchableContext bc, Object[] scope) {
        ClusterJobState jobState = this.runner.getJobState();
        log.debug('Entering execute, processing ' + scope.size() + ' records, current heap size: ' + Limits.getHeapSize());
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
            if (bc != null) {
                try {
                    List<SObject> jobs = Database.query('SELECT ApexClassId,CompletedDate,CreatedById,CreatedDate,ExtendedStatus,Id,JobItemsProcessed,JobType,LastProcessed,LastProcessedOffset,MethodName,NumberOfErrors,ParentJobId,Status,TotalJobItems FROM AsyncApexJob WHERE Id=\'' 
                        + String.escapeSingleQuotes(bc.getJobId()) + '\'');
                    if (jobs.size() == 1) {
                        SObject aajob = jobs.get(0);
                        if (Integer.valueOf(aajob.get('NumberOfErrors')) > 0) {
                            throw new ClusterException('Some or all batches in batch job ' + aaJob.get('Id') + ' failed with status: ' + aajob.get('ExtendedStatus') + ', number of errors: ' + aajob.get('NumberOfErrors')); 
                        }
                    }
                }
                catch (ClusterException ex) {
                    //Re-throw ClusterException
                    throw ex;
                }
                catch (Exception ex) {
                    //AsyncApexJob might not be accessible for some reason (Professional org?)
                    //Just log the error and continue
                    log.error('Failed to get async job status', ex);
                }
            }
            if (this.hadErrorsDuringProcessing) {
                throw new ClusterException('The following errors reported during processing: ' + this.lastProcessingError);
            }
            ClusterJobManager.saveJobState(jobState, ClusterConstants.JOBSTATUS_IN_PROGRESS, '');
            log.debug('Finishing batch job: ' + jobState.currentJobId);
            log.debug('Current heap size: ' + Limits.getHeapSize());
            this.done();
        }
        catch (Exception ex) {
            String logMessage = 'Exception caught during finalization of step ' + jobState.currentAlgorithmStep;
            log.error(logMessage, ex);
            ClusterJobManager.saveJobState(jobState, ClusterConstants.JOBSTATUS_FAILED, logMessage + ': ' + ex.getMessage());
        }
    }    

}
