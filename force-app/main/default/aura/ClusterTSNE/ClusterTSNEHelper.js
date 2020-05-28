({
    d3clusterColors: ["#1b70fc", "#faff16", "#d50527", "#158940", "#f898fd", "#24c9d7", "#cb9b64", "#866888", "#22e67a",
        "#e509ae", "#9dabfa", "#437e8a", "#b21bff", "#ff7b91", "#94aa05", "#ac5906", "#82a68d", "#fe6616", "#7a7352", "#f9bc0f",
        "#b65d66", "#07a2e6", "#c091ae", "#8a91a7", "#88fc07", "#ea42fe", "#9e8010", "#10b437", "#c281fe", "#f92b75", "#07c99d",
        "#a946aa", "#bfd544", "#16977e", "#ff6ac8", "#a88178", "#5776a9", "#678007", "#fa9316", "#85c070", "#6aa2a9", "#989e5d",
        "#fe9169", "#cd714a", "#6ed014", "#c5639c", "#c23271", "#698ffc", "#678275", "#c5a121", "#a978ba", "#ee534e", "#d24506",
        "#59c3fa", "#ca7b0a", "#6f7385", "#9a634a", "#48aa6f", "#ad9ad0", "#d7908c", "#6a8a53", "#8c46fc", "#8f5ab8", "#fd1105",
        "#7ea7cf", "#d77cd1", "#a9804b", "#0688b4", "#6a9f3e", "#ee8fba", "#a67389", "#9e8cfe", "#bd443c", "#6d63ff", "#d110d5",
        "#798cc3", "#df5f83", "#b1b853", "#bb59d8", "#1d960c", "#867ba8", "#18acc9", "#25b3a7", "#f3db1d", "#938c6d", "#936a24",
        "#a964fb", "#92e460", "#a05787", "#9c87a0", "#20c773", "#8b696d", "#78762d", "#e154c6", "#40835f", "#d73656", "#1afd5c",
        "#c4f546", "#3d88d8", "#bd3896", "#1397a3", "#f940a5", "#66aeff", "#d097e7", "#fe6ef9", "#d86507", "#8b900a", "#d47270",
        "#e8ac48", "#cf7c97", "#cebb11", "#718a90", "#e78139", "#ff7463", "#bea1fd"],
    
    init: function() {
    },

    loadDataPoints: function (component, offset) {
        let jobDetails = component.get('v.jobDetails');
        let action = component.get("c.getDataPointsJson");
        let count = 50;
        action.setParams({ jobId: jobDetails.jobId, maxCount: count, offset: offset });
        let helper = this;
        console.log('Loading data points, offset: ' + offset);
        action.setCallback(this, helper.getServerCallbackFunction(component, helper,
            function (dataPointsJson) {
                helper.loadDataPointsCallback(component, dataPointsJson, offset, count);
            },
            function (state, errors) {
            })
        );
        $A.enqueueAction(action);
    },

    loadDataPointsCallback: function(component, dataPointsJson, offset, maxCount) {
        let dataPoints = JSON.parse(dataPointsJson);
        let allDataPoints = component.get('v.dataPoints');
        let jobDetails = component.get('v.jobDetails');
        let helper = this;
        
        allDataPoints = (allDataPoints == null) ? dataPoints : allDataPoints.concat(dataPoints);
        if ((dataPoints.length < maxCount) || (offset > jobDetails.maxGraphDataPoints)) {
            if (jobDetails.model.algorithm == 'K-Means') {
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
            let color = helper.d3clusterColors[dataPoints[i].clusterIndex];
            let html  = helper.encodeHtml(d.recordName) + "<br/>" +
                "<span>Cluster: " + dataPoints[i].clusterIndex + "</span><div class='clusterbox' style='background-color:" + color + ";'></div><br/>";
            let dl = "<div class='slds-region_narrow' style='width: " + width.toString() + "px'><dl class='slds-dl_horizontal'>";
            for (let fi=0; fi<jobDetails.model.fields.length; fi++) {
                if (d.values[fi] == d.recordName)
                    continue;
                let fieldValue = d.values[fi];
                if (jobDetails.model.fields[fi].dataType == 'datetime' && fieldValue != null) {
                    fieldValue = new Date(fieldValue);
                }
                dl += '<dt class="slds-dl_horizontal__label">' +
                    '<p class="slds-truncate">' + helper.encodeHtml(jobDetails.model.fields[fi].name) + '</p></dt>' + 
                '<dd class="slds-dl_horizontal__detail slds-tile__meta">' +
                '<p class="slds-truncate">' + helper.encodeHtml(fieldValue) + '</p></dd>';
            }
            html += dl + "</dl></div>";
            tooltip.html(html)
                .transition()
                .duration(200) // ms
                .style("opacity", .9) // started as 0!

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
                    .style("fill", (d, i) => { return helper.d3clusterColors[dataPoints[i].clusterIndex]; })
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
                                    callback(distanceMatrix);
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

    // code from https://github.com/trekhleb/javascript-algorithms/tree/master/src/algorithms/string/levenshtein-distance
    levenshteinDistance: function (a, b) {
        // Create empty edit distance matrix for all possible modifications of
        // substrings of a to substrings of b.
        const distanceMatrix = Array(b.length + 1).fill(null).map(() => Array(a.length + 1).fill(null));

        // Fill the first row of the matrix.
        // If this is first row then we're transforming empty string to a.
        // In this case the number of transformations equals to size of a substring.
        for (let i = 0; i <= a.length; i += 1) {
            distanceMatrix[0][i] = i;
        }

        // Fill the first column of the matrix.
        // If this is first column then we're transforming empty string to b.
        // In this case the number of transformations equals to size of b substring.
        for (let j = 0; j <= b.length; j += 1) {
            distanceMatrix[j][0] = j;
        }

        for (let j = 1; j <= b.length; j += 1) {
            for (let i = 1; i <= a.length; i += 1) {
                const indicator = a[i - 1] === b[j - 1] ? 0 : 1;
                distanceMatrix[j][i] = Math.min(
                    distanceMatrix[j][i - 1] + 1, // deletion
                    distanceMatrix[j - 1][i] + 1, // insertion
                    distanceMatrix[j - 1][i - 1] + indicator // substitution
                );
            }
        }

        return distanceMatrix[b.length][a.length];
    },

    calculateNumericGowerDistance: function (a, b, delta) {
        if (a == null && b == null) return 0;
        let d = 0;
        try {
            d = Math.abs(a - b) / delta;
        }
        catch (ex) { 
            d = 1;
        }
        return d;
    },

    calculateTextGowerDistance: function (a, b, min, max) {
        if (a == null && b == null) return 0;
        let r = max;
        let d = 0;
        try {
            if (a == null) {
                d = Number(b.length()) / r;
            }
            else if (b == null) {
                d = Number(a.length()) / r;
            }
            else d = this.levenshteinDistance(a, b) / r;
        }
        catch (ex) { 
            d = 1;
        }
        return d;
    },

    calculateCategoryGowerDistance: function (a, b) {
        if (a == null && b == null) return 0;
        return (a == b) ? 0 : 1;
    },

    gowerDistance: function (currentObject, centroid, jobState) {
        let distance = 0;
        let weight = 0;
        let model = jobState.model;
        for (let i = 0; i < model.fields.length; i++) {
            if (model.fields[i].isNumeric) {
                distance += model.fields[i].weight * this.calculateNumericGowerDistance(Number(currentObject[i]), Number(centroid[i]),
                    Number(jobState.minMaxValues[i].delta));
                weight += model.fields[i].weight;
            }
            else if (model.fields[i].isText) {
                distance += model.fields[i].weight * this.calculateTextGowerDistance(String(currentObject[i]), String(centroid[i]),
                    Number(jobState.minMaxValues[i].minValue), Number(jobState.minMaxValues[i].maxValue));
                weight += model.fields[i].weight;
            }
            else if (model.fields[i].isCategory) {
                distance += model.fields[i].weight * this.calculateCategoryGowerDistance(String(currentObject[i]), String(centroid[i]));
                weight += model.fields[i].weight;
            }
            else if (model.fields[i].isLongText) {
                let tf1 = currentObject[i];
                let tf2 = centroid[i];
                let idf = jobState.minMaxValues[i].maxValue;
                distance += model.fields[i].weight * this.calculateCosineDistance(tf1, tf2, idf);
                weight += model.fields[i].weight;
            }
        }
        return distance / weight;
    },

    calculateCosineDistance: function(vector1, vector2, idfVector) {
        // Cosine similarity returns 1 if vectors are equal, subtracting from 1 will convert it to the distance
        return 1.0 - this.calculateCosineSimilarity(vector1, vector2, idfVector);
    },

    calculateCosineSimilarity: function(vector1, vector2, idfVector) {
        //We will also use idf vector in calculations to optimize loops a little
        let dotProduct = 0.0;
        let magnitude1 = 0.0;
        let magnitude2 = 0.0;
        let zero = 0.0;
        //Vector sizes might be different
        let v1Size = vector1.length;
        let v2Size = vector2.length;
        let idfSize = idfVector.length;
        let length = Math.max(v1Size, v2Size);
        for (let i = 0; i < length; i++) {
            let v1 = i < v1Size ? vector1[i] : zero;
            let v2 = i < v2Size ? vector2[i] : zero;
            if ((idfVector != null) && i < idfSize) {
                v1 = v1 * idfVector[i];
                v2 = v2 * idfVector[i];
            }
            dotProduct += v1 * v2;
            magnitude1 += v1 * v1;
            magnitude2 += v2 * v2;
        }
        magnitude1 = Math.sqrt(magnitude1);
        magnitude2 = Math.sqrt(magnitude2);
        let magnitude = magnitude1 * magnitude2;
        if (this.doublesEqual(magnitude, zero)) {
            return 1.0;
        }
        else {
            return dotProduct / magnitude;
        }
    },

    encodeHtml: function(rawStr) {
        if (typeof rawStr !== 'string') return rawStr;
        let p = document.createElement("p");
        p.textContent = rawStr;
        return p.innerHTML;
    },

    doublesEqual: function (a, b) {
        return Math.abs(a-b) < 0.000001;
    },

})
