({
    init: function() {
    },

    fireGraphDataPointHoverEvent: function(component, dataPoint) {
        var graphDataPointHoverEvent = component.getEvent('graphDataPointHoverEvent');
        graphDataPointHoverEvent.setParams({ "dataPoint" : dataPoint });
        graphDataPointHoverEvent.fire();
    },

    loadDataPoints: function (component, offset) {
        let jobDetails = component.get('v.jobDetails');
        let action = component.get("c.getDataPointsJson");
        let hasLongText = false;
        for (let i = 0; i < jobDetails.model.fields.length; i++) {
            if (jobDetails.model.fields[i].isLongText) {
                hasLongText = true;
                break;
            }
        }
        //Setting smaller batch size for long text fields to avoid Apex heap limit
        let count = hasLongText ? 100 : 500;
        action.setParams({ jobId: jobDetails.jobId, maxCount: count, offset: offset });
        let helper = this;
        console.log('Loading data points, offset: ' + offset);
        action.setCallback(this, helper.getServerCallbackFunction(component, helper,
            function (dataPointsJson) {
                helper.wrapTryCatch(component, () => {
                    helper.loadDataPointsCallback(component, dataPointsJson, offset, count);
                });
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },

    loadDataPointsCallback: function(component, dataPointsJson, offset, maxCount) {
        let jobDetails = component.get('v.jobDetails');
        let dataPoints = JSON.parse(dataPointsJson);
        for (let i=0; i<dataPoints.length; i++) {
            dataPoints[i].values = JSON.parse(dataPoints[i].valuesJson);
            this.processDataPointValues(jobDetails.state, dataPoints[i].values);
            dataPoints[i].valuesJson = null;
        }
        let allDataPoints = component.get('v.dataPoints');
        let helper = this;
        
        allDataPoints = (allDataPoints == null) ? dataPoints : allDataPoints.concat(dataPoints);
        if ((dataPoints.length < maxCount) || (offset > jobDetails.maxGraphDataPoints)) {
            if (jobDetails.model.algorithm == 'K-Means') {
                //jobDetails.state.centroids.forEach(c => helper.processDataPointValues(jobDetails.state, c.values));
                allDataPoints = allDataPoints.concat(jobDetails.state.centroids); //Adding centroids to data points array for K-Means for visualization
            }
            component.set("v.dataPoints", allDataPoints);
            //Sometimes d3 script is not fully loaded and initialized, so we give it some time
            window.setTimeout(
                $A.getCallback(function() {
                    try {
                        helper.runTSNE(component, allDataPoints, jobDetails);
                    }
                    catch (e) {
                        console.error(e);
                    }
                }), 1000
            );                    
        }
        else {
            //Load next data points batch
            component.set("v.dataPoints", allDataPoints);
            offset += maxCount;
            this.loadDataPoints(component, offset);
        }
    },

    getNodeStrokeColor: function(dataPoint) {
        return (dataPoint && dataPoint.isCentroid) ? "black" : "none";
    },

    runTSNE: function(component, dataPoints, jobDetails) {
        //TODO: implement t-SNE calc as a web worker (hopefully Locker service supports them)
        let distances = component.get('v.distances');
        let helper = this;
        if (!distances) {
            // initialize data with pairwise distances
            let callback = function(distanceMatrix) {
                component.set('v.distances', distanceMatrix);
                helper.drawTSNE3(component, dataPoints, jobDetails, distanceMatrix);
            };
            this.calculateDistanceMatrix(dataPoints, jobDetails.state, callback);            
        }
        else {        
            helper.drawTSNE3(component, dataPoints, jobDetails, distances);
        }
    },    

    drawTSNE3: function (component, dataPoints, jobDetails, distances) {
        if (this.d3simulation) {
            this.d3simulation.stop();
            this.d3simulation = null;
        }
        const data = dataPoints;
        // set the dimensions and margins of the graph
        const margin = { top: 10, right: 30, bottom: 30, left: 60 },
            width = component.get('v.width') - margin.left - margin.right,
            height = component.get('v.height') - margin.top - margin.bottom;

        //let divElement = d3.select(".my_dataviz");
        let divId = component.getGlobalId() + "_tsneplot";
        let divElement = d3.select(document.getElementById(divId));
        divElement.selectAll("*").remove();

        let svgElement = divElement
            .append("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .attr("class", "tsnesvg");

        // append the SVG object to the body of the page
        let SVG = svgElement
            .append("g")
            .attr("transform",
                "translate(" + margin.left + "," + margin.top + ")");

        // Add X axis
        let x = d3.scaleLinear()
            .domain([-100, 100])
            .range([0, width]);

        // Add Y axis
        let y = d3.scaleLinear()
            .domain([-100, 100])
            .range([height, 0]);
        // Create the scatter variable: where both the circles and the brush take place
        let scatter = SVG.append('g');
            //.attr("clip-path", "url(#clip)");


        const model = new tsnejs.tSNE({
            dim: 2, //Number of dimensions
            epsilon: component.get('v.epsilon'),
            perplexity: component.get('v.perplexity'),
        });

        let helper = this;
        let helpernodes = null;

        model.initDataDistArray(distances);

        // Add the tooltip container to the vis container
        // it's invisible and its position/contents are defined during mouseover
        let tooltip = d3.select(document.getElementById(divId)).append("div")
            .attr("class", "dptooltip")
            .style("opacity", 0);

        // tooltip mouseover event handler
        let tipMouseover = function(d,i) {
            d3.select(this).style("stroke", "black");
            helper.fireGraphDataPointHoverEvent(component, dataPoints[i]);
        };
        // tooltip mouseout event handler
        let tipMouseout = function(d) {
            d3.select(this).style("stroke", (d, i) => { return helper.getNodeStrokeColor(d); });
        };
        let nodeMouseout = function(d) {
            d3.select(this).style("stroke", "none");
        }
        let isCollide = component.get('v.collide');
        tooltip.on("mouseout", tipMouseout);
        let draw = function (nodes) {
            if (!helpernodes) {
                // Add circles
                helpernodes = scatter
                    .selectAll("circle")
                    .remove()
                    .data(nodes)
                    .enter()
                    .append("circle")
                    .attr("cx", function (d) { return d.x; })
                    .attr("cy", function (d) { return d.y; })
                    .attr("r", 4)
                    .style("opacity", d => d.isCentroid || isCollide ? 1 : 0.5)
                    .style("fill", (d, i) => { return jobDetails.clusterColors[dataPoints[i].clusterIndex]; })
                    .style("stroke", (d, i) => { return helper.getNodeStrokeColor(d); })
                    .on("mouseover", tipMouseover)
                    .on("mouseout", tipMouseout);
            }
            else {
                helpernodes.transition()
                    .attr("cx", function (d) { return d.x; })
                    .attr("cy", function (d) { return d.y; });

            }
        };

        let forceData = data.map(d => (d.x = width / 2, d.y = height / 2, d.isCentroid = jobDetails.state.centroids.find(c => c.recordId == d.recordId) != undefined, d));
        draw(forceData);
        let tsneSteps = 0;
        const forcetsne = d3.forceSimulation(forceData)
            .alphaDecay(0.01)
            .alpha(0.2)
            .force('tsne', function (alpha) {
                // every time you call this, solution gets better
                model.step();
                tsneSteps++;
                // Y is an array of 2-D points that you can plot
                let pos = model.getSolution();

                x.domain(d3.extent(pos.map(d => d[0])));
                y.domain(d3.extent(pos.map(d => d[1])));
                data.forEach((d, i) => {
                    d.posX = pos[i][0];
                    d.posY = pos[i][1];
                    d.x += alpha * (x(pos[i][0]) - d.x);
                    d.y += alpha * (y(pos[i][1]) - d.y);
                });
            })
            .on('tick', function () {
                draw(data);
            });
        if (isCollide) {
            forcetsne.force('collide', d3.forceCollide().radius(d => 1.5 + 4));
        }
        this.d3simulation = forcetsne;
        //Zoom functions 
        let zoom_actions = function(){
            SVG.attr("transform", d3.event.transform);
        };
        //add zoom capabilities 
        let zoom_handler = d3.zoom()
            .scaleExtent([.5, 20])  // This control how much you can unzoom (x0.5) and zoom (x20)
            .extent([[0, 0], [width, height]])
            .on("zoom", zoom_actions);
        zoom_handler(svgElement);
        
    },

    createFloatArray: function(n) {
        if(typeof(n)==='undefined' || isNaN(n)) { return []; }
        if(typeof ArrayBuffer === 'undefined') {
            // lacking browser support
            var arr = new Array(n);
            for(var i=0;i<n;i++) { arr[i]= 0; }
            return arr;
        } else {
            return new Float64Array(n); // typed arrays are faster
        }
    },

    calculateDistanceMatrix: function (dataPoints, jobState, callback) {
        console.log('Calculating distance matrix');
        let distanceMatrix = this.createFloatArray(dataPoints.length * dataPoints.length); 
        //Calculating pairwise distance (dissimilarities)
        //We will divide the whole process by 100 record chunks and have 0.5 seconds timeout between them to avoid browser UI freezing
        //Aura components don't support async/await yet so the code below emulates this feature
        let chunker = {
            helper: this,
            processBatch: function(chunkStart, chunkSize) {
                let length = Math.min(chunkStart + chunkSize, dataPoints.length);
                let n = dataPoints.length;
                for (let i = chunkStart; i < length; i++) {
                    for (let j = i+1; j < dataPoints.length; j++) {
                        let d = (i == j) ? 0 :
                            this.helper.gowerDistance(dataPoints[i].values, dataPoints[j].values, jobState);
                        distanceMatrix[i*n+j] = d;
                        distanceMatrix[j*n+i] = d;
                    }
                }
            },            
            processMatrix: function(callback, distanceMatrix) {
                let length = dataPoints.length;
                let chunkSize = 100;
                let numChunks = Math.ceil(length / chunkSize);
                let self = this;
                let p = Promise.resolve();                
				for (let i = 0; i < numChunks; i++) {
    				p = p.then(_ => new Promise(resolve =>
        				setTimeout($A.getCallback(function () {
                            try {
                                console.log('Processing chunk ' + (i+1) + ' of ' + numChunks);
                                self.processBatch(i * chunkSize, chunkSize);            				
                                if (i == numChunks - 1) {
                                    console.log('Distance calculations complete');
                                    setTimeout(function() { callback(distanceMatrix); }, 2000);
                                }
                                resolve();
                            }
                            catch(e) {
                                console.error(e);
                            }
        				}), 500)
                    ));
				}
            }

        };
        chunker.processMatrix(callback, distanceMatrix);
    },

    gowerDistance: function (currentObject, centroid, jobState) {
        return clustanUtils.gowerDistance(currentObject, centroid, jobState);
    },

    encodeHtml: function(rawStr) {
        if (typeof rawStr !== 'string') return rawStr;
        let p = document.createElement("p");
        p.textContent = rawStr;
        return p.innerHTML;
    },

    processDataPointValues: function(jobState, values) {
        clustanUtils.decompressDataPointValues(jobState, values);
    },

})