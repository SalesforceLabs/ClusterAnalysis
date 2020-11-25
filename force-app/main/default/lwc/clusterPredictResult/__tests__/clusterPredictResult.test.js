import { createElement } from 'lwc';
import ClusterPredictResult from 'c/clusterPredictResult';
import predict from '@salesforce/apex/ClusterPredictController.predict';

// Mocking imperative Apex method call
jest.mock(
    '@salesforce/apex/ClusterPredictController.predict',
    () => {
        return {
            default: jest.fn()
        };
    },
    { virtual: true }
);

const PREDICT_RESULT_SUCCESS = require('./data/predictResult.json');

// Sample error for imperative Apex call
const PREDICT_RESULT_ERROR = {
    body: { message: 'An internal server error has occurred' },
    ok: false,
    status: 400,
    statusText: 'Bad Request'
};


describe('c-cluster-predict-result', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        // Prevent data saved on mocks from leaking between tests
        jest.clearAllMocks();
    });

    // Helper function to wait until the microtask queue is empty. This is needed for promise
    // timing when calling imperative Apex.
    let flushPromises = function() {
        // eslint-disable-next-line no-undef
        return new Promise((resolve) => setImmediate(resolve));
    };

    it('Test predict UI rendering and calculations', () => {
        predict.mockResolvedValue(PREDICT_RESULT_SUCCESS);
        const element = createElement('c-cluster-predict-result', {
            is: ClusterPredictResult
        });
        element.jobOrModelId = 'a023B000003CvAEQA0';
        element.recordId = '00Q3B000006d55pUAA';
        document.body.appendChild(element);
        //element.predict();
        return flushPromises().then(() => {
            // Select div for validating conditionally changed text content
            const dl = element.shadowRoot.querySelectorAll(
                'dl.slds-dl_horizontal'
            );
            expect(dl).not.toBeNull();
            const clusterElement = element.shadowRoot.querySelectorAll(
                'dd.prClusterResult'
            );
            expect(clusterElement[0].textContent).toBe('Cluster 2');
        });

    });

    it('Test error handling', () => {
        predict.mockRejectedValue(PREDICT_RESULT_ERROR);
        const element = createElement('c-cluster-predict-result', {
            is: ClusterPredictResult
        });
        element.jobOrModelId = 'a023B000003CvAEQA0';
        element.recordId = '00Q3B000006d55pUAA';
        document.body.appendChild(element);
        return flushPromises().then(() => {
            // Select div for validating conditionally changed text content
            const errorText = element.shadowRoot.querySelectorAll(
                'div.slds-text-color_destructive'
            );
            expect(errorText[0].textContent).toBe(PREDICT_RESULT_ERROR.body.message);
        });
    });
});