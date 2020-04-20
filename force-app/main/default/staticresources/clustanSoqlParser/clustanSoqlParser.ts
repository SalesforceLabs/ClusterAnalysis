import { parseQuery, Query, isQueryValid } from 'soql-parser-js'; // TS / ES6 imports
// var soqlParserJs = require('soql-parser-js'); // node's require format - usage: soqlParserJs.parseQuery()
export class clustanSoqlParser {
	public parseSoqlQuery(soqlQuery:string) : Query {
		return parseQuery(soqlQuery);
	}

	public isSoqlValid(soqlQuery:string) : boolean {
		return isQueryValid(soqlQuery);
	}

}
(<any>window).clustanSoqlParser = new clustanSoqlParser();
