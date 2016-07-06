class IntervalController
  constructor: ({@intervalService}) ->

  create: (req, res) =>
    @intervalService.create req.meshbluAuth, (error, device) =>
      return res.sendError(error) if error?
      res.send device

  destroy: (req, res) =>
    @intervalService.destroy req.meshbluAuth, (error) =>
      return res.sendError(error) if error?
      res.sendStatus 200

module.exports = IntervalController
