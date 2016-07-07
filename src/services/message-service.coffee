_ = require 'lodash'
async = require 'async'
debug = require('debug')('interval-service:message-service')

class MessageService
  constructor: (dependencies={}) ->
    @REDIS_PORT = process.env.REDIS_PORT ? 6379
    @REDIS_HOST = process.env.REDIS_HOST ? 'localhost'
    @kue = dependencies.kue ? require 'kue'
    @queue = @kue.createQueue
      redis:
        port: @REDIS_PORT
        host: @REDIS_HOST

  pong: (params, callback) =>
    debug 'pong', JSON.stringify params
    @createPongJob params, callback

  subscribe: (params, callback) =>
    debug 'subscribe', JSON.stringify params
    return callback(new Error 'nodeId or sendTo not defined') unless params?.sendTo? && params?.nodeId?
    return callback(new Error 'noUnsubscribe should also set fireOnce') if params.noUnsubscribe and !params.fireOnce
    return callback(new Error 'intervalTime must be at least 1000ms') if !params.cronString && params.intervalTime < 1000
    @createRegisterJob params, callback

  unsubscribe: (params, callback) =>
    debug 'unsubscribe', JSON.stringify params
    return callback new Error 'nodeId or sendTo not defined' unless params?.sendTo? && params?.nodeId?
    @createUnregisterJob params, callback

  createRegisterJob: (data, callback)=>
    job = @queue.create('register', data).
      removeOnComplete(true).
      save (error) =>
        callback error, job

  createPongJob: (data, callback)=>
    job = @queue.create('pong', data).
      removeOnComplete(true).
      save (error) =>
        callback error, job

  createUnregisterJob: (data, callback)=>
    job = @queue.create('unregister', data).
      removeOnComplete(true).
      save (error) =>
        callback error, job

module.exports = MessageService
