_ = require 'lodash'

class IntervalController
  constructor: ({@intervalService}) ->
    throw new Error 'IntervalController: requries intervalService' unless @intervalService?

  create: (request, response) =>
    { nodeId } = request.params
    data = _.extend { nodeId }, request.meshbluAuth
    @intervalService.create data, (error, device) =>
      return response.sendError(error) if error?
      response.status(200).send device

  destroy: (request, response) =>
    { intervalUuid, nodeId } = request.params
    data = _.extend { intervalUuid, nodeId }, request.meshbluAuth
    @intervalService.destroy data, (error) =>
      return response.sendError(error) if error?
      response.sendStatus 200

module.exports = IntervalController
