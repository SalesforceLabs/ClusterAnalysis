/*
 * Base class for algorithms logic
 *
 * @author: Iskander Mukhamedgaliyev
 */
public abstract with sharing class ClusterAlgorithmRunner {
    private static final String MSG_ERR_MAX_ITERATIONS = 'Maximum algorithm iterations reached, job was interrupted';
    private static final String MSG_JOB_CANCELLED = 'Job was cancelled by request';
    @TestVisible
    private static final String MSG_ERR_OUTPUTFIELDVALIDATION = 'Cluster Result Output field name must start with \'ClusterNumber\' and should belong to the model object. Please create a new custom field which starts with \'ClusterNumber\'';
    public class ModelValidationResult {
        public List<String> messages;
        public Boolean isValid;        
    }
    public static Logger log = LogFactory.getLogger();
    @TestVisible
    private static ClusterJobState jobState;
    public List<ClusterAlgorithmStep> steps;
    public ClusterDistanceCacheManager distanceCacheManager;
    public ClusterAlgorithmRunner() {
        this.steps = new List<ClusterAlgorithmStep>();
        this.objectFactory = new ClusterObjectFactory();
    }

    public abstract void initializeDistanceCache();

    public virtual ClusterAlgorithmRunner.ModelValidationResult validateModel(ClusterModelWrapper model) {
        ModelValidationResult result = new ModelValidationResult();
        result.isValid = true;
        result.messages = new List<String>();
        Boolean hasIdField = false;
        Boolean hasValueFields = false;
        Integer longTextFieldCount = 0;
        for (Integer i=0; i<model.fields.size(); i++) {
            if (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_OUTPUT) {
                result.isValid &= model.fields[i].name.toLowerCase().startsWith('clusternumber');
                result.isValid &= model.objectName.toLowerCase() == model.fields[i].objectName.toLowerCase();
            }
            else if (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_NONE && model.fields[i].isIdField) {
                hasIdField = true;
            }
            else if ((model.fields[i].distanceType == ClusterConstants.FIELDTYPE_CATEGORY) || 
                (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_NUMERIC) || 
                (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_TEXT) ||
                (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_LONGTEXT)) 
            {
                hasValueFields = true;
                if (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_LONGTEXT) {
                    longTextFieldCount++;
                }
            }
        }
        if (!result.isValid) {
            result.messages.add(MSG_ERR_OUTPUTFIELDVALIDATION);
        }
        if (!hasIdField) {
            result.isValid = false;
            result.messages.add('Model must have object id field');
        }
        if (!hasValueFields) {
            result.isValid = false;
            result.messages.add('Model must have at least one Numeric, Category or Text field');
        }
        if (longTextFieldCount > 1) {
            result.isValid = false;
            result.messages.add('Model can have only one long text field');
        }
        List<String> accessErrors = ClusterAccessCheck.checkModelObjectAccessPermissions(model);
        if (accessErrors.size() > 0) {
            result.isValid = false;
            result.messages.addAll(accessErrors);
        }
        return result;
    }

    public virtual void init(ClusterModelWrapper model) {
        Boolean hasJobOutput = false;
        for (Integer i=0; i<model.fields.size(); i++) {
            if (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_OUTPUT) {
                hasJobOutput = true;
                break;
            }
        }
        if (hasJobOutput) {
            ClusterJobOutputStep jobOutputStep = new ClusterJobOutputStep();
            this.steps.add(jobOutputStep);
        }
    }
    public abstract ClusterJobState getJobState();    
    public abstract ClusterJobState createJobState();    
    private ClusterObjectFactory objectFactory{ get; set; }

    public virtual void start() {
        try {
            ClusterJobState state = this.getJobState();
            log.debug('Starting algorithm: ' + state.model.algorithm);
            //We will CRUD permissions on ClusterJobResult__c once here and will not check check them in every step
            ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobResult__c);
            state.clusterJob = ClusterJobManager.createJob(state.model.name, state.model);
            state.jobClusters = ClusterJobManager.createJobClusters(state.clusterJob);
            state.totalIterationsCount = 0;
            log.debug('Created cluster job: ' + state.clusterJob);
            log.debug('Created ' + state.jobClusters.size() + ' job clusters');
            log.debug('Executing algorithm steps');
            this.runCurrentStep();
            if (!this.steps[state.currentAlgorithmStep].isAsync()) {
                this.processNextSteps();
            }
        }
        catch (Exception ex) {
            log.error('Exception caught in start method', ex);
            throw ex;
        }
    }

    public virtual void runCurrentStep(){
        ClusterJobState state = this.getJobState();
        log.debug('Running algorithm step ' + state.currentAlgorithmStep);
        ClusterAlgorithmStep currentStep = this.steps[state.currentAlgorithmStep];
        currentStep.init(this);
        currentStep.run();
        if (!currentStep.isAsync()) {
            currentStep.done();
        }
    }

    public virtual void processNextSteps() {
        ClusterJobState state = this.getJobState();
        log.debug('Finished algorithm step ' + state.currentAlgorithmStep);
        while (state.currentAlgorithmStep < this.steps.size()) {
            state.totalIterationsCount++;
            if (state.totalIterationsCount > ClusterConstants.getMaxIterations()) {
                //Break if exceeded max iterations
                log.error(MSG_ERR_MAX_ITERATIONS);
                ClusterJobManager.saveJobState(state, ClusterConstants.JOBSTATUS_CANCELLED, MSG_ERR_MAX_ITERATIONS);
                break;
            }
            ClusterJob__c currentJob = ClusterJobManager.getJob(state.clusterJob.Id);
            if (currentJob.JobStatus__c == ClusterConstants.JOBSTATUS_MARKED_FOR_CANCEL) {
                //Break if job was marked for cancel, set status to calcelled
                log.debug(MSG_JOB_CANCELLED);
                ClusterJobManager.saveJobState(state, ClusterConstants.JOBSTATUS_CANCELLED, MSG_JOB_CANCELLED);
                break;
            }
            if (currentJob.JobStatus__c == ClusterConstants.JOBSTATUS_FAILED) {
                //Break if job status is failed
                log.debug('Job status was set to FAILED on the previous step. Finishing algorithm execution');
                break;
            }
            Boolean lastStep = this.prepareNextStep();
            jobState = state;
            if (lastStep || state.currentAlgorithmStep > this.steps.size() - 1) {
                log.debug('Finished algorithm ' + state.model.algorithm);
                ClusterJobManager.saveJobState(state, ClusterConstants.JOBSTATUS_COMPLETED, 'Cluster job finished');
                break;
            }
            else {
                ClusterJobManager.saveJobState(state, ClusterConstants.JOBSTATUS_IN_PROGRESS, 'Executing step ' + (state.currentAlgorithmStep + 1) + ' of ' + this.steps.size());
                if (Test.isRunningTest()){
                    break; //Can't chain batch apex if running test
                }
                this.runCurrentStep();
                if (this.steps[state.currentAlgorithmStep].isAsync()) {
                    break; //If step is async this method will be called again
                }
            }
        }
    }
    public abstract Boolean prepareNextStep();

    public virtual Double calculateDPDistance(ClusterDataPoint currentObject, ClusterDataPoint centroid) {
        //Check cache if both data points are loaded into sample array
        if (currentObject.index != null && centroid.index != null) {
            double distance = this.distanceCacheManager.get(currentObject, centroid);
            if (distance == null) {
                distance = this.calculateDistance(currentObject.values, centroid.values);
                this.distanceCacheManager.set(currentObject, centroid, distance);
            }
            return distance;
        }
        return this.calculateDistance(currentObject.values, centroid.values);
    }

    public ClusterSObjectProcessor getSObjectProcessor() {
        return this.objectFactory.createSObjectProcessor(this.getJobState());
    }

    public void setJobState(String jobStateJson) {
        Map<String, Object> jobStateValues = (Map<String, Object>)JSON.deserializeUntyped(jobStateJson);
        ClusterJobState newJobState = this.createJobState();
        newJobState.loadFromMap(jobStateValues);
        this.init(newJobState.model);
        this.setJobState(newJobState);
    }

    public abstract void setJobState(ClusterJobState state);

    public Integer predict(Id recordId, String jobStateJson) {
        this.setJobState(jobStateJson);
        return this.predict(recordId);
    }

    public Integer predict(Id dpRecordId) {
        ClusterDataPoint dataPoint = this.getDataPoint(dpRecordId);
        return this.predict(dataPoint);
    }

    public ClusterDataPoint getDataPoint(Id recordId) {
        ClusterModelWrapper model = this.getJobState().model;
        String keyCode = String.valueOf(recordId).subString(0,3);
        Schema.DescribeSObjectResult objectDescribe = ClusterUtils.findObjectDescByKeyCode(keyCode);
        if (objectDescribe.getName().toLowerCase() != model.objectName.toLowerCase()) {
            throw new ClusterException('Model object (' + model.objectName +') does not match with the record id object (' + objectDescribe.getName() + ')');
        }
        String modelSoql = model.generateSoqlSelect();
        modelSoql += ' WHERE Id=\'' + String.escapeSingleQuotes(String.valueOf(recordId)) + '\'';
        ClusterAlgorithmRunner.ModelValidationResult vr = this.validateModel(model);
        if (!vr.isValid) {
            ClusterException ex = new ClusterException();
            ex.setMessage('Model validation failed. Error message(s): ' + String.join(vr.messages,'\n'));
            throw ex;
        }
        List<SObject> predictRecords = Database.query(modelSoql);
        if (predictRecords.size() != 1) {
            throw new ClusterException('Record with id ' + recordId + ' was not found');
        }
        ClusterSObjectProcessor objectProcessor = this.getSObjectProcessor();
        return objectProcessor.processSObject(predictRecords.get(0));
    }

    public abstract Integer predict(ClusterDataPoint dataPoint);

    protected abstract Double calculateDistance(Object[] currentObject, Object[] centroid);

    public abstract ClusterAlgorithmParameter[] getParameters(ClusterModelWrapper model);
    
}