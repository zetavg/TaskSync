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
          sails.controllers.sync._getListTasks req, res
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
              record.save ->
                sails.log.info 'list data saved:' + JSON.stringify(record) if sails.logExtInfo
                callback null, record

        # Save the lists in parallel
        async.series savelistActions, (err, results) ->

          # Delete lists that doesn't appear in list
          List.destroy(listId: '!': listIds ).exec ->

            sails.log.info 'cleaning lists...' if sails.logExtInfo
            cb(req, res)
            res.send('Success!')
