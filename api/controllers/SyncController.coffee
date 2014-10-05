 # SyncController
 #
 # @description :: Server-side logic for managing syncs
 # @help        :: See http://links.sailsjs.org/docs/controllers

module.exports =

  sync: (req, res) ->
    syncLog = { remoteSyncs: {}, startTime: new Date(), errors: [] }
    sails.log.info 'Start syncing ...'
    sails.wl.login loginData, (error, login) ->
      if login
        getData ->
          serviceSync ->
            writeBack ->
              Task.destroy({deletedAt: {'!': null} }).exec (error, data) ->
                syncLog.endTime = new Date()
                syncLog.time = syncLog.endTime - syncLog.startTime
                if syncLog.errors.length < 1
                  syncLog.status = 'done'
                  sails.log.info "sync done in #{syncLog.time/1000} seconds"
                else
                  syncLog.status = 'error'
                  sails.log.warn "sync done with error(s) in #{syncLog.time/1000} seconds: #{JSON.stringify(syncLog)}"
                sails.log.info 'Sync done.'
                res.send(syncLog)
      else
        sails.log.error error
        syncLog.status = 'error'
        syncLog.error = error
        res.status(500).send(syncLog)


    # Get data from Wunderlist
    getData = (cb=->) ->
      sails.log.info 'Start getting data from Wunderlist'
      async.parallel
        getLists: (glCallback) ->
          getLists glCallback
        getTasks: (gtCallback) ->
          getTasks gtCallback
      , (error, results) ->
        if error
          sails.log.error error
          syncLog.status = 'error'
          res.status(500).send(syncLog)
          return
        else
          cb(req, res)


    # Get lists from Wunderlist
    getLists = (cb) ->
      cb = cb || ->
      sails.log.info 'Start getting lists from Wunderlist'

      # Get lists
      l = sails.wl.getMeLists (error, lists) ->
        if error
          sails.log.error error
          syncLog.status = 'error'
          syncLog.error = error
          res.status(500).send(syncLog)
        else

          # Prepare lists data
          listIds = []
          savelistActions = []
          lists.forEach (list, index) ->
            sails.log.info "processing list data for: #{list.id} (#{list.title})" if sails.logExtInfo
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
                    sails.log.info "list data saved: #{JSON.stringify(record)}" if sails.logExtInfo
                    callback null, data

          # Save the lists in parallel
          async.parallel savelistActions, (err, results) ->

            # Delete lists that doesn't appear in list
            List.destroy( listId: {'!': listIds} ).exec ->

              sails.log.info 'cleaning lists...' if sails.logExtInfo
              cb(null, true)


    # Get tasks from Wunderlist
    getTasks = (cb) ->
      cb = cb || ->
      sails.log.info 'Start getting updated tasks from Wunderlist'
      ts = sails.wl.getMeTasks (error, wlTasks) ->
        if error
          sails.log.error error
          syncLog.status = 'error'
          res.status(500).send(syncLog)
          return
        else

          # Prepare task data
          taskIds = []
          taskActions = []
          wlTasks.forEach (wlTask, index) ->
            sails.log.info "preparing task: #{wlTask.id} (#{wlTask.title} in #{wlTask.list_id})" if sails.logExtInfo
            taskIds.push wlTask.id
            taskActions.push (callback) ->
              sails.log.info "dealing with task: #{wlTask.id} (#{wlTask.title} in #{wlTask.list_id})" if sails.logExtInfo
              Task.findOrCreate( {taskId: wlTask.id}, {taskId: wlTask.id, listId: wlTask.list_id} ).exec (error, record) ->
                callback error, null if error
                # if (remote updateds after local update && remote updateds after local updates remote) or new record
                if ((new Date(record.lastUpdatedAt)) < (new Date(wlTask.updated_at)) && (new Date(wlTask.updated_at)) > (new Date(record.wlUpdatedAt))) || Date.parse(record.lastUpdatedAt) == 0
                  record.lastUpdatedAt = (new Date(wlTask.updated_at))
                  record.title = wlTask.title
                  record.completedAt = if wlTask.completed_at then new Date(wlTask.completed_at) else null
                  # record.deletedAt =
                  record.dueDate = wlTask.due_date
                  record.note = (if wlTask.note then wlTask.note.replace(/http.*\/\/#URL\n/, '') else null)
                  record.starred = wlTask.starred
                  # record.assignedToMe =
                  record.save (error, data) ->
                    if error
                      sails.log.error error
                      callback error, null
                    else
                      sails.log.info "task saved: #{JSON.stringify(record)}" if sails.logExtInfo
                      callback null, record
                else
                  callback null, record

          # Deal with each task in parallel
          async.parallel taskActions, (error, results) ->
            # Mark task that doesn't appear in list as deleted
            Task.update( {taskId: {'!': taskIds}, deletedAt: null}, {deletedAt: new Date()} ).exec (error, updated) ->
              sails.log.info "tasks that dosen't appear, mark as deleted: #{JSON.stringify(updated)}" if sails.logExtInfo
              cb(null, true)


    # Write tasks data back to Wunderlist
    writeBack = (cb=->) ->
      sails.log.info 'Witing tasks back to Wunderlist'
      ts = sails.wl.getMeTasks (error, wlTasks) ->
        if error
          sails.log.error error
          syncLog.status = 'error'
          res.status(500).send(syncLog)
          return
        else
          wlTasks = wlTasks.reduce ((o, v, k) ->
            o[v.id] = v
            return o
          ), {}

          # each task update or create or del
          # Task.find(deletedAt: null).exec (error, tasks) ->
          Task.find().exec (error, tasks) ->
            if error
              sails.log.error error
              syncLog.status = 'error'
              res.status(500).send(syncLog)
              return
            else
              # Prepare action for each task
              taskWbActions = []
              tasks.forEach (task, index) ->
                # Write back only synced tasks
                if task.remoteTaskId != '_null_'
                  # if Task is marked as deleted
                  if task.deletedAt
                    sails.log.info "preparing task for delete: #{task.taskId} (#{task.title}, deleted at: #{task.deletedAt})" if sails.logExtInfo
                    taskWbActions.push (callback) ->
                      if (!!wlTasks[task.taskId])
                        sails.wl.deleteMeTask task.taskId, (error, deleted) ->
                          if error
                            sails.log.error error
                            callback error, null
                          else
                            sails.log.info "deleted: #{task.taskId} (#{task.title}, deleted at: #{task.deletedAt}) #{JSON.stringify(deleted)}" if sails.logExtInfo
                            callback null, true
                      else
                        callback null, true
                  # else
                  else
                    sails.log.info "preparing task for writeback: #{task.taskId} (#{task.title})" if sails.logExtInfo
                    taskWbActions.push (callback) ->
                      if !task.taskId  # new task, create it
                        cl = sails.wl.createMeTask
                          list_id: task.listId
                          title: if task.title then task.title else '(blank)'
                          completed_at: if task.completedAt then new Date(task.completedAt) else null
                          due_date: task.dueDate
                          note: (if task.remoteUrl then "#{task.remoteUrl} //#URL\n#{task.note}" else task.note)
                          starred: task.starred
                        , (error, newTask) ->
                          if error
                            sails.log.error error
                            callback error, null
                          else
                            task.taskId = newTask.id
                            task.wlUpdatedAt = newTask.updated_at if newTask.updated_at
                            task.save ->
                              sails.log.info "created task: #{task.taskId} (#{task.title}) #{JSON.stringify(newTask)}" if sails.logExtInfo
                              callback null, true
                      else if wlTasks[task.taskId] && (new Date(task.lastUpdatedAt)) > (new Date(wlTasks[task.taskId]['updated_at']))  # updated task, rewrite it
                        cl = sails.wl.updateMeTask task.taskId,
                          title: if task.title then task.title else '(blank)'
                          completed_at: if task.completedAt then new Date(task.completedAt) else null
                          due_date: task.dueDate
                          note: (if task.remoteUrl then "#{task.remoteUrl} //#URL\n#{if task.note then task.note else ''}" else task.note)
                          starred: task.starred
                        , (error, updated) ->
                          if error
                            sails.log.error error
                            callback error, null
                          else
                            task.wlUpdatedAt = updated.updated_at if updated.updated_at
                            task.save ->
                              sails.log.info "updated task: #{task.taskId} (#{task.title}) #{JSON.stringify(updated)}" if sails.logExtInfo
                              callback null, true
                      else  # nothing to do! yeah!
                        callback null, true

              # Do in parallel
              async.parallel taskWbActions, (error, results) ->
                if error
                  sails.log.error error
                  syncLog.status = 'error'
                  res.status(500).send(syncLog)
                  return
                else
                  cb(req, res)


    # Sync for each service
    serviceSync = (cb=->) ->
      sails.log.info 'Start sync data with services'

      # Prepare sync actions
      syncActions = []
      List.find(syncService: {'!': null}, syncOptions: {'!': null}).populate('syncService').exec (error, lists) ->
        lists.forEach (list, index) ->
          if !!list.syncService && !!list.syncOptions
            sails.log.info "preparing list for sync: #{list.listId} (#{list.title}, type: #{list.syncService.type}, opts: #{list.syncOptions})" if sails.logExtInfo
            switch list.syncService.type

              # Sync with asana
              when 'asana'
                syncLog.remoteSyncs[list.listId] = { listTitle: list.title, type: list.syncService.type, opts: list.syncOptions }
                syncActions.push (sCallback) ->
                  sails.log.info "syncing with asana: #{list.listId} (#{list.title}, opts: #{list.syncOptions})"
                  logNewTasksFromLocal = []
                  logUpdatedTasksFromLocal = []
                  logUpdatedTasksFromRemote = []
                  logDeletedTasksFromLocal = []
                  logDeletedTasksFromRemote = []
                  asana = require("#{process.env.PWD}/lib/asana")
                  asana.setApiKey(list.syncService.apiKey)
                  asana.getTasks list.syncOptions, (error, data) ->
                    if error
                      sails.log.error error
                      sCallback error, null
                    else
                      aTasks = data['data']
                      # Prepare task sync
                      aTaskActions = []
                      aTaskIds = []
                      aTasks.forEach (aTask, index) ->
                        sails.log.info "preparing asana task for sync: #{aTask.id} (#{aTask.name})" if sails.logExtInfo
                        aTaskIds.push aTask.id
                        aTaskActions.push (ataCallback) ->
                          asana.getTask aTask.id, null, (error, data) ->
                            if error
                              sails.log.error error
                              ataCallback error, null
                            else
                              aTask = data['data']
                              Task.findOrCreate( {remoteTaskId: aTask.id, listId: list.listId}, {remoteTaskId: aTask.id, listId: list.listId} ).exec (error, record) ->
                                # delete if local task marked as deleted (has deletedAt) and deleted after remote updated
                                if record.deletedAt && (new Date(record.deletedAt)) > (new Date(aTask.modified_at))
                                  asana.deleteTask aTask.id, (error, data) ->
                                    if error
                                      sails.log.error error
                                      ataCallback error, null
                                    else
                                      logDeletedTasksFromLocal.push record
                                      sails.log.info "remote task deleted: #{record.taskId} (#{record.title}) #{JSON.stringify(data)}" if sails.logExtInfo
                                      ataCallback null, data
                                # update local if (remote updateds after local update && remote updateds after local updates remote) or new record
                                else if ((new Date(record.lastUpdatedAt)) < (new Date(aTask.modified_at)) && (new Date(aTask.modified_at)) > (new Date(record.remoteUpdatedAt))) || Date.parse(record.lastUpdatedAt) == 0
                                  record.lastUpdatedAt = (new Date(aTask.modified_at))
                                  record.title = aTask.name
                                  record.completedAt = if aTask.completed_at then new Date(aTask.completed_at) else null
                                  # record.deletedAt =
                                  record.dueDate = aTask.due_on
                                  record.note = aTask.notes
                                  record.deletedAt = null
                                  record.starred = aTask.hearted
                                  # record.assignedToMe =
                                  record.save (error, data) ->
                                    if error
                                      sails.log.error error
                                      ataCallback error, null
                                    else
                                      logUpdatedTasksFromRemote.push record
                                      sails.log.info "task saved: #{JSON.stringify(record)}" if sails.logExtInfo
                                      ataCallback null, true
                                # else
                                else
                                  # check if remote needs update
                                  if (new Date(record.lastUpdatedAt)) > (new Date(aTask.modified_at))
                                    asana.updateTask aTask.id,
                                      title: (if record.title then record.title else '(blank)')
                                      completed: (if record.completedAt then true else false)
                                      due_on: record.dueDate
                                      notes: record.note
                                      hearted: record.starred
                                    , (error, updated) ->
                                      if error
                                        sails.log.error error
                                        ataCallback error, null
                                      else
                                        record.remoteUpdatedAt = updated.data.modified_at if updated.data?.modified_at
                                        record.save ->
                                          logUpdatedTasksFromLocal.push record
                                          sails.log.info "remote task updated: #{record.taskId} (#{record.title}) #{JSON.stringify(updated)}" if sails.logExtInfo
                                          ataCallback null, true
                                  # nothing to do
                                  else
                                    if !!record.deletedAt
                                      record.deletedAt = null
                                      record.save (error, data) ->
                                        ataCallback null, true
                                    else
                                      ataCallback null, true
                      # Do task sync in parallel
                      async.parallel aTaskActions, (error, results) ->
                        if error
                          sails.log.error error
                          syncLog.status = 'error'
                          res.status(500).send(syncLog)
                          return
                        else
                          # mark task that has a remote id but doesn't appear in list as deleted
                          aTaskIds.push '_null_'
                          Task.update( {listId: list.listId, remoteTaskId: {'!': aTaskIds}}, {deletedAt: new Date()} ).exec (error, updated) ->
                            logDeletedTasksFromRemote.concat updated
                            sails.log.info "tasks that dosen't appear in remote anymore, mark as deleted: #{JSON.stringify(updated)}" if sails.logExtInfo
                            # pick and create tasks that does not have an remote id
                            Task.find({listId: list.listId, remoteTaskId: '_null_'}).exec (error, newTasks) ->
                              if error
                                sails.log.error error
                                syncLog.status = 'error'
                                res.status(500).send(syncLog)
                                return
                              else if newTasks.length > 0
                                # prepare creation
                                asana.getUserMe {}, (error, me) ->
                                  if error || !me.data
                                    sails.log.error error
                                    syncLog.status = 'error'
                                    res.status(500).send(syncLog)
                                    return
                                  wsMatch = list.syncOptions.match(/workspace=[^&]+/)
                                  wsId = if wsMatch then wsMatch[0].replace(/workspace=/, "") else null
                                  pMatch = list.syncOptions.match(/project=[^&]+/)
                                  pId = if pMatch then pMatch[0].replace(/project=/, "") else null
                                  assigned = list.syncOptions.match(/assignee=[^&]+/)
                                  assignee = if assigned then me.data.id else null
                                  aCreateTaskActions = []
                                  newTasks.forEach (newTask, index) ->
                                    sails.log.info "preparing task for remote creation: #{newTask.id} (#{newTask.name})" if sails.logExtInfo
                                    aCreateTaskActions.push (ctCallback) ->
                                      asana.createTask
                                        assignee: assignee
                                        workspace: wsId
                                        projects: (if pId then [pId] else [])
                                        name: (if newTask.title then newTask.title else '(blank)')
                                        completed: (if newTask.completedAt then true else false)
                                        due_on: newTask.dueDate
                                        notes: (if newTask.note then newTask.note else '')
                                        hearted: newTask.starred
                                      , (error, updated) ->
                                        if error || !updated.data
                                          sails.log.error error, updated
                                          ctCallback error, updated
                                        else
                                          newTask.remoteUpdatedAt = updated.data.modified_at if updated.data?.modified_at
                                          newTask.remoteTaskId = updated.data.id
                                          newTask.save (error, data) ->
                                            if error
                                              sails.log.error error
                                              ctCallback error, null
                                              return
                                            logNewTasksFromLocal.push data
                                            sails.log.info "remote task created: #{newTask.taskId} (#{newTask.title}) #{JSON.stringify(updated)}" if sails.logExtInfo
                                            ctCallback null, updated

                                  # create in parallel
                                  async.parallel aCreateTaskActions, (error, results) ->
                                    if error
                                      sails.log.error error
                                      syncLog.status = 'error'
                                      res.status(500).send(syncLog)
                                      return
                                    else
                                      syncLog.remoteSyncs[list.listId].statistics =
                                        newTasksFromLocal: logNewTasksFromLocal.length
                                        updatedTasksFromLocal: logUpdatedTasksFromLocal.length
                                        updatedTasksFromRemote: logUpdatedTasksFromRemote.length
                                        deletedTasksFromLocal: logDeletedTasksFromLocal.length
                                        deletedTasksFromRemote: logDeletedTasksFromRemote.length
                                      syncLog.remoteSyncs[list.listId].details =
                                        newTasksFromLocal: logNewTasksFromLocal
                                        updatedTasksFromLocal: logUpdatedTasksFromLocal
                                        updatedTasksFromRemote: logUpdatedTasksFromRemote
                                        deletedTasksFromLocal: logDeletedTasksFromLocal
                                        deletedTasksFromRemote: logDeletedTasksFromRemote
                                      sails.log.info "done sync with asana: #{list.listId} (#{list.title}, opts: #{list.syncOptions}, nl: #{logNewTasksFromLocal.length}, ul: #{logUpdatedTasksFromLocal.length}, ur: #{logUpdatedTasksFromRemote.length}, dl: #{logDeletedTasksFromLocal.length}, dr: #{logDeletedTasksFromRemote.length})"
                                      sCallback null, true

                              # no new tasks to create on remote
                              else
                                syncLog.remoteSyncs[list.listId].statistics =
                                  newTasksFromLocal: logNewTasksFromLocal.length
                                  updatedTasksFromLocal: logUpdatedTasksFromLocal.length
                                  updatedTasksFromRemote: logUpdatedTasksFromRemote.length
                                  deletedTasksFromLocal: logDeletedTasksFromLocal.length
                                  deletedTasksFromRemote: logDeletedTasksFromRemote.length
                                syncLog.remoteSyncs[list.listId].details =
                                  newTasksFromLocal: logNewTasksFromLocal
                                  updatedTasksFromLocal: logUpdatedTasksFromLocal
                                  updatedTasksFromRemote: logUpdatedTasksFromRemote
                                  deletedTasksFromLocal: logDeletedTasksFromLocal
                                  deletedTasksFromRemote: logDeletedTasksFromRemote
                                sails.log.info "done sync with asana: #{list.listId} (#{list.title}, opts: #{list.syncOptions}, nl: #{logNewTasksFromLocal.length}, ul: #{logUpdatedTasksFromLocal.length}, ur: #{logUpdatedTasksFromRemote.length}, dl: #{logDeletedTasksFromLocal.length}, dr: #{logDeletedTasksFromRemote.length})"
                                sCallback null, true


              # Sync with Trello
              when 'trello'
                syncLog.remoteSyncs[list.listId] = { listTitle: list.title, type: list.syncService.type, opts: list.syncOptions }

                # 判斷同步類型
                boardMatch = list.syncOptions.match(/board=[^&]+/)
                listMatch = list.syncOptions.match(/list=[^&]+/)
                if boardMatch
                  syncType = 'board'
                  boardId = boardMatch[0].replace(/board=/, "")
                  getListUrl = "/1/boards/#{boardId}/lists"
                  getCardsUrl = "/1/boards/#{boardId}/cards"
                else if listMatch
                  syncType = 'list'
                  listId = listMatch[0].replace(/list=/, "")
                  getListUrl = "/1/lists/#{listId}"
                  getCardsUrl = "/1/lists/#{listId}/cards"
                else
                  syncType = null
                  syncLog.remoteSyncs[list.listId].error = error
                  syncLog.errors.push "bad sync options for #{list.listId} (#{list.title}): #{list.syncOptions}"
                  sCallback null, true
                  return

                if syncType  # 開始同步

                  syncActions.push (sCallback) ->
                    sails.log.info "syncing with trello: #{list.listId} (#{list.title}, opts: #{list.syncOptions})"
                    logNewTasksFromLocal = []
                    logUpdatedTasksFromLocal = []
                    logUpdatedTasksFromRemote = []
                    logDeletedTasksFromLocal = []
                    logDeletedTasksFromRemote = []
                    trello = new sails.Trello(list.syncService.apiKey, list.syncService.apiSecret)
                    trello.get getListUrl, (error, tList) ->
                      if error
                        syncLog.remoteSyncs[list.listId].error = error
                        syncLog.errors.push "can't get list from trello of #{list.listId} (#{list.title}): no lists in board? or wrong API key, token or board ID?"
                        sCallback null, true
                        return
                      else
                        tList = tList[0] if syncType == 'board'
                        if !tList
                          syncLog.remoteSyncs[list.listId].error = tList
                          syncLog.errors.push "can't get list from trello of #{list.listId} (#{list.title}): no lists in board? or wrong API key, token or board ID?"
                          sCallback null, true
                          return

                        trello.get getCardsUrl, (error, cards) ->
                          if error
                            syncLog.remoteSyncs[list.listId].error = error
                            syncLog.errors.push "can't get cards from trello #{list.listId} (#{list.title}): wrong API key, token or board ID?"
                            sCallback null, true
                            return
                          else
                            # 已取得卡片資料，準備平行處理每張卡片的同步
                            cardActions = []
                            cardIds = []
                            cards.forEach (card, index) ->
                              sails.log.info "preparing trello card for sync: #{card.id} (#{card.name})" if sails.logExtInfo
                              cardIds.push card.id
                              cardActions.push (tcaCallback) ->
                                Task.findOrCreate( {remoteTaskId: card.id, listId: list.listId}, {remoteTaskId: card.id, listId: list.listId} ).exec (error, record) ->
                                  # delete if local task marked as deleted (has deletedAt) and deleted after remote updated
                                  if record.deletedAt && (new Date(record.deletedAt)) > (new Date(card.dateLastActivity))
                                    trello.del "/1/cards/#{record.remoteTaskId}", (error, data) ->
                                      if error
                                        syncLog.errors.push "can't update trello, check token permissions?"
                                        sails.log.error error
                                        tcaCallback error, null
                                      else
                                        logDeletedTasksFromLocal.push record
                                        sails.log.info "remote task deleted: #{record.taskId} (#{record.title}) #{JSON.stringify(data)}" if sails.logExtInfo
                                        tcaCallback null, data
                                  # update local if (remote updateds after local update && remote updateds after local updates remote) or new record
                                  else if ((new Date(record.lastUpdatedAt)) < (new Date(card.dateLastActivity)) && (new Date(card.dateLastActivity)) > (new Date(record.remoteUpdatedAt))) || Date.parse(record.lastUpdatedAt) == 0
                                    record.lastUpdatedAt = (new Date(card.dateLastActivity))
                                    record.remoteUrl = card.url
                                    record.title = card.name
                                    record.completedAt = (if card.closed then new Date() else null)
                                    # record.deletedAt =
                                    record.dueDate = (if card.due then card.due.replace(/T.*$/, '') else null)
                                    record.note = card.desc
                                    record.deletedAt = null
                                    record.starred = card.subscribed
                                    # record.assignedToMe =
                                    record.save (error, data) ->
                                      if error
                                        sails.log.error error
                                        tcaCallback error, null
                                      else
                                        logUpdatedTasksFromRemote.push record
                                        sails.log.info "task saved: #{JSON.stringify(record)}" if sails.logExtInfo
                                        tcaCallback null, true
                                  # else
                                  else
                                    # check if remote needs update
                                    if (new Date(record.lastUpdatedAt)) > (new Date(card.dateLastActivity))
                                      query =
                                        name: record.title
                                        desc: record.note
                                        due: (if record.dueDate then (new Date(record.dueDate)) else '')
                                        closed: (if record.completedAt then true else false)
                                        subscribed: record.starred
                                      trello.put "/1/cards/#{record.remoteTaskId}", query, (error, updated) ->
                                        if error
                                          syncLog.errors.push "can't update trello card #{record.remoteTaskId}, check token permissions?"
                                          sails.log.error error
                                          tcaCallback error, null
                                        else
                                          record.remoteUpdatedAt = updated.data.modified_at if updated.data?.modified_at
                                          record.save ->
                                            logUpdatedTasksFromLocal.push record
                                            sails.log.info "remote task updated: #{record.taskId} (#{record.title}) #{JSON.stringify(updated)}" if sails.logExtInfo
                                            tcaCallback null, true
                                    # nothing to do
                                    else
                                      if !!record.deletedAt
                                        record.deletedAt = null
                                        record.save (error, data) ->
                                          tcaCallback null, true
                                      else
                                        tcaCallback null, true
                            # Do task sync in parallel
                            async.parallel cardActions, (error, results) ->
                              if error
                                sails.log.error error
                                syncLog.status = 'error'
                                res.status(500).send(syncLog)
                                return
                              else
                                # mark task that has a remote id but doesn't appear in list as deleted
                                cardIds.push '_null_'
                                Task.update( {listId: list.listId, remoteTaskId: {'!': cardIds}}, {deletedAt: new Date()} ).exec (error, updated) ->
                                  logDeletedTasksFromRemote.concat updated
                                  sails.log.info "tasks that dosen't appear in remote anymore, mark as deleted: #{JSON.stringify(updated)}" if sails.logExtInfo
                                  # pick and create tasks that does not have an remote id
                                  Task.find({listId: list.listId, remoteTaskId: '_null_'}).exec (error, newTasks) ->
                                    if error
                                      sails.log.error error
                                      syncLog.status = 'error'
                                      res.status(500).send(syncLog)
                                      return
                                    else if newTasks.length > 0
                                      tCreateCardActions = []
                                      newTasks.forEach (newTask, index) ->
                                        sails.log.info "preparing card for remote creation: #{newTask.id} (#{newTask.name})" if sails.logExtInfo
                                        tCreateCardActions.push (ccCallback) ->

                                          query =
                                            idList: tList.id
                                            urlSource: null
                                            name: newTask.title
                                            desc: newTask.note
                                            due: (if newTask.dueDate then (new Date(newTask.dueDate)) else '')
                                            pos: 'top'
                                          trello.post "/1/cards", query, (error, updated) ->
                                            if error
                                              syncLog.errors.push "can't update trello, check token permissions?"
                                              sails.log.error error, updated
                                              ccCallback error, updated
                                            else
                                              newTask.remoteUpdatedAt = updated.dateLastActivity
                                              newTask.remoteTaskId = updated.id
                                              newTask.remoteUrl = updated.url
                                              newTask.lastUpdatedAt = new Date()
                                              newTask.save (error, data) ->
                                                if error
                                                  sails.log.error error
                                                  ccCallback error, null
                                                  return
                                                logNewTasksFromLocal.push data
                                                sails.log.info "remote task created: #{newTask.taskId} (#{newTask.title}) #{JSON.stringify(updated)}" if sails.logExtInfo
                                                ccCallback null, updated

                                      # create in parallel
                                      async.parallel tCreateCardActions, (error, results) ->
                                        if error
                                          sails.log.error error
                                          syncLog.status = 'error'
                                          res.status(500).send(syncLog)
                                          return
                                        else
                                          syncLog.remoteSyncs[list.listId].statistics =
                                            newTasksFromLocal: logNewTasksFromLocal.length
                                            updatedTasksFromLocal: logUpdatedTasksFromLocal.length
                                            updatedTasksFromRemote: logUpdatedTasksFromRemote.length
                                            deletedTasksFromLocal: logDeletedTasksFromLocal.length
                                            deletedTasksFromRemote: logDeletedTasksFromRemote.length
                                          syncLog.remoteSyncs[list.listId].details =
                                            newTasksFromLocal: logNewTasksFromLocal
                                            updatedTasksFromLocal: logUpdatedTasksFromLocal
                                            updatedTasksFromRemote: logUpdatedTasksFromRemote
                                            deletedTasksFromLocal: logDeletedTasksFromLocal
                                            deletedTasksFromRemote: logDeletedTasksFromRemote
                                          sails.log.info "done sync with Trello: #{list.listId} (#{list.title}, opts: #{list.syncOptions}, nl: #{logNewTasksFromLocal.length}, ul: #{logUpdatedTasksFromLocal.length}, ur: #{logUpdatedTasksFromRemote.length}, dl: #{logDeletedTasksFromLocal.length}, dr: #{logDeletedTasksFromRemote.length})"
                                          sCallback null, true

                                    # no new tasks to create on remote
                                    else
                                      syncLog.remoteSyncs[list.listId].statistics =
                                        newTasksFromLocal: logNewTasksFromLocal.length
                                        updatedTasksFromLocal: logUpdatedTasksFromLocal.length
                                        updatedTasksFromRemote: logUpdatedTasksFromRemote.length
                                        deletedTasksFromLocal: logDeletedTasksFromLocal.length
                                        deletedTasksFromRemote: logDeletedTasksFromRemote.length
                                      syncLog.remoteSyncs[list.listId].details =
                                        newTasksFromLocal: logNewTasksFromLocal
                                        updatedTasksFromLocal: logUpdatedTasksFromLocal
                                        updatedTasksFromRemote: logUpdatedTasksFromRemote
                                        deletedTasksFromLocal: logDeletedTasksFromLocal
                                        deletedTasksFromRemote: logDeletedTasksFromRemote
                                      sails.log.info "done sync with Trello: #{list.listId} (#{list.title}, opts: #{list.syncOptions}, nl: #{logNewTasksFromLocal.length}, ul: #{logUpdatedTasksFromLocal.length}, ur: #{logUpdatedTasksFromRemote.length}, dl: #{logDeletedTasksFromLocal.length}, dr: #{logDeletedTasksFromRemote.length})"
                                      sCallback null, true


              else
                sails.log.warn "Unknown service type '#{list.syncService.type}' for #{list.listId} (#{list.title})"

        # Sync each list in parallel
        async.parallel syncActions, (error, results) ->
          if error
            sails.log.error error
            syncLog.status = 'error'
            res.status(500).send(syncLog)
            return
          else
            cb(req, res)
