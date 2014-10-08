/**
 * Load New Relic
 */

if (!!process.env.NEW_RELIC_LICENSE_KEY) global.newrelic = require('newrelic');
