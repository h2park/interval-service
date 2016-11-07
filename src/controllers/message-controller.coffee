_     = require 'lodash'
debug = require('debug')('interval-service:message-controller')

class MessageController
  constructor: ({@messageService}) ->
    @topicRoutes =
      'register-interval': @register
      'register-cron': @register
      'unregister-interval': @unregister
      'unregister-cron': @unregister
      'pong': @pong

  _getFromUuidFromRoute: (route) =>
    hop = _.first route
    return hop.from if hop?

  _parseIfPossible: (str) =>
    return unless str
    try return JSON.parse str

  message: (request, response) =>
    debug 'message request body', JSON.stringify request.body

    route = @_parseIfPossible request.header('X-MESHBLU-ROUTE')
    request.body.fromUuid ?= @_getFromUuidFromRoute route

    return response.sendStatus(501) unless @topicRoutes[request.body.topic]?
    @topicRoutes[request.body.topic] request, response

  pong: (request, response) =>
    response.sendStatus(204)

  register: (request, response) =>
    { payload, fromUuid } = request.body
    debug 'register', JSON.stringify payload
    params = _.merge {}, payload, { sendTo: fromUuid }
    @messageService.subscribe params, (error) =>
      return response.sendError(error) if error?
      response.sendStatus(201)

  unregister: (request, response) =>
    { payload, fromUuid } = request.body
    debug 'unregister', JSON.stringify payload
    params = _.merge {}, payload, { sendTo: fromUuid }
    @messageService.unsubscribe params, (error) =>
      return response.sendError(error) if error?
      response.sendStatus(204)

module.exports = MessageController
