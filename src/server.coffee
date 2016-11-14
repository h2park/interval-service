_                  = require 'lodash'
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
      @client
    } = options
    throw new Error 'Server requires: publicKey' unless @publicKey?
    throw new Error 'Server requires: meshbluConfig' unless @meshbluConfig?
    throw new Error 'Server requires: mongodbUri' unless @mongodbUri?
    throw new Error 'Server requires: intervalServiceUri' unless @intervalServiceUri?
    throw new Error 'Server requires: client' unless @client?

  address: =>
    @server.address()

  run: (callback) =>
    callback = _.once callback
    app = octobluExpress { @disableLogging, @logFn }

    meshbluAuth = new MeshbluAuth @meshbluConfig
    app.use httpSignature.verify pub: @publicKey.publicKey
    app.use meshbluAuth.auth()

    app.use (req, res, next) =>
      return httpSignature.gateway()(req, res, next) if req.signature?.verified == true
      meshbluAuth.gateway()(req, res, next)

    database = mongojs @mongodbUri, ['soldiers']
    intervalService = new IntervalService {@meshbluConfig, database, @intervalServiceUri}
    messageService = new MessageService {database, @client}
    router = new Router {@meshbluConfig, intervalService, messageService}
    router.route app

    @server = app.listen @port, callback
    enableDestroy @server

  die: (error) =>
    console.error error.stack
    process.exit 1

  stop: (callback) =>
    @server.close callback

  destroy: =>
    @server.destroy()

module.exports = Server
