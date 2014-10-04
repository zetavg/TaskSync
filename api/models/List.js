/**
* List.js
*
* @description :: TODO: You might write a short summary of how this model works and what it represents here.
* @docs        :: http://sailsjs.org/#!documentation/models
*/

module.exports = {

  attributes: {

    listId: {
      type: 'string',
      primaryKey: true,
      required: true,
      unique: true
    },

    title: {
      type: 'string'
    },

    tasks: {
      collection: 'task',
      via: 'listId'
    },

    syncService: {
      model: 'service'
    },

    syncOptions: {
      type: 'string'
    },

    lastSyncService: {
      model: 'service'
    },

    lastSyncOptions: {
      type: 'string'
    }
  },

  afterDestroy : function (list, cb) {
    // Remove remoteTaskId for tasks
    Task.destroy({listId: list.listId}).exec(function(error, lists) {
      if (error) return cb(error);
      sails.log.info("List deleated: " + list.listId + " (" + list.title + ")" + JSON.stringify(lists))
      cb();
    });
  },

  afterUpdate: function (list, cb) {

    if (list.lastSyncService != list.syncService || list.lastSyncOptions != list.syncOptions) {
      // Remove remoteTaskId for tasks
      Task.update({listId: list.listId}, {remoteTaskId: '_null_'}).exec(function(error, lists) {
        if (error) return cb(error);
        sails.log.info("List remote disconnected/changed: " + list.listId + " (" + list.title + ") " + JSON.stringify(lists))
        List.findOne({listId: list.listId}).exec(function(error, list) {
          if (error) return cb(error);
          list.lastSyncService = list.syncService;
          list.lastSyncOptions = list.syncOptions;
          list.save(function(error, data) {
            if (error) return cb(error);
            cb();
          });
        });
      });
    } else {
      cb();
    }
  },

};
