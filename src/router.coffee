IntervalController = require './controllers/interval-controller'

class Router
  constructor: ({@intervalService}) ->

  route: (app) =>
    intervalController = new IntervalController {@intervalService}

    app.post '/intervals', intervalController.create
    app.delete '/intervals', intervalController.destroy

module.exports = Router
