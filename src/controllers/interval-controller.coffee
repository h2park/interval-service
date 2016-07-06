class IntervalController
  constructor: ({@intervalService}) ->

  create: (req, res) =>
    @intervalService.create req.meshbluAuth, (error, device) =>
      return res.sendError(error) if error?
      res.send device

module.exports = IntervalController
