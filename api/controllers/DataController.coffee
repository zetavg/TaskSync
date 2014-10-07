 # DataController
 #
 # @description :: Server-side logic for managing Datas
 # @help        :: See http://links.sailsjs.org/docs/controllers

module.exports =

  index: (req, res) ->
    Data.find().exec (error, data) ->
      d = [{}].concat(data).reduce (obj, item) ->
        obj[item["key"]] = item["value"]
        return obj
      Service.find().exec (error, service) ->
        d.service = [{}].concat(service).reduce (obj, item) ->
          obj[item["id"]] = item
          return obj
        res.json(d)
