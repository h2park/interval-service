IntervalController = require './controllers/interval-controller'
MessageController  = require './controllers/message-controller'

class Router
  constructor: ({@intervalService, @messageService}) ->
    throw new Error 'Router: requires intervalService' unless @intervalService?
    throw new Error 'Router: requires messageService' unless @messageService?

  route: (app) =>
    intervalController = new IntervalController {@intervalService}
    messageController  = new MessageController {@messageService}

    app.post   '/nodes/:nodeId/intervals', intervalController.create
    app.delete '/nodes/:nodeId/intervals/:intervalUuid', intervalController.destroy
    app.post   '/message', messageController.message

module.exports = Router
