/**
 * Bootstrap
 * (sails.config.bootstrap)
 *
 * An asynchronous bootstrap function that runs before your Sails app gets lifted.
 * This gives you an opportunity to set up your data model, run jobs, or perform some special logic.
 *
 * For more information on bootstrapping your app, check out:
 * http://sailsjs.org/#/documentation/reference/sails.config/sails.config.bootstrap.html
 */

module.exports.bootstrap = function(cb) {

  sails.dotenv = require('dotenv');
  sails.dotenv.load();
  sails.logExtInfo = process.env.LOG_EXT_INFO

  sails.Trello = require('node-trello');

  sails.icalendar = require('icalendar');


  sails.wl = require('../lib/Wunderlist2Api.js'), username = process.env.WL_USERNAME, password = process.env.WL_PASSWORD, loginData = '{ "email": "'+username+'", "password": "'+password+'" }'

  // It's very important to trigger this callback method when you are finished
  // with the bootstrap!  (otherwise your server will never lift, since it's waiting on the bootstrap)
  cb();
};
