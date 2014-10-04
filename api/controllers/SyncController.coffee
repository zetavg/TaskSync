 # SyncController
 #
 # @description :: Server-side logic for managing syncs
 # @help        :: See http://links.sailsjs.org/docs/controllers

module.exports =

  sync: (req, res) ->
    sails.log.info 'Start syncing ...'
    sails.wl.login loginData, (error, login) ->
      if login
        sails.controllers.sync._getLists req, res, (req, res) ->
          sails.controllers.sync._getTasks req, res, (req, res) ->
            res.send('done')
      else
        sails.log.error error
        res.send(error)


  # Sync saved lists with Wunderlist
  _getLists: (req, res, cb=->) ->
    sails.log.info 'Start getting lists from Wunderlist'

    # Get lists
    l = sails.wl.getMeLists (error, lists) ->
      if error
        sails.log.error error
        res.send(error)
      else

        # Prepare lists data
        listIds = []
        savelistActions = []
        lists.forEach (list, index) ->
          sails.log.info 'processing list data for: ' + list.id + ' (' + list.title + ')' if sails.logExtInfo
          listIds.push list.id
          savelistActions.push (callback) ->
            List.findOrCreate({listId: list.id}, {listId: list.id}).exec (error, record) ->
              callback error, null if error
              record.title = list.title
              record.save (error, data) ->
                if error
                  sails.log.error error
                  callback error, null
                else
                  sails.log.info 'list data saved:' + JSON.stringify(record) if sails.logExtInfo
                  callback null, data

        # Save the lists in parallel
        async.series savelistActions, (err, results) ->

          # Delete lists that doesn't appear in list
          List.destroy(listId: '!': listIds ).exec ->

            sails.log.info 'cleaning lists...' if sails.logExtInfo
            cb(req, res)


  # Get updated tasks from Wunderlist
  _getTasks: (req, res, cb=->) ->
    sails.log.info 'Start getting updated tasks from Wunderlist'
    ts = sails.wl.getMeTasks (error, wlTasks) ->
      if error
        sails.log.error error
        res.status(500).send( { error: 'something blew up' } )
        return
      else

        # Prepare task data
        taskIds = []
        taskActions = []
        wlTasks.forEach (wlTask, index) ->
          sails.log.info 'preparing task: ' + wlTask.id + ' (' + wlTask.title + ' in ' + wlTask.list_id + ')' if sails.logExtInfo
          taskIds.push wlTask.id
          taskActions.push (callback) ->
            sails.log.info 'dealing with task: ' + wlTask.id + ' (' + wlTask.title + ' in ' + wlTask.list_id + ')' if sails.logExtInfo
            Task.findOrCreate( {taskId: wlTask.id, listId: wlTask.list_id}, {taskId: wlTask.id, listId: wlTask.list_id} ).exec (error, record) ->
              callback error, null if error
              if (new Date(record.updatedAt)) < (new Date(wlTask.updated_at)) || (new Date(record.createdAt) > (new Date(new Date().setTime(new Date().getTime()-10000))))
                record.title = wlTask.title
                record.completedAt = if wlTask.completed_at then new Date(wlTask.completed_at) else null
                # record.deletedAt =
                record.dueDate = wlTask.due_date
                record.note = wlTask.note
                record.starred = wlTask.starred
                # record.assignedToMe =
                record.save (error, data) ->
                  if error
                    sails.log.error error
                    callback error, null
                  else
                    sails.log.info 'task saved: ' + JSON.stringify(record) if sails.logExtInfo
                    callback null, record
              else
                callback null, record

        # Deal with each task in parallel
        async.series taskActions, (error, results) ->
          # Mark task that doesn't appear in list as deleted
          Task.update( {taskId: '!': taskIds}, {deletedAt: new Date()} ).exec (error, updated) ->
            sails.log.info 'tasks that dosen\'t appear, mark as deleted: ' + JSON.stringify(updated) if sails.logExtInfo
            cb(req, res)
