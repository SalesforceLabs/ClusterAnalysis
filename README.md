# SFDC Cluster Analysis Package
- Performs [cluster analysis](https://en.wikipedia.org/wiki/Cluster_analysis) on Salesforce standard and custom objects, breaks records into groups (clusters) using K-Means and K-Medoids (CLARA) algorithms.<br/>
- Supports clustering of objects with mixed data types (numeric, category/picklist, text) using Gower distance function.<br/>
- Supports clustering of free text (LongTextArea) values using [TF-IDF](https://en.wikipedia.org/wiki/Tf%E2%80%93idf) NLP technique.<br/>
- Visualizes the clustering result using [t-SNE](https://en.wikipedia.org/wiki/T-distributed_stochastic_neighbor_embedding) dimensionality reduction technique.<br/>
- Can find similar records and predict field values for any record using [K-Nearest Neighbors](https://en.wikipedia.org/wiki/K-nearest_neighbors_algorithm) algorithm.<br/>
Click [here](../../wiki/Finding-similarities-and-making-predictions-with-TF-IDF-and-k-Nearest-Neighbors-in-Salesforce) and [here](../../wiki/Cluster-Analysis-in-Salesforce) to get more information about the methodology and algorithms used in this app.

## Installation
Install the application from [Salesforce AppExchange](https://appexchange.salesforce.com/appxListingDetail?listingId=a0N3A00000G11fzUAB)

## Dev, Build and Test

### Create a scratch org
```
sfdx force:org:create -f ./config/project-scratch-def.json -a ScratchOrgAlias --durationdays 30
sfdx force:config:set defaultusername=<user name returned from the previous command>
```

### Push the source code to the scratch org
```
sfdx force:org:push
```

### Create sample lead records
```
sfdx force:data:bulk:upsert -f force-app/main/default/staticresources/ClustanLeadsMock.csv -s Lead -i Email
```

### Run Apex tests
```
sfdx force:apex:test:run
```

### Authorise an org
```
sfdx force:auth:web:login --setalias OrgAlias
```

### Deploy to an org
The app also works if deployed to an org without a namespace. However I recommend using a managed package installation
```
sfdx force:source:deploy --checkonly --sourcepath force-app --targetusername OrgAlias --testlevel RunLocalTests
sfdx force:source:deploy --sourcepath force-app --targetusername OrgAlias --testlevel NoTestRun
```

### Create a managed package
```
sfdx force:package:create --name "Cluster Analysis" --path force-app --packagetype Managed -d "Group records from any object into clusters and visualize the result using machine learning algorithms"
```

### Create and promote a package version
```
sfdx force:package:version:create --package "Cluster Analysis" --wait 10 --installationkeybypass --codecoverage
sfdx force:package:version:promote --package "Cluster Analysis@1.0.0-1"
```


## Description of Files and Directories
* **sfdx-project.json**: Required by Salesforce DX. Configures your project.  Use this file to specify the parameters that affect your Salesforce development project.
* **config/project-scratch-def.json**: Sample file that shows how to define the shape of a scratch org.  You reference this file when you create your scratch org with the force:org:create command.   
* **force-app**: Directory that contains the source for the Cluster Analysis package and tests.
* **force-app/main/default**: Directory that contains the app source and shared classes.
* **force-app/main/algorithms**: Directory that contains algorithm classes.
* **force-app/main/api**: Directory that contains Cluster Analysis global api Apex classes.
* **force-app/main/utils**: Directory that contains utility classes.
* **force-app/main/test**: Directory that contains Apex test classes.
* **.gitignore**:  Optional Git file. Specifies intentionally untracked files that you want Git (or in this case GitHub) to ignore.

## Resources
Clustering Large Data Sets (By Leonard Kaufman, Peter J.Rousseeuw, 1986)

Clustering with optimised weights for Gower’s metric (By Jeroen van den Hoven)
https://beta.vu.nl/nl/Images/stageverslag-hoven_tcm235-777817.pdf

Clustering on mixed type data (by Thomas Filaire)
https://towardsdatascience.com/clustering-on-mixed-type-data-8bbd0a2569c3

Visualizing Data using t-SNE (by Laurens van der Maaten)
https://lvdmaaten.github.io/tsne/

tSNEJS (Copyright Andrej Karpathy)
https://github.com/karpathy/tsnejs

Javascript SOQL parser (Copyright 2019 Austin Turner)
https://github.com/paustint/soql-parser-js

JavaScript Algorithms and Data Structures (Copyright (c) 2018 Oleksii Trekhleb)
https://github.com/trekhleb/javascript-algorithms

Data-Driven Documents (D3.js, Copyright 2010-2017 Mike Bostock)
https://d3js.org/

Building Machine Learning Systems with Apex (Presented on DF14 by Jen Wyher and Paul Battisson)
https://www.slideshare.net/pbattisson/df14-building-machine-learning-systems-with-apex

Salesforce Lookup Component
https://github.com/pozil/sfdc-ui-lookup-lwc

## Issues
To report a bug or suggest an enhancement create an issue on "Issues" tab.