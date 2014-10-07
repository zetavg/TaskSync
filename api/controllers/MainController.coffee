 # MainController
 #
 # @description :: Server-side logic for managing mains
 # @help        :: See http://links.sailsjs.org/docs/controllers

module.exports =

  index: (req, res) ->
    if !process.env.WL_USERNAME || !process.env.WL_PASSWORD || !process.env.USERNAME || !process.env.ENCRYPTED_PASSWORD || !process.env.APP_KEY
      return res.redirect '/setup'
    else if !!req.session.authenticated
      return res.view 'main/controlPanel',
        current_user_name: req.session.current_user_name
        urlKey: process.env.APP_KEY
    else
      return res.view()

  login: (req, res) ->
    crypto = require('crypto')
    username = req.param('username')
    password = req.param('password')
    if !!username && !!password && username.toLowerCase() == process.env.USERNAME.toLowerCase() && crypto.createHash('md5').update(password).digest('hex') == process.env.ENCRYPTED_PASSWORD
      req.session.authenticated = process.env.USERNAME
      req.session.current_user_name = process.env.USERNAME
    else
      req.flash('alert', 'Bad username or password.')
    return res.redirect '/'

  logout: (req, res) ->
    req.session.authenticated = null
    req.session.current_user_name = null
    return res.redirect '/'

  setup: (req, res) ->
    return res.view()
