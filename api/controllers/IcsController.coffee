 # IcsController
 #
 # @description :: Server-side logic for managing ics
 # @help        :: See http://links.sailsjs.org/docs/controllers

module.exports =

  list: (req, res) ->
    Task.find({ listId: req.param('listId'), dueDate: { '!': null } }).exec (error, tasks) ->
      ical = new sails.icalendar.iCalendar()
      if tasks
        tasks.forEach (task, index) ->
          if !!task.taskId
            taskEvent = ical.addComponent('VEVENT')
            taskEvent.setSummary (if task.title then task.title else '')
            taskEvent.setDescription (if task.remoteUrl then "#{task.remoteUrl}\n#{task.note}" else (if task.note then task.note else ''))
            dueDate = new Date(task.dueDate)
            dueDate.date_only = true
            taskEvent.setDate dueDate, dueDate
            taskEvent.addProperty 'UID', task.taskId
            taskEvent.addProperty 'URL', (if task.remoteUrl then task.remoteUrl else '')
      res.send(ical.toString())

  all: (req, res) ->
    Task.find({ dueDate: { '!': null } }).exec (error, tasks) ->
      ical = new sails.icalendar.iCalendar()
      if tasks
        tasks.forEach (task, index) ->
          if !!task.taskId
            taskEvent = ical.addComponent('VEVENT')
            taskEvent.setSummary (if task.title then task.title else '')
            taskEvent.setDescription (if task.remoteUrl then "#{task.remoteUrl}\n#{task.note}" else (if task.note then task.note else ''))
            dueDate = new Date(task.dueDate)
            dueDate.date_only = true
            taskEvent.setDate dueDate, dueDate
            taskEvent.addProperty 'UID', task.taskId
            taskEvent.addProperty 'URL', (if task.remoteUrl then task.remoteUrl else '')
      res.send(ical.toString())

