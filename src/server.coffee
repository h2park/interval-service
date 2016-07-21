cors               = require 'cors'
morgan             = require 'morgan'
express            = require 'express'
bodyParser         = require 'body-parser'
errorHandler       = require 'errorhandler'
OctobluRaven       = require 'octoblu-raven'
enableDestroy      = require 'server-destroy'
compression        = require 'compression'
sendError          = require 'express-send-error'
MeshbluAuth        = require 'express-meshblu-auth'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
Router             = require './router'
IntervalService    = require './services/interval-service'
MessageService     = require './services/message-service'
debug              = require('debug')('interval-service:server')
Redis              = require 'ioredis'
httpSignature      = require '@octoblu/connect-http-signature'
publicKey          = require '../public-key.json'
expressVersion     = require 'express-package-version'

class Server
  constructor: (options={})->
    {
      @disableLogging
      @port
      @meshbluConfig
      @mongodbUri
      @redisUri
      @intervalServiceUri
      @octobluRaven
    } = options
    throw new Error 'Server requires: meshbluConfig' unless @meshbluConfig?
    throw new Error 'Server requires: mongodbUri' unless @mongodbUri?
    throw new Error 'Server requires: redisUri' unless @redisUri?
    throw new Error 'Server requires: intervalServiceUri' unless @intervalServiceUri?
    @octobluRaven ?= new OctobluRaven()

  address: =>
    @server.address()

  run: (callback) =>
    @app = express()
    @app.use compression()

    ravenExpress = @octobluRaven.express()
    @app.use ravenExpress.handleErrors()
    @app.use sendError()

    @app.use meshbluHealthcheck()
    @app.use expressVersion({format: '{"version": "%s"}'})
    skip = (request, response) =>
      return response.statusCode < 400
    @app.use morgan 'dev', { immediate: false, skip } unless @disableLogging
    @app.use cors()
    @app.use errorHandler()
    @app.use bodyParser.urlencoded limit: '1mb', extended : true
    @app.use bodyParser.json limit : '1mb'

    meshbluAuth = new MeshbluAuth @meshbluConfig
    @app.use httpSignature.verify pub: publicKey.publicKey
    @app.use meshbluAuth.auth()
    @app.use ravenExpress.meshbluAuthContext()

    @app.use (req, res, next) =>
      return httpSignature.gateway()(req, res, next) if req.signature?.verified == true
      meshbluAuth.gateway()(req, res, next)

    @app.options '*', cors()

    @redisClient = new Redis @redisUri, dropBufferSupport: true
    @redisClient.on 'ready', =>
      @startServer callback

  startServer: (callback) =>
    intervalService = new IntervalService {@meshbluConfig, @mongodbUri, @intervalServiceUri}
    messageService = new MessageService {@meshbluConfig, @mongodbUri, @redisClient, @redisUri}
    router = new Router {@meshbluConfig, intervalService, messageService}

    router.route @app

    @server = @app.listen @port, callback
    enableDestroy @server

  stop: (callback) =>
    @server.close callback

  destroy: =>
    @server.destroy()

module.exports = Server
