mongojs            = require 'mongojs'
enableDestroy      = require 'server-destroy'
octobluExpress     = require 'express-octoblu'
MeshbluAuth        = require 'express-meshblu-auth'
httpSignature      = require '@octoblu/connect-http-signature'
Router             = require './router'
IntervalService    = require './services/interval-service'
MessageService     = require './services/message-service'
debug              = require('debug')('interval-service:server')

class Server
  constructor: (options={})->
    {
      @logFn
      @disableLogging
      @port
      @meshbluConfig
      @mongodbUri
      @intervalServiceUri
      @publicKey
    } = options
    throw new Error 'Server requires: publicKey' unless @publicKey?
    throw new Error 'Server requires: meshbluConfig' unless @meshbluConfig?
    throw new Error 'Server requires: mongodbUri' unless @mongodbUri?
    throw new Error 'Server requires: intervalServiceUri' unless @intervalServiceUri?

  address: =>
    @server.address()

  run: (callback) =>
    app = octobluExpress { @disableLogging, @logFn }

    meshbluAuth = new MeshbluAuth @meshbluConfig
    app.use httpSignature.verify pub: @publicKey.publicKey
    app.use meshbluAuth.auth()

    app.use (req, res, next) =>
      return httpSignature.gateway()(req, res, next) if req.signature?.verified == true
      meshbluAuth.gateway()(req, res, next)

    database = mongojs @mongodbUri, ['soldiers']
    intervalService = new IntervalService {@meshbluConfig, database, @intervalServiceUri}
    messageService = new MessageService {@meshbluConfig, database}
    router = new Router {@meshbluConfig, intervalService, messageService}

    router.route app

    @server = app.listen @port, callback
    enableDestroy @server

  stop: (callback) =>
    @server.close callback

  destroy: =>
    @server.destroy()

module.exports = Server
