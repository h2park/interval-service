IntervalController = require './controllers/interval-controller'

class Router
  constructor: ({@intervalService}) ->

  route: (app) =>
    intervalController = new IntervalController {@intervalService}

    app.post '/nodes/:nodeId/intervals', intervalController.create
    app.delete '/nodes/:nodeId/intervals/:id', intervalController.destroy

module.exports = Router
