/**
 * Built-in Log Configuration
 * (sails.config.log)
 *
 * Configure the log level for your app, as well as the transport
 * (Underneath the covers, Sails uses Winston for logging, which
 * allows for some pretty neat custom transports/adapters for log messages)
 *
 * For more information on the Sails logger, check out:
 * http://sailsjs.org/#/documentation/concepts/Logging
 */

 /***************************************************************************
 *                                                                          *
 * Valid `level` configs: i.e. the minimum log level to capture with        *
 * sails.log.*()                                                            *
 *                                                                          *
 * The order of precedence for log levels from lowest to highest is:        *
 * silly, verbose, info, debug, warn, error                                 *
 *                                                                          *
 * You may also set the level to "silent" to suppress all logs.             *
 *                                                                          *
 ***************************************************************************/

require('dotenv').load();

if (process.env.LOG_FILE_PATH) {
  var winston = require('winston');

  var fileLogger = new winston.Logger({
    transports: [
      new(winston.transports.File)({
        level: (process.env.LOG_LEVEL || 'warn'),
        filename: process.env.LOG_FILE_PATH
      }),
      new(winston.transports.Console)({
        level: (process.env.LOG_LEVEL || 'warn'),
        prettyPrint: true,
        colorize: true,
        silent: false,
        timestamp: false
      }),
    ],
  });

  module.exports.log = {
    colors: false,
    custom: fileLogger
  };
} else {
  module.exports.log = {
    level: (process.env.LOG_LEVEL || 'warn')
  };
}
