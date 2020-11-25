import { createElement } from 'lwc';
import ClusterPredict from 'c/clusterPredict';
import getPredictUiModel from '@salesforce/apex/ClusterPredictController.getPredictUiModel';

// Mocking imperative Apex method call
jest.mock(
    '@salesforce/apex/ClusterPredictController.getPredictUiModel',
    () => {
        return {
            default: jest.fn()
        };
    },
    { virtual: true }
);

const PREDICT_SEARCHUI_SUCCESS = {
    models: [],
    jobId: 'a023B000003CvAEQA0',
    recordIdNeeded: true,
    modelObjectLabel: 'Lead'
}

const PREDICT_MODELUI_SUCCESS = {
    models: [],
    jobId: 'a023B000003CvAEQA0',
    recordIdNeeded: false,
    modelObjectLabel: 'Lead'
}

// Sample error for imperative Apex call
const PREDICT_MODEL_ERROR = {
    body: { message: 'An internal server error has occurred' },
    ok: false,
    status: 400,
    statusText: 'Bad Request'
};

describe('c-cluster-predict', () => {
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

    it('Test lookup UI rendering', () => {
        getPredictUiModel.mockResolvedValue(PREDICT_SEARCHUI_SUCCESS);
        const element = createElement('c-cluster-predict', {
            is: ClusterPredict
        });
        document.body.appendChild(element);
        return flushPromises().then(() => {
            // check if c-lookup was created
            const lookup = element.shadowRoot.querySelectorAll(
                'c-lookup'
            );
            expect(lookup[0]).toBeDefined();
        });
    });

    it('Test model picker UI rendering', () => {
        getPredictUiModel.mockResolvedValue(PREDICT_MODELUI_SUCCESS);
        const element = createElement('c-cluster-predict', {
            is: ClusterPredict
        });
        document.body.appendChild(element);
        return flushPromises().then(() => {
            // check if c-lookup was created
            const verticalNav = element.shadowRoot.querySelectorAll(
                'lightning-vertical-navigation'
            );
            expect(verticalNav[0]).toBeDefined();
            // check if c-lookup was created
            const lookup = element.shadowRoot.querySelectorAll(
                'c-lookup'
            );
            expect(lookup[0]).toBeUndefined();
            const errorText = element.shadowRoot.querySelectorAll(
                'div.slds-text-color_destructive'
            );
            expect(errorText[0].textContent).toBe('');
        });
    });

    it('Test error handling', () => {
        getPredictUiModel.mockRejectedValue(PREDICT_MODEL_ERROR);
        const element = createElement('c-cluster-predict', {
            is: ClusterPredict
        });
        document.body.appendChild(element);
        return flushPromises().then(() => {
            // Select div for validating conditionally changed text content
            const errorText = element.shadowRoot.querySelectorAll(
                'div.slds-text-color_destructive'
            );
            expect(errorText[0].textContent).toBe(PREDICT_MODEL_ERROR.body.message);
        });
    });
});