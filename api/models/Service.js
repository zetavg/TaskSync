/**
* Service.js
*
* @description :: TODO: You might write a short summary of how this model works and what it represents here.
* @docs        :: http://sailsjs.org/#!documentation/models
*/

module.exports = {

  attributes: {

    type: {
      type: 'string',
      required: true
    },

    title: {
      type: 'string',
      required: true
    },

    apiKey: {
      type: 'string',
      required: true
    },

    syncLists: {
      collection: 'list',
      via: 'syncService'
    }
  }
};

