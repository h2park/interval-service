_ = require 'lodash'

class IntervalController
  constructor: ({@intervalService}) ->

  create: (req, res) =>
    params =
      nodeId: req.params.nodeId

    data = _.extend params, req.meshbluAuth
    @intervalService.create data, (error, device) =>
      return res.sendError(error) if error?
      res.send device

  destroy: (req, res) =>
    params =
      id: req.params.id
      nodeId: req.params.nodeId

    data = _.extend params, req.meshbluAuth
    @intervalService.destroy data, (error) =>
      return res.sendError(error) if error?
      res.sendStatus 200

module.exports = IntervalController
