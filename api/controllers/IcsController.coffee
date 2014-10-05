 # IcsController
 #
 # @description :: Server-side logic for managing ics
 # @help        :: See http://links.sailsjs.org/docs/controllers

module.exports =

  list: (req, res) ->
    Task.find({ dueDate: { '!': null }, listId: req.param('listId') }).exec (error, tasks) ->
      ical = new sails.icalendar.iCalendar()
      tasks.forEach (task, index) ->
        taskEvent = ical.addComponent('VEVENT')
        taskEvent.setSummary task.title
        taskEvent.setDescription if task.remoteUrl then "#{task.remoteUrl}\n#{task.note}" else task.note
        dueDate = new Date(task.dueDate)
        dueDate.date_only = true
        taskEvent.setDate dueDate, dueDate
        taskEvent.addProperty 'URL', task.remoteUrl
      res.send(ical.toString())

  all: (req, res) ->
    Task.find({ dueDate: { '!': null } }).exec (error, tasks) ->
      ical = new sails.icalendar.iCalendar()
      tasks.forEach (task, index) ->
        taskEvent = ical.addComponent('VEVENT')
        taskEvent.setSummary task.title
        taskEvent.setDescription if task.remoteUrl then "#{task.remoteUrl}\n#{task.note}" else task.note
        dueDate = new Date(task.dueDate)
        dueDate.date_only = true
        taskEvent.setDate dueDate, dueDate
        taskEvent.addProperty 'URL', task.remoteUrl
      res.send(ical.toString())

