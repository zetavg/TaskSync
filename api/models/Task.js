/**
* Task.js
*
* @description :: TODO: You might write a short summary of how this model works and what it represents here.
* @docs        :: http://sailsjs.org/#!documentation/models
*/

module.exports = {

  attributes: {

    listId: {
      model: 'list',
      required: true
    },

    taskId: {
      type: 'string',
      unique: true
    },

    title: {
      type: 'string'
    },

    completedAt: {
      type: 'datetime'
    },

    deletedAt: {
      type: 'datetime'
    },

    dueDate: {
      type: 'date'
    },

    note: {
      type: 'text'
    },

    starred: {
      type: 'boolean',
      defaultsTo: false
    },

    assignedToMe: {
      type: 'boolean',
      defaultsTo: false
    },

    remoteTaskId: {
      type: 'string',
      defaultsTo: '_null_',
      required: true
    },

    lastUpdatedAt: {
      type: 'datetime',
      defaultsTo: (new Date(0)),
      required: true
    },

    remoteUpdatedAt: {
      type: 'datetime',
      defaultsTo: (new Date(0)),
      required: true
    },

    wlUpdatedAt: {
      type: 'datetime',
      defaultsTo: (new Date(0)),
      required: true
    },
  }
};
