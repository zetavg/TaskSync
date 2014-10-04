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
      primaryKey: true,
      required: true,
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

    lastUpdatedAt: {
      type: 'datetime'
    },

    starred: {
      type: 'boolean',
      defaultsTo: false
    },

    assignedToMe: {
      type: 'boolean',
      defaultsTo: false
    }
  }
};
