_     = require 'lodash'
debug = require('debug')('interval-service:message-controller')

class MessageController
  constructor: ({@messageService}) ->

  _getFromUuidFromRoute: (route) =>
    hop = _.first route
    return hop.from if hop?

  _parseIfPossible: (str) =>
    return unless str
    try
      JSON.parse str

  message: (req, res) =>
    debug 'message request body', JSON.stringify req?.body

    route = @_parseIfPossible req.header 'X-MESHBLU-ROUTE'
    req?.body.fromUuid ?= @_getFromUuidFromRoute route

    switch req?.body?.topic
      when 'register-interval'   then @register req, res
      when 'register-cron'       then @register req, res
      when 'unregister-interval' then @unregister req, res
      when 'unregister-cron'     then @unregister req, res
      when 'pong'                then @pong req, res
      else res.status(501).end() if res

  pong: (req, res) =>
    payload = req.body?.payload || {}
    payload.sendTo = req.body?.fromUuid
    debug 'pong', JSON.stringify payload
    @messageService.pong payload, (err) =>
      debug err if err
      debug 'done pong'
      res.status(500).send(err.message) if res and err
      res.status(201).end() if res

  register: (req, res) =>
    debug 'register', JSON.stringify req?.body?.payload
    params = _.merge {}, req?.body?.payload, sendTo: req?.body?.fromUuid
    @messageService.subscribe params, (err) =>
      debug err if err
      debug 'done register'
      res.status(500).end() if res and err
      res.status(201).end() if res

  unregister: (req, res) =>
    debug 'unregister', JSON.stringify req?.body?.payload
    params = _.merge {}, req?.body?.payload, sendTo: req?.body?.fromUuid
    @messageService.unsubscribe params, (err) =>
      debug err if err
      res.status(500).end() if res and err
      res.status(201).end() if res

module.exports = MessageController
