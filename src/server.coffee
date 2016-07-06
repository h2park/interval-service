cors               = require 'cors'
morgan             = require 'morgan'
express            = require 'express'
bodyParser         = require 'body-parser'
errorHandler       = require 'errorhandler'
enableDestroy      = require 'server-destroy'
SendError          = require 'express-send-error'
MeshbluAuth        = require 'express-meshblu-auth'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
Router             = require './router'
IntervalService = require './services/interval-service'
debug              = require('debug')('interval-service:server')

class Server
  constructor: ({@disableLogging, @port, @meshbluConfig, @mongodbUri})->
    throw new Error 'Server requires: mongodbUri' unless @mongodbUri?

  address: =>
    @server.address()

  run: (callback) =>
    app = express()
    app.use SendError()
    app.use meshbluHealthcheck()
    app.use morgan 'dev', immediate: false unless @disableLogging
    app.use cors()
    app.use errorHandler()
    app.use bodyParser.urlencoded limit: '1mb', extended : true
    app.use bodyParser.json limit : '1mb'

    meshbluAuth = new MeshbluAuth @meshbluConfig
    app.use meshbluAuth.auth()
    app.use meshbluAuth.gateway()

    app.options '*', cors()

    intervalService = new IntervalService {@meshbluConfig, @mongodbUri}
    router = new Router {@meshbluConfig, intervalService}

    router.route app

    @server = app.listen @port, callback
    enableDestroy @server

  stop: (callback) =>
    @server.close callback

  destroy: =>
    @server.destroy()

module.exports = Server
