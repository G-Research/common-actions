/******/ (() => { // webpackBootstrap
/******/ 	"use strict";
/******/ 	/* webpack/runtime/compat */
/******/ 	
/******/ 	if (typeof __nccwpck_require__ !== 'undefined') __nccwpck_require__.ab = __dirname + "/";
/******/ 	
/************************************************************************/
var __webpack_exports__ = {};

function processJob(jobName, jobData) {
    const status = jobData.result;
    console.log(`Processing job: ${jobName} with status: ${status}`);
    if (status === "success") {
        console.log(`Job ${jobName} succeeded.`);
        return 0;
    }
    else if (status === "failure" || status === "cancelled") {
        console.log(`Job ${jobName} failed: status ${status}!`);
        return 1;
    }
    else {
        console.log(`Job ${jobName} has unknown status: ${status}!`);
        return 1;
    }
}
function main() {
    const resultsJson = process.env["INPUT_NEEDS-CONTEXT"];
    if (!resultsJson) {
        throw Error("No needs-context was provided");
    }
    ;
    let results;
    try {
        results = JSON.parse(resultsJson);
    }
    catch (error) {
        throw (Error(`Error: Unable to parse needs-context as JSON: ${error}`));
    }
    let exitStatus = 0;
    for (const [jobName, jobData] of Object.entries(results)) {
        if (typeof jobData !== 'object' || jobData === null) {
            throw (Error(`Unexpected shape at key ${jobName}, expected an object`));
        }
        exitStatus += processJob(jobName, jobData);
    }
    if (exitStatus > 0) {
        throw (Error("Some jobs failed!"));
    }
    return 0;
}
main();

module.exports = __webpack_exports__;
/******/ })()
;