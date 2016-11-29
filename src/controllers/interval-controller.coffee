_     = require 'lodash'
debug = require('debug')('interval-service:interval-controller')

class IntervalController
  constructor: ({@intervalService}) ->
    throw new Error 'IntervalController: requries intervalService' unless @intervalService?

  create: (request, response) =>
    { nodeId } = request.params
    debug 'creating', { nodeId }
    data = _.extend { nodeId }, request.meshbluAuth
    @intervalService.create data, (error, device) =>
      debug 'created', { nodeId, error }
      return response.sendError(error) if error?
      response.status(200).send device

  destroy: (request, response) =>
    { intervalUuid, nodeId } = request.params
    debug 'destroying', { nodeId, intervalUuid }
    data = _.extend { intervalUuid, nodeId }, request.meshbluAuth
    @intervalService.destroy data, (error) =>
      debug 'destroyed', { nodeId, intervalUuid, error }
      return response.sendError(error) if error?
      response.sendStatus 200

module.exports = IntervalController
